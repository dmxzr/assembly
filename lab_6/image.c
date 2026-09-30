#include "image.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Смещения полей в заголовке BMP (байты, little-endian):
 *   10 — uint32: смещение до начала пикселей
 *   18 — int32:  ширина
 *   22 — int32:  высота (> 0 → строки снизу вверх, < 0 → сверху вниз)
 *   28 — uint16: бит на пиксель (8 или 24)
 */

/* Перевод RGB → grayscale по формуле BT.601 */
static uint8_t rgb_to_gray(uint8_t r, uint8_t g, uint8_t b)
{
    return (uint8_t)(0.299f * r + 0.587f * g + 0.114f * b);
}

/* ------------------------------------------------------------------ */

Image *image_alloc(int width, int height)
{
    Image *img = malloc(sizeof(Image));
    if (!img) return NULL;
    img->width  = width;
    img->height = height;
    /* +64 байта — SIMD-код может читать чуть дальше последнего пикселя */
    img->pixels = calloc(width * height + 64, 1);
    if (!img->pixels) { free(img); return NULL; }
    return img;
}

void image_free(Image *img)
{
    if (!img) return;
    free(img->pixels);
    free(img);
}

/* ------------------------------------------------------------------ */

Image *image_load_bmp(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "Error: cannot open '%s'\n", path); return NULL; }

    /* Читаем весь файл в буфер (как в лаб5) */
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    uint8_t *buf = malloc(size);
    if (!buf) { fclose(f); return NULL; }
    fread(buf, 1, size, f);
    fclose(f);

    /* Проверка сигнатуры 'BM' */
    if (buf[0] != 'B' || buf[1] != 'M') {
        fprintf(stderr, "Error: '%s' is not a BMP file\n", path);
        free(buf);
        return NULL;
    }

    /* Берём нужные поля напрямую по смещению — без структур */
    uint32_t pixel_offset = *(uint32_t *)(buf + 10);
    int32_t  width        = *(int32_t  *)(buf + 18);
    int32_t  height       = *(int32_t  *)(buf + 22);
    uint16_t bpp          = *(uint16_t *)(buf + 28);

    if (height < 0) height = -height;

    if (bpp != 24) {
        fprintf(stderr, "Error: only 24-bit BMP supported (got %d-bit)\n", bpp);
        free(buf);
        return NULL;
    }

    Image *img = image_alloc(width, height);
    if (!img) { free(buf); return NULL; }

    /* 24-бит: три байта на пиксель (B G R), строки выровнены до 4 байт.
       BMP хранит строки снизу вверх — начинаем с последней строки файла */
    uint32_t padding  = (4 - (width * 3) % 4) % 4;
    uint8_t  *row     = buf + pixel_offset + (height - 1) * (width * 3 + padding);

    for (int y = 0; y < height; y++) {
        uint8_t *dst = img->pixels + y * width;
        for (int x = 0; x < width; x++) {
            dst[x] = rgb_to_gray(row[x*3 + 2], row[x*3 + 1], row[x*3 + 0]);
        }
        row -= (width * 3 + padding);   /* переходим к предыдущей строке в файле */
    }

    free(buf);
    return img;
}

/* ------------------------------------------------------------------ */

int image_save_bmp(const Image *img, const char *path)
{
    int w = img->width;
    int h = img->height;

    /* Выравнивание строки до 4 байт (8-бит = 1 байт на пиксель) */
    uint32_t padding     = (4 - w % 4) % 4;
    uint32_t pixel_offset = 14 + 40 + 256 * 4;               /* до начала пикселей  */
    uint32_t file_size    = pixel_offset + (w + padding) * h; /* полный размер файла */

    FILE *f = fopen(path, "wb");
    if (!f) { fprintf(stderr, "Error: cannot write '%s'\n", path); return 0; }

    /* --- Заголовок файла: 14 байт --- */
    uint8_t fhdr[14] = {0};
    fhdr[0] = 'B';
    fhdr[1] = 'M';
    *(uint32_t *)(fhdr + 2)  = file_size;
    *(uint32_t *)(fhdr + 10) = pixel_offset;
    fwrite(fhdr, 1, 14, f);

    /* --- DIB-заголовок: 40 байт --- */
    uint8_t dhdr[40] = {0};
    *(uint32_t *)(dhdr + 0)  = 40;  /* размер этого заголовка */
    *(int32_t  *)(dhdr + 4)  = w;
    *(int32_t  *)(dhdr + 8)  = h;   /* > 0: строки хранятся снизу вверх */
    *(uint16_t *)(dhdr + 12) = 1;   /* цветовых плоскостей */
    *(uint16_t *)(dhdr + 14) = 8;   /* бит на пиксель */
    *(uint32_t *)(dhdr + 32) = 256; /* размер палитры */
    fwrite(dhdr, 1, 40, f);

    /* --- Палитра: 256 оттенков серого ---
       Каждая запись 4 байта: B G R 0
       Запись i означает: пиксель со значением i имеет цвет (i, i, i) */
    for (int i = 0; i < 256; i++) {
        uint8_t entry[4] = { (uint8_t)i, (uint8_t)i, (uint8_t)i, 0 };
        fwrite(entry, 1, 4, f);
    }

    /* --- Пиксели: снизу вверх ---
       Пишем строки в обратном порядке (BMP формат).
       После каждой строки — padding нулевых байт до кратности 4. */
    uint8_t zeros[3] = {0, 0, 0};
    for (int y = h - 1; y >= 0; y--) {
        fwrite(img->pixels + y * w, 1, w, f);  /* строка пикселей */
        fwrite(zeros, 1, padding, f);           /* выравнивание    */
    }

    fclose(f);
    return 1;
}
