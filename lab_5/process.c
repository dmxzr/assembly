#include <stdint.h>

void desaturate(uint8_t *pixels, int32_t width, int32_t height)
{
    if (pixels == NULL) return;
    if (width <= 0 || height <= 0) return;

    uint32_t padding = (4 - (width * 3) % 4) % 4;

    for (int32_t y = 0; y < height; y++) {
        for (int32_t x = 0; x < width; x++) {
            uint8_t b = pixels[x * 3];
            uint8_t g = pixels[x * 3 + 1];
            uint8_t r = pixels[x * 3 + 2];

            uint8_t high = (r > b) ? ((r > g) ? r : g) : ((b > g) ? b : g);
            uint8_t low  = (r < b) ? ((r < g) ? r : g) : ((b < g) ? b : g);

            uint8_t gray = (high + low) / 2;

            pixels[x * 3]     = gray;
            pixels[x * 3 + 1] = gray;
            pixels[x * 3 + 2] = gray;
        }
        pixels += width * 3 + padding;
    }
}
