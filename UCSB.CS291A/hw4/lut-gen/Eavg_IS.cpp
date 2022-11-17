#include <iostream>
#include <vector>
#include <algorithm>
#include <cmath>
#include <sstream>
#include <fstream>
#include "vec.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION

#include "stb_image_write.h"

#define STB_IMAGE_IMPLEMENTATION

#include "stb_image.h"

int resolution = 128;
int channel = 3;

void setRGB(int x, int y, float alpha, unsigned char *data) {
    data[3 * (resolution * x + y) + 0] = uint8_t(alpha);
    data[3 * (resolution * x + y) + 1] = uint8_t(alpha);
    data[3 * (resolution * x + y) + 2] = uint8_t(alpha);
}

void setRGB(int x, int y, Vec3f alpha, unsigned char *data) {
    data[3 * (resolution * x + y) + 0] = uint8_t(alpha.x);
    data[3 * (resolution * x + y) + 1] = uint8_t(alpha.y);
    data[3 * (resolution * x + y) + 2] = uint8_t(alpha.z);
}

Vec3f getEmu(int x, int y, unsigned char *data) {
    return Vec3f(data[3 * (resolution * x + y) + 0],
                 data[3 * (resolution * x + y) + 1],
                 data[3 * (resolution * x + y) + 2]);
}

int main() {
    unsigned char *Edata = stbi_load("./GGX_E_LUT.png", &resolution, &resolution, &channel, 3);
    if (Edata == NULL) {
        std::cout << "ERROE_FILE_NOT_LOAD" << std::endl;
        return -1;
    } else {
        std::cout << resolution << " " << resolution << " " << channel << std::endl;
        // | -----> mu(j)
        // | 
        // | rough（i）
        // Flip it, if you want the data written to the texture
        uint8_t data[resolution * resolution * 3];
        float step = 1.0 / resolution;
        Vec3f Eavg = Vec3f(0.0);
        for (int i = 0; i < resolution; i++) {
            float roughness = step * (static_cast<float>(i) + 0.5f);
            for (int j = 0; j < resolution; j++) {
                float NdotV = step * (static_cast<float>(j) + 0.5f);
                Vec3f V = Vec3f(std::sqrt(1.f - NdotV * NdotV), 0.f, NdotV);

                Vec3f Emu = getEmu((resolution - 1 - i), j, Edata);
                Eavg += Vec3f(Emu.z) * 2 * NdotV * step;
            }

            for (int k = 0; k < resolution; k++) {
                setRGB(i, k, Eavg, data);
            }

            Eavg = Vec3f(0.0);
        }
        stbi_flip_vertically_on_write(true);
        stbi_write_png("GGX_Eavg_LUT.png", resolution, resolution, channel, data, 0);
    }
    stbi_image_free(Edata);
    return 0;
}