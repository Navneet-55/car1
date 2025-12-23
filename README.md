# Metal Racing Game - macOS Apple Silicon

A high-performance, GPU-intensive car racing game built with Metal 3, designed for Apple Silicon (M1, M2, M3, M4+).

## Features

- **Metal 3 Rendering Pipeline**: PBR, HDR, hardware ray tracing
- **MetalFX Integration**: Upscaling and temporal anti-aliasing
- **Adaptive Performance**: Scales across M1-M4+ with feature detection
- **60-120 FPS**: Optimized for sustained high frame rates
- **Hardware Ray Tracing**: Real-time reflections, GI, soft shadows
- **GPU-Driven Systems**: Particles, culling, instancing

## Requirements

- macOS 13.0+ (Ventura or later)
- Apple Silicon (M1, M2, M3, M4, or compatible)
- Xcode 15.0+ with Metal 3 support

## Building

Open `MetalRacingGame.xcodeproj` in Xcode and build for your target architecture.

## Architecture

- `Engine/`: Core engine systems
- `Rendering/`: Metal 3 rendering pipeline
- `Physics/`: Car physics and collision
- `Game/`: Racing game logic
- `Shaders/`: Metal shader files

