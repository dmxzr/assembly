#include "sobel.h"

#include <stdlib.h>  /* abs() */

void sobel_filter(const uint8_t *src, uint8_t *dst, int width, int height)
{
    /* Ядра Собеля — записаны явно как матрицы 3×3 */
    static const int Gx[3][3] = {
        { -1,  0, +1 },
        { -2,  0, +2 },
        { -1,  0, +1 }
    };

    static const int Gy[3][3] = {
        { -1, -2, -1 },
        {  0,  0,  0 },
        { +1, +2, +1 }
    };

    /* Граничные пиксели не обрабатываются — зануляем их */
    for (int x = 0; x < width; x++) {
        dst[x] = 0;
        dst[(height - 1) * width + x] = 0;
    }
    for (int y = 0; y < height; y++) {
        dst[y * width] = 0;
        dst[y * width + width - 1] = 0;
    }

    /* Основной проход: свёртка каждого внутреннего пикселя с ядрами */
    for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
            int gx = 0;
            int gy = 0;

            /* Проход по окрестности 3×3 */
            for (int ky = -1; ky <= 1; ky++) {
                for (int kx = -1; kx <= 1; kx++) {
                    int pixel = src[(y + ky) * width + (x + kx)];
                    gx += pixel * Gx[ky + 1][kx + 1];
                    gy += pixel * Gy[ky + 1][kx + 1];
                }
            }

            /* Магнитуда: |Gx| + |Gy|, зажатая в [0, 255] */
            int mag = abs(gx) + abs(gy);
            if (mag > 255) mag = 255;
            dst[y * width + x] = (uint8_t)mag;
        }
    }
}
