#define _POSIX_C_SOURCE 200809L
#include "image.h"
#include "sobel.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define REPEATS 100

static double now_ms(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1e3 + t.tv_nsec * 1e-6;
}

int main(int argc, char *argv[])
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s input.bmp output.bmp\n", argv[0]);
        return 1;
    }

    Image *src = image_load_bmp(argv[1]);
    if (!src) return 1;

    Image *dst = image_alloc(src->width, src->height);
    if (!dst) { image_free(src); return 1; }

    double t0 = now_ms();
    for (int i = 0; i < REPEATS; i++)
        sobel_filter(src->pixels, dst->pixels, src->width, src->height);
    double elapsed = (now_ms() - t0) / REPEATS;

    printf("размер: %dx%d\n", src->width, src->height);
    printf("время:  %.3f мс (среднее по %d запускам)\n", elapsed, REPEATS);

    if (!image_save_bmp(dst, argv[2])) {
        image_free(src);
        image_free(dst);
        return 1;
    }

    image_free(src);
    image_free(dst);
    return 0;
}
