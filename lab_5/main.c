#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>


#define ADRESS_DATA 10
#define BMP_WIDTH 18
#define BMP_HEIGHT 22

extern void desaturate(uint8_t *pixels, int32_t width, int32_t height);

int main(int argc, char *argv[])
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s input.bmp output.bmp\n", argv[0]);
        return 1;
    }

    /* читаем весь файл в буфер */
    FILE *in = fopen(argv[1], "rb");
    if (!in) { perror(argv[1]); return 1; }

    fseek(in, 0, SEEK_END);
    long size = ftell(in);
    fseek(in, 0, SEEK_SET);

    uint8_t *buf = malloc(size);
    fread(buf, 1, size, in);
    fclose(in);

    /* поля BMP-заголовка по фиксированным смещениям:
     * байт 10 — смещение до пикселей (uint32)
     * байт 18 — ширина (int32)
     * байт 22 — высота (int32)              */
    uint32_t pixel_offset = *(uint32_t *)(buf + 10);
    int32_t  width        = *(int32_t  *)(buf + 18);
    int32_t  height       = *(int32_t  *)(buf + 22);
    if (height < 0) height = -height;

    uint8_t *pixels = buf + pixel_offset;

    /* замер времени */
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    desaturate(pixels, width, height);

    clock_gettime(CLOCK_MONOTONIC, &t1);

    double ms = (t1.tv_sec  - t0.tv_sec)  * 1e3
              + (t1.tv_nsec - t0.tv_nsec) * 1e-6;
    printf("%.3f ms  (%dx%d)\n", ms, width, height);

    /* пишем результат */
    FILE *out = fopen(argv[2], "wb");
    fwrite(buf, 1, size, out);
    fclose(out);

    free(buf);
    return 0;
}
