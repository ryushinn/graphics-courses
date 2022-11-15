# Real-time High Quality Rendering

## 5 Denoising in Real-time Ray Tracing

Implemented spatio-temporal filtering techniques widely used in RTRT

- Spatial denoising: joint bilateral filtering with growing kernel size (À-Trous Wavelet)
- Temporal denoising: projection by motion vector

![room-diff](hw5/results/room-diff.png)\

| Raw                                 | Denoised                                 |
| ----------------------------------- | ---------------------------------------- |
| ![box-raw](hw5/results/box-raw.gif) | ![box-raw](hw5/results/box-filtered.gif) |
