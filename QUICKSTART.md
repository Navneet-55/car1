# Quick Start Guide

## Getting Started

1. **Open the Project**
   ```bash
   open MetalRacingGame.xcodeproj
   ```

2. **Select Target**
   - Choose "My Mac (Apple Silicon)" as the run destination
   - Ensure you're running on Apple Silicon (M1, M2, M3, or M4)

3. **Build and Run**
   - Press ⌘R or click the Run button
   - The game window will open at 1280x720

## Controls

- **W**: Accelerate
- **S**: Brake
- **A**: Steer left
- **D**: Steer right
- **Space**: Handbrake

## What You'll See

- A red car (player) that responds to input
- Three AI cars moving on the track
- Smooth camera following the player car
- PBR rendering with HDR lighting
- Hardware-accelerated ray tracing (if on M3+)

## Performance

The game automatically detects your hardware and adjusts:
- **M1/M1 Pro**: Medium quality, 60 FPS target
- **M1 Max/M2**: High quality, 60-120 FPS
- **M2 Pro/M2 Max/M3**: High quality, 120 FPS
- **M3 Pro/M3 Max/M4+**: Ultra quality, 120 FPS, Ray tracing enabled

## Troubleshooting

### "Metal is not supported"
- Ensure you're running on Apple Silicon
- Check macOS version (13.0+ required)

### Low FPS
- Check hardware detection output in console
- Verify you're not running in Debug mode (use Release)
- Close other GPU-intensive applications

### Ray Tracing Not Working
- Ray tracing requires M3 or later
- Check console for "Ray tracing not supported" message
- Game will run without ray tracing on older hardware

## Next Steps

- Add track geometry
- Implement advanced AI
- Add audio system
- Enhance particle effects
- Integrate full MetalFX framework

