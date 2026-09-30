#ifndef SOBEL_H
#define SOBEL_H

#include <stdint.h>

/*
 * Apply Sobel edge detection to a grayscale image.
 *
 *   src    — input pixels,  width * height bytes
 *   dst    — output pixels, width * height bytes (must not alias src)
 *   width  — image width  in pixels
 *   height — image height in pixels
 *
 * Border pixels in dst are set to zero.
 * Magnitude formula: |Gx| + |Gy|, clamped to [0, 255].
 *
 * Sobel kernels:
 *   Gx: [-1  0  +1]     Gy: [-1  -2  -1]
 *       [-2  0  +2]         [ 0   0   0]
 *       [-1  0  +1]         [+1  +2  +1]
 *
 * This function is implemented in exactly one of:
 *   sobel_c.c      — plain C
 *   sobel_asm.asm  — NASM (no SIMD)
 *   sobel_simd.asm — NASM + SSE2
 * Selected at build time via the IMPL variable in the Makefile.
 */
void sobel_filter(const uint8_t *src, uint8_t *dst, int width, int height);

#endif
