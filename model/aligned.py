"""Trainable aligned encoder, independently emulating exported integer inference.

CPU only. Approximate gradients use differentiable floating operators, while
every returned forward state follows the frozen finite-width contract exactly.
This is not the original dynamically fake-quantized training model.
"""
import copy
import json
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

from model import aligned_arithmetic as a
from model.network import Encoder, pwl_silu


class AlignedEncoder(nn.Module):
    def __init__(self, export_path, checkpoint=None):
        super().__init__()
        root = Path(export_path)
        self.manifest = json.loads((root / 'manifest.json').read_text())
        self.config, self.mode, self.spec = self.manifest['config'], self.manifest['mode'], self.manifest['spec']
        if self.spec.get('rmsnorm_implementation') != 'rsqrt_lut' or self.spec['state_fraction_bits'] != 12:
            raise ValueError('This implementation targets the existing Q12/LUT candidate')
        self.network = Encoder(self.config)
        saved = torch.load(checkpoint or self.manifest['checkpoint_path'], map_location='cpu', weights_only=True)
        self.network.load_state_dict(saved['model'])
        with np.load(root / 'constants.npz') as values:
            self.constants = {key: torch.from_numpy(values[key].astype(np.int64)) for key in values.files}
        self.scales = {key: torch.tensor(value['weight_scale'], dtype=torch.float64) for key, value in self.manifest['layers'].items()}
        self.trace_enabled = False
        self.trace, self.saturations = {}, {}

    def integer(self, real):
        return torch.round(real.detach().double() * 4096.).to(torch.int64)

    def record_integer(self, name, value, bits=24):
        result = a.clip(value, bits)
        if self.trace_enabled:
            self.saturations[name] = int((value != result).sum())
            self.trace[name] = result.detach().clone()
        return result

    def state(self, name, value, surrogate):
        result = self.record_integer(name, value)
        return a.attach(result.float() / 4096., surrogate)

    def quantized_parameters(self, name):
        module = self.network.get_submodule(name)
        layer = self.manifest['layers'][name]
        # The existing exporter divides FP32 parameters by FP32 channel scales.
        # Preserve that rounding boundary; FP64 division can move half-way cases.
        scale = self.scales[name].float()
        bits = self.mode['weight_bits']
        weights = torch.round(module.weight.detach() / scale[:, None]).clamp(-(1 << (bits - 1)), (1 << (bits - 1)) - 1).long()
        bias = torch.round(module.bias.detach() / (scale * 2. ** layer['activation_exponent'])).long()
        return weights, bias

    def linear(self, name, x):
        layer = self.manifest['layers'][name]
        raw = a.shift(self.integer(x), layer['q12_to_int8_shift'])
        q = self.record_integer(name + '.input_int8', raw, 8)
        weights, bias = self.quantized_parameters(name)
        accumulator = a.check(a.dot_i8(q, weights) + bias, self.spec['linear_accumulator_signed_bits'], name)
        multiplier = self.constants[name + '.multiplier']
        if int(accumulator.abs().max()) * int(multiplier.abs().max()) > (1 << 62) - 1:
            raise OverflowError('Requantization product exceeds safe integer range')
        result = a.shift(accumulator * multiplier, self.spec['weight_multiplier_fraction_bits'])
        if self.trace_enabled:
            self.trace[name + '.accumulator'] = accumulator.clone()
        module = self.network.get_submodule(name)
        qreal = q.float() * 2. ** layer['activation_exponent']
        wreal = (weights.double() * self.scales[name][:, None]).float()
        surrogate = F.linear(a.attach(qreal, x), a.attach(wreal, module.weight), module.bias)
        return self.state(name, result, surrogate)

    def norm(self, name, x):
        gamma = torch.round(self.network.get_submodule(name).weight.detach().double() * (1 << self.spec['norm_gamma_fraction_bits'])).long()
        a.check(gamma, 24, 'norm gamma')
        result = a.norm(self.integer(x), gamma, self.constants['rsqrt_table'], self.spec)
        surrogate = self.network.get_submodule(name)(x)
        return self.state(name, result, surrogate)

    def block(self, name, x):
        c = self.config
        qkv = self.linear(name + '.qkv', self.norm(name + '.norm1', x))
        b, n, d = qkv.shape[0], x.shape[1], c['width']
        parts = qkv.reshape(b, n, 3, c['heads'], d // c['heads']).permute(2, 0, 3, 1, 4).unbind(0)
        integer, real = [], []
        for tensor, shift, kind in zip(parts, self.manifest['attention_qkv_int8_shifts'][name], ['q', 'k', 'v']):
            raw = a.shift(self.integer(tensor), shift)
            q = self.record_integer(name + '.' + kind + '.int8', raw, 8) << shift
            if self.trace_enabled:
                self.trace[name + '.' + kind] = q.clone()
            integer.append(q)
            real.append(a.attach(q.float() / 4096., tensor))
        attention = a.attention(*integer, self.constants['exp_table'], self.spec, self.manifest['attention_scale_multiplier_q20'])
        surrogate = F.scaled_dot_product_attention(*real)
        attention = attention.transpose(1, 2).reshape(b, n, d)
        y = self.state(name + '.attention', attention, surrogate.transpose(1, 2).reshape(b, n, d))
        y = self.linear(name + '.projection', y)
        x = self.state(name + '.residual1', self.integer(x) + self.integer(y), x + y)
        y = self.linear(name + '.fc1', self.norm(name + '.norm2', x))
        y = self.state(name + '.activation', a.activation(self.integer(y), self.constants['silu_knots'], self.spec), pwl_silu(y))
        y = self.linear(name + '.fc2', y)
        return self.state(name + '.residual2', self.integer(x) + self.integer(y), x + y)

    def gate(self, x):
        b, n, d = x.shape
        g, keep = self.config['group_size'], self.mode['keep_groups']
        token_score = self.linear('gate.scorer', x).reshape(b, n // g, g)
        scores_int = self.integer(token_score).sum(-1)
        selected = torch.argsort(scores_int, dim=-1, descending=True, stable=True)[:, :keep]
        mask = torch.zeros_like(scores_int, dtype=torch.bool).scatter(1, selected, True)
        if self.trace_enabled:
            self.trace['gate.group_sums'] = scores_int.clone()
            self.trace['gate.selected_groups'] = torch.sort(selected, dim=-1).values
        exact = self.integer(x).reshape(b, n // g, g, d)
        groups = x.reshape(b, n // g, g, d)
        soft = torch.sigmoid(token_score.mean(-1))
        gate = a.attach(mask.float(), soft) if self.training else mask.float()
        retained = groups * gate[..., None, None]
        if not self.mode['rts']:
            values = exact[mask].reshape(b, keep * g, d)
            return self.state('gate.compacted', values, retained[mask].reshape(b, keep * g, d))
        weights_int = self.integer(token_score).abs() + 4096
        numerator = a.check((exact * weights_int[..., None]).sum(2), 53, 'summary weighted sum')
        summary_int = a.divide(numerator, weights_int.sum(-1, keepdim=True))
        weights = token_score.detach().abs() + 1.
        summary = (groups * weights[..., None]).sum(2) / weights.sum(-1, keepdim=True)
        lengths = torch.where(mask, g, 1)
        offsets = lengths.cumsum(1) - lengths
        emit = mask[..., None].expand(b, n // g, g).clone()
        emit[:, :, 0] = True
        destination = offsets[..., None] + torch.arange(g)
        rows = torch.arange(b)[:, None, None].expand_as(emit)
        total = keep * g + n // g - keep
        out_int = torch.zeros((b, total, d), dtype=torch.int64)
        out_real = x.new_zeros((b, total, d))
        out_int[rows[emit], destination[emit]] = torch.where(mask[..., None, None], exact, summary_int[..., None, :])[emit]
        out_real[rows[emit], destination[emit]] = torch.where(mask[..., None, None], retained, summary[..., None, :])[emit]
        return self.state('gate.compacted', out_int, out_real)

    def forward(self, x):
        if x.device.type != 'cpu':
            raise ValueError('Aligned reference training is CPU only')
        if not bool(torch.isfinite(x).all()):
            raise ValueError('Finite preprocessed input required')
        self.trace, self.saturations = {}, {}
        scale = 2. ** (self.manifest['input_q12_shift'] - 12)
        quantized = self.record_integer('host_input_int8', torch.round(x.detach().double() / scale).long(), 8)
        integer = quantized << self.manifest['input_q12_shift']
        x = a.attach(integer.float() / 4096., x)
        c = self.config
        x = self.linear('embedding', x.reshape(len(x), -1, c['patch_samples'] * len(c['channels'])))
        position = torch.round(self.network.position.detach().double() * 4096.).long()
        x = self.state('position_added', self.integer(x) + position, x + self.network.position)
        for index in range(self.mode['exit_block']):
            x = self.block(f'blocks.{index}', x)
            if index + 1 == c['gate_after_block'] and self.mode['keep_groups'] < x.shape[1] // c['group_size']:
                x = self.gate(x)
        x = self.norm('norm', x)
        x = self.state('pooled', a.divide(self.integer(x).sum(1), x.shape[1]), x.mean(1))
        return self.linear('exit_classifier' if self.mode['exit_block'] == 2 else 'classifier', x)

    def export_constants(self):
        arrays = {key: value.numpy().copy() for key, value in self.constants.items()}
        for name in self.manifest['layers']:
            weight, bias = self.quantized_parameters(name)
            arrays[name + '.weight'] = weight.numpy().astype(np.int8)
            arrays[name + '.bias'] = bias.numpy()
        for name, module in self.network.named_modules():
            if name + '.gamma' in arrays:
                arrays[name + '.gamma'] = torch.round(module.weight.detach().double() * (1 << self.spec['norm_gamma_fraction_bits'])).long().numpy()
        arrays['position'] = torch.round(self.network.position.detach().double()[0] * 4096.).long().numpy()
        return arrays
