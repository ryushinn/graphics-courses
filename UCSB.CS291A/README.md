# Real-time High Quality Rendering

## 4 The Kulla-Conty Microfacet BRDF

Implemented the Kulla-Conty approximation on energy-preserving for the microfacet BRDF.

References:

- Christopher Kulla and Alejandro Conty, [Revisiting Physically Based Shading at Imageworks](https://fpsunflower.github.io/ckulla/data/s2017_pbs_imageworks_slides_v2.pdf), SIGGRAPH 2017 course
- Walter et al., [Microfacet Models for Refraction through Rough Surfaces](https://www.graphics.cornell.edu/~bjw/microfacetbsdf.pdf), EGSR 2007

This figure shows the energy compensation by the KC approximation.

![KullaConty](hw4/images/KullaConty.png)

The roughness increases from left to right. The first row is a bit brighter than the second row which does not have compensation.

There is also a White Furnace Test for fun :)

|$F_0$=Gold | $F_0$=White (no energy absorption, so *invisible* matpreview balls!) |
| - | - |
| ![gold](hw4/images/WFT(Gold).png)  | ![1.0](hw4/images/white%20furnace%20test.gif)  |

## 5 Denoising in Real-time Ray Tracing

Implemented spatio-temporal filtering techniques widely used in RTRT

- Spatial denoising: joint bilateral filtering with growing kernel size (À-Trous Wavelet)
- Temporal denoising: projection by motion vectors

![room-diff](hw5/results/room-diff.png)

| Raw                                 | Denoised                                 |
| ----------------------------------- | ---------------------------------------- |
| ![box-raw](hw5/results/box-raw.gif) | ![box-raw](hw5/results/box-filtered.gif) |
