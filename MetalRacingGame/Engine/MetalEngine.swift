//
//  MetalEngine.swift
//  MetalRacingGame
//
//  Core engine with triple-buffered async rendering
//

import Metal
import MetalKit
import AppKit
import simd

/// Main game engine coordinating all systems
class MetalEngine {
    static let shared = MetalEngine()
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let capabilities: HardwareCapabilities
    
    private var renderer: MetalRenderer?
    private var rayTracingRenderer: RayTracingRenderer?
    private var physicsEngine: PhysicsEngine
    private var inputManager: InputManager
    private var racingGame: RacingGame?
    private var hudManager: HUDManager?
    
    private var frameCount: UInt64 = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimeHistory: [CFTimeInterval] = []
    
    // Triple buffering
    private let inFlightSemaphore = DispatchSemaphore(value: 3)
    private var frameIndex: Int = 0
    
    private init() {
        // Initialize hardware detection
        let detector = HardwareDetector.shared
        self.device = detector.getDevice()
        self.capabilities = detector.getCapabilities()
        
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        self.commandQueue = queue
        
        // Initialize subsystems
        self.physicsEngine = PhysicsEngine()
        self.inputManager = InputManager.shared
        
        print("Metal Engine initialized")
        print("Device: \(device.name)")
    }
    
    /// Initialize rendering with Metal view
    func initialize(metalView: MTKView) {
        // Create renderer (will initialize pipeline cache)
        self.renderer = MetalRenderer(device: device, view: metalView, capabilities: capabilities)
        
        // Warmup all shaders upfront (eliminates runtime compilation stutter)
        // This is critical for Metal 4 compilation workflow
        if let renderer = renderer {
            renderer.warmupShaders()
        }
        
        // Create ray tracing renderer if supported (Metal 4 path when available)
        if capabilities.hasRayTracing {
            self.rayTracingRenderer = RayTracingRenderer(
                device: device,
                capabilities: capabilities,
                metal4: capabilities.metal4
            )
            renderer?.setRayTracingRenderer(rayTracingRenderer!)
        }
        
        // Get track from renderer
        let track = renderer?.getTrack()
        
        // Initialize game
        self.racingGame = RacingGame(
            physicsEngine: physicsEngine,
            inputManager: inputManager,
            capabilities: capabilities,
            track: track,
            hudManager: hudManager
        )
        
        // Setup MetalFX if available
        if capabilities.hasMetalFX {
            // MetalFX will be initialized by renderer
        }
        
        print("Rendering initialized")
    }
    
    /// Set HUD manager
    func setHUDManager(_ manager: HUDManager) {
        self.hudManager = manager
        racingGame?.setHUDManager(manager)
    }
    
    /// Main update loop (called from view controller)
    func update(deltaTime: CFTimeInterval) {
        // Update frame timing
        frameCount += 1
        lastFrameTime = deltaTime
        frameTimeHistory.append(deltaTime)
        if frameTimeHistory.count > 60 {
            frameTimeHistory.removeFirst()
        }
        
        // Update input
        inputManager.update()
        
        // Update physics
        physicsEngine.update(deltaTime: Float(deltaTime))
        
        // Update game logic
        racingGame?.update(deltaTime: Float(deltaTime))
    }
    
    /// Render frame (called from MTKViewDelegate)
    func render(in view: MTKView) {
        // Wait for available frame buffer (triple buffering)
        _ = inFlightSemaphore.wait(timeout: .distantFuture)
        
        frameIndex = (frameIndex + 1) % 3
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            inFlightSemaphore.signal()
            return
        }
        
        // Add completion handler for triple buffering
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inFlightSemaphore.signal()
        }
        
        // Render
        renderer?.render(
            commandBuffer: commandBuffer,
            frameIndex: frameIndex,
            game: racingGame
        )
        
        // Adaptive quality adjustment for ray tracing (based on frame timing)
        if let rayTracingRenderer = rayTracingRenderer {
            let currentFPS = getFPS()
            rayTracingRenderer.adjustQuality(targetFPS: 60.0, currentFPS: currentFPS)
            rayTracingRenderer.disableIfNeeded(currentFPS: currentFPS, minAcceptableFPS: 30.0)
        }
        
        // Present
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
    
    /// Get current FPS
    func getFPS() -> Double {
        guard !frameTimeHistory.isEmpty else { return 0 }
        let avgFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        return 1.0 / avgFrameTime
    }
    
    /// Get frame time in milliseconds
    func getFrameTime() -> Double {
        return lastFrameTime * 1000.0
    }
    
    /// Handle window resize
    func handleResize(size: CGSize) {
        renderer?.handleResize(size: size)
        rayTracingRenderer?.handleResize(size: size)
    }
    
    /// Cleanup
    deinit {
        // Wait for all frames to complete
        for _ in 0..<3 {
            _ = inFlightSemaphore.wait(timeout: .distantFuture)
        }
    }
}

