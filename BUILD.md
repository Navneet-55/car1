# Building Metal Racing Game

## Prerequisites

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1, M2, M3, M4, or compatible)
- Xcode 15.0 or later
- Metal 3 support

## Building

1. Open `MetalRacingGame.xcodeproj` in Xcode
2. Select your target device/simulator (Apple Silicon only)
3. Build and run (⌘R)

## Project Structure

```
MetalRacingGame/
├── Engine/              # Core engine systems
│   ├── MetalEngine.swift
│   ├── HardwareDetector.swift
│   ├── PhysicsEngine.swift
│   └── InputManager.swift
├── Rendering/           # Metal rendering pipeline
│   ├── MetalRenderer.swift
│   ├── RayTracingRenderer.swift
│   ├── MetalFXUpscaler.swift
│   └── ParticleSystem.swift
├── Game/                # Game logic
│   ├── RacingGame.swift
│   ├── Car.swift
│   └── Camera.swift
├── Shaders/             # Metal shaders
│   └── Shaders.metal
└── MetalRacingGameApp.swift  # App entry point
```

## Features

### Implemented
- ✅ Metal 3 rendering pipeline
- ✅ Hardware detection (M1-M4+)
- ✅ Triple-buffered async rendering
- ✅ PBR shaders
- ✅ Physics engine
- ✅ Input handling (keyboard)
- ✅ Camera systems (chase, cockpit, cinematic)
- ✅ Particle system framework
- ✅ Ray tracing framework (M3+)

### To Be Enhanced
- MetalFX integration (requires proper framework)
- Full ray tracing implementation
- Advanced AI
- Track geometry
- Audio system
- Asset streaming

## Controls

- **W**: Throttle
- **S**: Brake
- **A**: Steer left
- **D**: Steer right
- **Space**: Handbrake

## Performance

The game automatically detects your hardware and adjusts quality settings:
- **M1/M1 Pro**: Medium quality
- **M1 Max/M2**: High quality
- **M2 Pro/M2 Max/M3**: High quality
- **M3 Pro/M3 Max/M4+**: Ultra quality

Ray tracing is automatically enabled on M3+ devices.

