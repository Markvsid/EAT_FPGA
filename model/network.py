"""FP32 and experimental fake-quantized models; not a bit-accurate FPGA model."""
import math
import torch
from torch import nn
from torch.nn import functional as F


def ste_quantize(x, bits, per_channel=False, power_of_two=False):
    maximum = x.detach().abs().amax(dim=1, keepdim=True) if per_channel else x.detach().abs().amax()
    scale = (maximum / (2 ** (bits - 1) - 1)).clamp_min(1e-8)
    if power_of_two:
        scale = 2.0 ** torch.ceil(torch.log2(scale))
    q = (x / scale).round().clamp(-(2 ** (bits - 1)), 2 ** (bits - 1) - 1) * scale
    return x + (q - x).detach()


class Linear(nn.Linear):
    def forward(self, x, bits=None):
        if bits:
            x = ste_quantize(x, 8, power_of_two=True)
            weight = ste_quantize(self.weight, bits, per_channel=True)
        else:
            weight = self.weight
        return F.linear(x, weight, self.bias)


class RMSNorm(nn.Module):
    def __init__(self, width):
        super().__init__()
        self.weight = nn.Parameter(torch.ones(width))

    def forward(self, x):
        return x * torch.rsqrt(x.square().mean(-1, keepdim=True) + 1e-5) * self.weight


def pwl_silu(x):
    # Continuous interpolation of SiLU at fixed knots. Exact constants are
    # software candidates; selection of fixed-point coefficients is pending.
    knots = x.new_tensor([-4., -3., -2., -1., 0., 1., 2., 3., 4.])
    values = knots * torch.sigmoid(knots)
    idx = torch.floor(x.clamp(-4, 3.99999) + 4).long()
    interpolation = values[idx] + (x - knots[idx]) * (values[idx + 1] - values[idx])
    return torch.where(x < -4, torch.zeros_like(x), torch.where(x > 4, x, interpolation))


def streaming_attention(q, k, v, tile=8):
    """FP32 reference for template equations 15–18, no full score matrix."""
    if tile < 1 or k.shape[-2] < 1:
        raise ValueError("Nonempty keys and positive tile required")
    m = torch.full_like(q[..., :1], -torch.inf)
    normalizer = torch.zeros_like(m)
    output = torch.zeros_like(q)
    for start in range(0, k.shape[-2], tile):
        scores = q @ k[..., start:start + tile, :].transpose(-2, -1) / math.sqrt(q.shape[-1])
        new_m = torch.maximum(m, scores.amax(-1, keepdim=True))
        alpha = torch.exp(m - new_m)
        p = torch.exp(scores - new_m)
        output = output * alpha + p @ v[..., start:start + tile, :]
        normalizer = normalizer * alpha + p.sum(-1, keepdim=True)
        m = new_m
    return output / normalizer


class Block(nn.Module):
    def __init__(self, c):
        super().__init__()
        d = c["width"]
        self.heads = c["heads"]
        self.norm1, self.norm2 = RMSNorm(d), RMSNorm(d)
        self.qkv, self.projection = Linear(d, 3 * d), Linear(d, d)
        self.fc1, self.fc2 = Linear(d, c["ffn_ratio"] * d), Linear(c["ffn_ratio"] * d, d)
        self.activation = c["activation"]

    def forward(self, x, bits=None, stream=False):
        b, n, d = x.shape
        q, k, v = self.qkv(self.norm1(x), bits).reshape(b, n, 3, self.heads, d // self.heads).permute(2, 0, 3, 1, 4).unbind(0)
        y = streaming_attention(q, k, v) if stream else F.scaled_dot_product_attention(q, k, v)
        x = x + self.projection(y.transpose(1, 2).reshape(b, n, d), bits)
        y = self.fc1(self.norm2(x), bits)
        y = pwl_silu(y) if self.activation == "pwl_silu" else F.silu(y)
        return x + self.fc2(y, bits)


class TokenGate(nn.Module):
    def __init__(self, width, group_size):
        super().__init__()
        self.scorer = Linear(width, 1)
        self.group_size = group_size

    def forward(self, x, keep_groups, rts, bits=None):
        b, n, d = x.shape
        g = self.group_size
        if n % g or not 1 <= keep_groups <= n // g:
            raise ValueError("Only complete groups and positive legal retention supported")
        groups = x.reshape(b, n // g, g, d)
        token_score = self.scorer(x, bits).reshape(b, n // g, g)
        scores = token_score.mean(-1)
        # Stable sorting makes earlier temporal groups win exact ties.
        selected = torch.argsort(scores, dim=-1, descending=True, stable=True)[:, :keep_groups]
        mask = torch.zeros_like(scores, dtype=torch.bool).scatter(1, selected, True)
        # Straight-through surrogate trains the scorer through retained features.
        soft = torch.sigmoid(scores)
        gate = mask.to(x.dtype) + soft - soft.detach() if self.training else mask.to(x.dtype)
        groups = groups * gate[..., None, None]
        if not rts:
            return groups[mask].reshape(b, keep_groups * g, d)
        # A low-cost nonnegative importance candidate; quantization remains pending.
        weights = token_score.detach().abs() + 1.0
        summaries = (x.reshape(b, n // g, g, d) * weights[..., None]).sum(2) / weights.sum(2)[..., None]
        # Chronological compaction. Each discarded group contributes one summary.
        lengths = torch.where(mask, g, 1)
        offsets = lengths.cumsum(1) - lengths
        # Dropped groups emit only their first slot; retained groups emit all g.
        emit = mask[..., None].expand(b, n // g, g).clone()
        emit[:, :, 0] = True
        destination = offsets[..., None] + torch.arange(g, device=x.device)
        values = torch.where(mask[..., None, None], groups, summaries[..., None, :])
        output = x.new_zeros(b, keep_groups * g + n // g - keep_groups, d)
        row_indices = torch.arange(b, device=x.device)[:, None, None].expand_as(emit)
        output[row_indices[emit], destination[emit]] = values[emit]
        return output


class Encoder(nn.Module):
    def __init__(self, c):
        super().__init__()
        self.config = c
        p, d = c["patch_samples"], c["width"]
        if c["window_samples"] % p or d % c["heads"]:
            raise ValueError("Patch length and head width must divide dimensions")
        self.embedding = Linear(p * len(c["channels"]), d)
        self.position = nn.Parameter(torch.zeros(1, c["window_samples"] // p, d))
        nn.init.normal_(self.position, std=0.02)
        self.blocks = nn.ModuleList([Block(c) for _ in range(c["layers"])])
        self.gate = TokenGate(d, c["group_size"])
        self.norm = RMSNorm(d)
        self.classifier = Linear(d, c["classes"])
        self.exit_classifier = Linear(d, c["classes"])

    def forward(self, x, mode=None, stream=False, return_aux=False):
        c = self.config
        mode = mode or {"weight_bits": None, "keep_groups": self.position.shape[1] // c["group_size"], "rts": False, "exit_block": c["layers"]}
        bits = mode["weight_bits"]
        x = self.embedding(x.reshape(x.shape[0], -1, c["patch_samples"] * len(c["channels"])), bits) + self.position
        auxiliary = None
        for index, block in enumerate(self.blocks, 1):
            x = block(x, bits, stream)
            if index == c["gate_after_block"] and mode["keep_groups"] < x.shape[1] // c["group_size"]:
                x = self.gate(x, mode["keep_groups"], mode["rts"], bits)
            if index == 2:
                auxiliary = self.exit_classifier(self.norm(x).mean(1), bits)
            if index == mode["exit_block"]:
                break
        output = auxiliary if mode["exit_block"] == 2 else self.classifier(self.norm(x).mean(1), bits)
        return (output, auxiliary) if return_aux else output
