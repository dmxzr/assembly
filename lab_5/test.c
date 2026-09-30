#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#pragma pack(push, 1)
typedef struct {
    uint16_t type;
    uint32_t file_size;
    uint16_t reserved1;
    uint16_t reserved2;
    uint32_t pixel_offset;
} BmpFileHeader;

typedef struct {
    uint32_t header_size;
    int32_t  width;
    int32_t  height;
    uint16_t color_planes;
    uint16_t bits_per_pixel;
    uint32_t compression;
    uint32_t image_size;
    int32_t  x_ppm;
    int32_t  y_ppm;
    uint32_t colors_used;
    uint32_t colors_important;
} BmpDibHeader;
#pragma pack(pop)

void desaturate(uint8_t *pixels, int32_t width, int32_t height)
{
    int32_t padding = (4 - (width * 3) % 4) % 4;
    uint8_t *p = pixels;

    for (int32_t y = 0; y < height; y++) {
        for (int32_t x = 0; x < width; x++) {
            uint8_t b = p[0], g = p[1], r = p[2];

            uint8_t hi = r > g ? r : g;
            if (b > hi) hi = b;
            uint8_t lo = r < g ? r : g;
            if (b < lo) lo = b;

            p[0] = p[1] = p[2] = (uint8_t)(((unsigned)hi + lo) >> 1);
            p += 3;
        }
        p += padding;
    }
}

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

    /* разбираем заголовки */
    BmpFileHeader *fh = (BmpFileHeader *)buf;
    BmpDibHeader  *dh = (BmpDibHeader *)(buf + sizeof(BmpFileHeader));

    int32_t width  = dh->width;
    int32_t height = dh->height < 0 ? -dh->height : dh->height;

    uint8_t *pixels = buf + fh->pixel_offset;

    /* обрабатываем */
    desaturate(pixels, width, height);

    /* пишем результат */
    FILE *out = fopen(argv[2], "wb");
    fwrite(buf, 1, size, out);
    fclose(out);

    free(buf);
    return 0;
}
