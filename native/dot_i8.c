#include <stdint.h>
#include <stddef.h>
#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

/* C = A * W^T. W is row-major [output_channel,reduction].
 * K <= 256 bounds every INT32 lane sum; the API returns INT64 dot products.
 * No bias, scaling, rounding, or saturation is performed by this kernel. */
int eat_dot_i8(const int8_t *a, const int8_t *w, int64_t *c,
               size_t rows, size_t outputs, size_t reduction) {
    if (!a || !w || !c || !rows || !outputs || !reduction || reduction > 256) return -1;
    for (size_t r = 0; r < rows; ++r) {
        for (size_t o = 0; o < outputs; ++o) {
            const int8_t *ar = a + r * reduction;
            const int8_t *wr = w + o * reduction;
            size_t k = 0;
            int64_t sum = 0;
#if defined(__ARM_NEON)
            int32x4_t low = vdupq_n_s32(0), high = vdupq_n_s32(0);
            for (; k + 16 <= reduction; k += 16) {
                int8x16_t av = vld1q_s8(ar + k), bv = vld1q_s8(wr + k);
                low = vpadalq_s16(low, vmull_s8(vget_low_s8(av), vget_low_s8(bv)));
                high = vpadalq_s16(high, vmull_s8(vget_high_s8(av), vget_high_s8(bv)));
            }
            int32_t lanes[4];
            vst1q_s32(lanes, vaddq_s32(low, high));
            sum = (int64_t)lanes[0] + lanes[1] + lanes[2] + lanes[3];
#endif
            for (; k < reduction; ++k) sum += (int64_t)ar[k] * wr[k];
            c[r * outputs + o] = sum;
        }
    }
    return 0;
}
