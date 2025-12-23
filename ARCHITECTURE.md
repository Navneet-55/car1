# Metal Racing Game - Architecture Documentation

## Overview

A high-performance Metal 3 racing game engine built specifically for Apple Silicon (M1-M4+). The engine is designed with a modular architecture, triple-buffered rendering, and adaptive quality scaling.

## Core Architecture

### Engine Layer (`Engine/`)

#### `MetalEngine.swift`
- **Purpose**: Main engine coordinator
- **Responsibilities**:
  - Initializes all subsystems
  - Manages frame loop and timing
  - Triple-buffered command buffer management
  - FPS tracking and frame pacing

#### `HardwareDetector.swift`
- **Purpose**: Adaptive hardware detection and capability assessment
- **Features**:
  - Detects M1, M2, M3, M4 series chips
  - Estimates GPU core count
  - Checks ray tracing support (M3+)
  - Determines MetalFX availability
  - Provides quality presets based on hardware tier

#### `PhysicsEngine.swift`
- **Purpose**: Car physics simulation
- **Features**:
  - Car dynamics (throttle, brake, steering)
  - Gravity and collision (basic)
  - Multi-car physics support
  - GPU-friendly update structure

#### `InputManager.swift`
- **Purpose**: macOS-native input handling
- **Controls**:
  - Keyboard (WASD + Space)
  - Mouse/trackpad support
  - Smooth input interpolation

### Rendering Layer (`Rendering/`)

#### `MetalRenderer.swift`
- **Purpose**: Main Metal 3 rendering pipeline
- **Features**:
  - PBR (Physically Based Rendering) shaders
  - HDR pipeline
  - Triple-buffered uniform buffers
  - Depth testing and stencil support
  - Integration with ray tracing and MetalFX

#### `RayTracingRenderer.swift`
- **Purpose**: Hardware-accelerated ray tracing (M3+)
- **Features**:
  - Real-time reflections
  - Global illumination framework
  - Soft shadows
  - Graceful fallback for non-RT devices

#### `MetalFXUpscaler.swift`
- **Purpose**: MetalFX integration for upscaling and TAA
- **Features**:
  - Spatial upscaling
  - Temporal anti-aliasing
  - Performance optimization
  - Placeholder for full MetalFX framework integration

#### `ParticleSystem.swift`
- **Purpose**: GPU-driven particle effects
- **Features**:
  - Smoke, sparks, debris particles
  - Compute shader-based updates
  - Efficient GPU memory usage
  - Configurable particle types

### Game Layer (`Game/`)

#### `RacingGame.swift`
- **Purpose**: Main game logic coordinator
- **Features**:
  - Player car management
  - AI car system
  - Game state management
  - Camera coordination

#### `Car.swift`
- **Purpose**: Car entity representation
- **Features**:
  - Physics state integration
  - Input handling
  - Visual properties (color, model)
  - Speed tracking

#### `Camera.swift`
- **Purpose**: Dynamic camera systems
- **Modes**:
  - **Chase**: Follows car from behind
  - **Cockpit**: First-person view
  - **Cinematic**: Dynamic cinematic angles
- **Features**:
  - Smooth interpolation
  - Configurable parameters
  - Aspect ratio support

## Rendering Pipeline

### Frame Flow

1. **Update Phase** (`MetalEngine.update`)
   - Input processing
   - Physics simulation
   - Game logic update
   - Camera update

2. **Render Phase** (`MetalEngine.render`)
   - Wait for available frame buffer (triple buffering)
   - Create command buffer
   - Update uniforms
   - Render geometry (PBR)
   - Ray tracing pass (if enabled)
   - MetalFX upscaling (if enabled)
   - Present drawable

### Triple Buffering

- Three command buffers in flight
- Semaphore-based synchronization
- Prevents CPU-GPU blocking
- Ensures smooth 60-120 FPS

### Shader Pipeline

#### Vertex Shader (`vertex_main`)
- Transforms vertices
- Calculates world position
- Passes data to fragment shader

#### Fragment Shader (`fragment_main`)
- PBR lighting calculation
- HDR tone mapping
- Gamma correction
- Outputs final color

#### Compute Shaders
- `ray_tracing_compute`: Ray tracing fallback
- `update_particles`: GPU particle updates

## Hardware Compatibility

### M1 Series
- **Base**: 8 GPU cores, Medium quality
- **Pro**: 16 GPU cores, Medium quality
- **Max**: 32 GPU cores, High quality
- **Ray Tracing**: ❌
- **MetalFX**: ✅ (macOS 13.0+)

### M2 Series
- **Base**: 8 GPU cores, High quality
- **Pro**: 19 GPU cores, High quality
- **Max**: 38 GPU cores, High quality
- **Ray Tracing**: ❌
- **MetalFX**: ✅

### M3 Series
- **Base**: 10 GPU cores, High quality
- **Pro**: 19 GPU cores, Ultra quality
- **Max**: 40 GPU cores, Ultra quality
- **Ray Tracing**: ✅
- **MetalFX**: ✅

### M4 Series
- **Base**: 10 GPU cores, Ultra quality
- **Pro**: 30 GPU cores, Ultra quality
- **Max**: 60 GPU cores, Ultra quality
- **Ray Tracing**: ✅
- **MetalFX**: ✅

## Performance Optimizations

1. **Triple Buffering**: Eliminates frame stutter
2. **Async Rendering**: Non-blocking CPU-GPU communication
3. **GPU-Driven Systems**: Particles, culling, instancing
4. **Adaptive Quality**: Automatic LOD based on hardware
5. **MetalFX Upscaling**: Render at lower resolution, upscale
6. **Efficient Memory**: Unified memory utilization

## Future Enhancements

### High Priority
- Full MetalFX framework integration
- Complete ray tracing implementation
- Track geometry and collision
- Advanced AI pathfinding
- Audio system integration

### Medium Priority
- Weather system (rain, fog)
- Motion blur and depth of field
- Advanced particle effects
- Asset streaming system
- Debug UI and profiling tools

### Low Priority
- Multiplayer support
- Replay system
- Photo mode
- Custom track editor

## Code Quality Standards

- ✅ Zero deprecated APIs
- ✅ Memory safety (bounds checking)
- ✅ Error handling and logging
- ✅ Modular architecture
- ✅ Clear separation of concerns
- ✅ Deterministic frame execution

## Build Configuration

- **Minimum macOS**: 13.0 (Ventura)
- **Target**: Apple Silicon only
- **Metal Version**: 3.0
- **Swift Version**: 5.0
- **Xcode Version**: 15.0+

## Testing Strategy

1. **Hardware Testing**: Test on M1, M2, M3, M4 devices
2. **Performance Profiling**: Metal System Trace
3. **Memory Profiling**: Instruments
4. **Frame Pacing**: Verify 60-120 FPS consistency
5. **Feature Testing**: Ray tracing, MetalFX on supported devices

