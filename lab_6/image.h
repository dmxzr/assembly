#ifndef IMAGE_H
#define IMAGE_H

#include <stdint.h>

/* Grayscale image: pixels stored row-major, top-to-bottom */
typedef struct {
    int      width;
    int      height;
    uint8_t *pixels;
} Image;

Image *image_load_bmp(const char *path);   /* supports 8-bit and 24-bit BMP */
int    image_save_bmp(const Image *img, const char *path);
Image *image_alloc(int width, int height); /* allocate + zero pixels */
void   image_free(Image *img);

#endif
