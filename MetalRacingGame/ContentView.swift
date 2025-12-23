//
//  ContentView.swift
//  MetalRacingGame
//
//  Main view controller with Metal rendering
//

import SwiftUI
import MetalKit
import AppKit

struct ContentView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor()
    @StateObject private var hudManager = HUDManager()
    
    var body: some View {
        ZStack {
            MetalView(performanceMonitor: performanceMonitor, hudManager: hudManager)
                .frame(minWidth: 1280, minHeight: 720)
            
            // HUD overlay with DRS, tires, and pit limiter
            RacingHUD(
                speed: hudManager.speed,
                gear: hudManager.gear,
                mode: hudManager.mode,
                showLapTimer: hudManager.showLapTimer,
                lapTime: hudManager.lapTime,
                drsState: hudManager.drsState,
                tireCompound: hudManager.tireCompound,
                tireWear: hudManager.tireWear,
                isPitLimiterActive: hudManager.isPitLimiterActive,
                isLowBatteryModeActive: Settings.shared.isLowBatteryMode
            )
            
            // Debug UI overlay
            VStack {
                HStack {
                    DebugUI(performanceMonitor: performanceMonitor)
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            // Set hardware info
            let detector = HardwareDetector.shared
            let caps = detector.getCapabilities()
            performanceMonitor.setHardwareInfo("\(caps.tier) - \(caps.gpuCoreCount) GPU cores")
        }
    }
}

struct MetalView: NSViewRepresentable {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    @ObservedObject var hudManager: HUDManager
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.delegate = context.coordinator
        view.preferredFramesPerSecond = 120 // ProMotion support
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        
        // Initialize engine
        let engine = MetalEngine.shared
        engine.initialize(metalView: view)
        engine.setHUDManager(hudManager)
        
        return view
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Handle updates
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.performanceMonitor = performanceMonitor
        coordinator.hudManager = hudManager
        return coordinator
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        private var lastFrameTime: CFTimeInterval = 0
        weak var performanceMonitor: PerformanceMonitor?
        weak var hudManager: HUDManager?
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            MetalEngine.shared.handleResize(size: size)
        }
        
        func draw(in view: MTKView) {
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastFrameTime
            lastFrameTime = currentTime
            
            // Cap delta time to prevent large jumps
            let clampedDelta = min(deltaTime, 1.0 / 30.0) // Max 30ms
            
            // Update engine
            MetalEngine.shared.update(deltaTime: clampedDelta)
            
            // Render
            let renderStart = CACurrentMediaTime()
            MetalEngine.shared.render(in: view)
            let renderEnd = CACurrentMediaTime()
            
            // Update performance metrics
            if let monitor = performanceMonitor {
                monitor.update(frameTime: clampedDelta, gpuTime: renderEnd - renderStart)
                monitor.setDrawCalls(1) // Will be updated with actual count
                monitor.setTriangles(100) // Will be updated with actual count
            }
        }
    }
}
