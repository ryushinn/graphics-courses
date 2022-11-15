#include "denoiser.h"

Denoiser::Denoiser(bool useAtrous /* = false */) : m_useTemportal(false), m_useAtrous(useAtrous) {}

void Denoiser::Reprojection(const FrameInfo &frameInfo) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    Matrix4x4 preWorld2Screen =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 1];
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            m_valid(x, y) = false;
            if (frameInfo.m_id(x, y) == -1) continue;
            auto worldPos = frameInfo.m_position(x, y);
            auto curLocal2World = frameInfo.m_matrix[frameInfo.m_id(x, y)];
            auto preLocal2World = m_preFrameInfo.m_matrix[frameInfo.m_id(x, y)];
            auto preCoord = (preWorld2Screen * preLocal2World * Inverse(curLocal2World))(worldPos, Float3::EType::Point);
            auto preX = int(preCoord.x);
            auto preY = int(preCoord.y);
            if (preX >= 0 && preX < width && preY >= 0 && preY < height &&
                frameInfo.m_id(x, y) == m_preFrameInfo.m_id(preX, preY)) {
                m_valid(x, y) = true;
                m_misc(x, y) = m_accColor(preX, preY);
            }
        }
    }
    std::swap(m_misc, m_accColor);
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 3;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            if (m_valid(x, y)) {
                Float3 EX = 0.0;
                Float3 ESqrX = 0.0;
                int count = 0;
                for (int i = -kernelRadius; i <= kernelRadius; ++i) {
                    for (int j = -kernelRadius; j <= kernelRadius; ++j) {
                        auto _x = x + i, _y = y + j;
                        if (_x < 0 || _x >= width || _y < 0 || _y >= height)
                            continue;
                        count++;
                        EX += curFilteredColor(_x, _y);
                        ESqrX += curFilteredColor(_x, _y) * curFilteredColor(_x, _y);
                    }
                }
                EX /= count;
                ESqrX /= count;
                auto VarX = ESqrX - EX * EX;
                auto SigmaX = Float3(std::sqrt(VarX.x),
                                     std::sqrt(VarX.y),
                                     std::sqrt(VarX.z));

                Float3 color = m_accColor(x, y);
                color = Clamp(color, EX - SigmaX * m_colorBoxK, EX + SigmaX * m_colorBoxK);
                m_misc(x, y) = Lerp(color, curFilteredColor(x, y), m_alpha);
            }
            else {
                m_misc(x, y) = curFilteredColor(x, y);
            }
        }
    }
    std::swap(m_misc, m_accColor);
}

Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 16;

    if (m_useAtrous) {
        // a-trous optimization:
        Buffer2D<Float3> interColor = CreateBuffer2D<Float3>(width, height);
        interColor.Copy(frameInfo.m_beauty);

         for (int step = 1, times = kernelRadius; times > 1; times >>= 1, step <<= 1) {
#pragma omp parallel for
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    if (frameInfo.m_id(x, y) == -1) continue;
                    float weight_sum = 0.0;
                    Float3 filtered_sum = 0.0;
                    for (int i = -2; i <= 2; ++i) {
                        for (int j = -2; j <= 2; ++j) {
                            auto _x = x + i * step, _y = y + j * step;
                            if (_x < 0 || _x >= width || _y < 0 || _y >= height)
                                continue;
                            if (frameInfo.m_id(_x, _y) == -1) continue;
                            float weight = 1.0;
                            if (x != _x || y != _y) {
                                float exp_coord = (Sqr(i * step) + Sqr(j * step)) / (2 * Sqr(m_sigmaCoord));
                                float exp_color = Sqr(Luminance(interColor(x, y)) - Luminance(interColor(_x, _y)))
                                                  / (2 * Sqr(m_sigmaColor));
                                float exp_normal = Sqr(SafeAcos(Dot(frameInfo.m_normal(x, y), frameInfo.m_normal(_x, _y))))
                                                   / (2 * Sqr(m_sigmaNormal));
                                float exp_plane = Sqr(Dot(Normalize(frameInfo.m_position(_x, _y) - frameInfo.m_position(x, y)),
                                                          frameInfo.m_normal(x, y))) / (2 * Sqr(m_sigmaPlane));
                                weight = std::expf(-(exp_coord + exp_color + exp_normal + exp_plane));
                            }
                            filtered_sum += interColor(_x, _y) * weight;
                            weight_sum += weight;
                        }
                    }
                    filteredImage(x, y) = filtered_sum / weight_sum;
                }
            }
            interColor.Copy(filteredImage);
         }
    }
    else {
        // brute force filtering:
#pragma omp parallel for
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                if (frameInfo.m_id(x, y) == -1) continue;
                float weight_sum = 0.0;
                Float3 filtered_sum = 0.0;
                for (int i = -kernelRadius; i <= kernelRadius; ++i) {
                    for (int j = -kernelRadius; j <= kernelRadius; ++j) {
                        auto _x = x + i, _y = y + j;
                        if (_x < 0 || _x >= width || _y < 0 || _y >= height)
                            continue;
                        if (frameInfo.m_id(_x, _y) == -1) continue;
                        float weight = 1.0;
                        if (x != _x || y != _y) {
                            float exp_coord = (Sqr(i) + Sqr(j)) / (2 * Sqr(m_sigmaCoord));
                            float exp_color = Sqr(Luminance(frameInfo.m_beauty(x, y)) - Luminance(frameInfo.m_beauty(_x, _y)))
                                              / (2 * Sqr(m_sigmaColor));
                            float exp_normal = Sqr(SafeAcos(Dot(frameInfo.m_normal(x, y), frameInfo.m_normal(_x, _y))))
                                               / (2 * Sqr(m_sigmaNormal));
                            float exp_plane = Sqr(Dot(Normalize(frameInfo.m_position(_x, _y) - frameInfo.m_position(x, y)),
                                                      frameInfo.m_normal(x, y))) / (2 * Sqr(m_sigmaPlane));
                            weight = std::expf(-(exp_coord + exp_color + exp_normal + exp_plane));
                        }
                        filtered_sum += frameInfo.m_beauty(_x, _y) * weight;
                        weight_sum += weight;
                    }
                }
                filteredImage(x, y) = filtered_sum / weight_sum;
            }
        }
    }

    return filteredImage;
}

void Denoiser::Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor) {
    m_accColor.Copy(filteredColor);
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    m_misc = CreateBuffer2D<Float3>(width, height);
    m_valid = CreateBuffer2D<bool>(width, height);
}

void Denoiser::Maintain(const FrameInfo &frameInfo) { m_preFrameInfo = frameInfo; }

Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo) {
    // Filter current frame
    Buffer2D<Float3> filteredColor;
    filteredColor = Filter(frameInfo);

    return filteredColor;

//    Buffer2D<Float3> filteredColor = CreateBuffer2D<Float3>(frameInfo.m_beauty.m_width, frameInfo.m_beauty.m_height);
//    filteredColor.Copy(frameInfo.m_beauty);

    // Reproject previous frame color to current
    if (m_useTemportal) {
        Reprojection(frameInfo);
        TemporalAccumulation(filteredColor);
    } else {
        Init(frameInfo, filteredColor);
    }

    // Maintain
    Maintain(frameInfo);
    if (!m_useTemportal) {
        m_useTemportal = true;
    }
    return m_accColor;
}
