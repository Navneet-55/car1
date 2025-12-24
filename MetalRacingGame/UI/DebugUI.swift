//
//  DebugUI.swift
//  MetalRacingGame
//
//  Debug overlay with performance metrics
//

import SwiftUI
import MetalKit

struct DebugUI: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Metal Racing Game - Debug")
                .font(.headline)
                .foregroundColor(.white)
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FPS: \(Int(performanceMonitor.fps))")
                    Text("Frame Time: \(String(format: "%.2f", performanceMonitor.frameTime))ms")
                    Text("GPU Time: \(String(format: "%.2f", performanceMonitor.gpuTime))ms")
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Draw Calls: \(performanceMonitor.drawCalls)")
                    Text("Triangles: \(performanceMonitor.triangles)")
                    Text("Particles: \(performanceMonitor.particles)")
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white)
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            Text("Hardware: \(performanceMonitor.hardwareInfo)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Controls:")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Text("WASD: Drive  |  Space: Brake")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Text("E: DRS  |  P: Pit  |  T: Change Tires")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .padding()
    }
}

class PerformanceMonitor: ObservableObject {
    @Published var fps: Double = 0
    @Published var frameTime: Double = 0
    @Published var gpuTime: Double = 0
    @Published var drawCalls: Int = 0
    @Published var triangles: Int = 0
    @Published var particles: Int = 0
    @Published var hardwareInfo: String = ""
    
    private var frameTimeHistory: [CFTimeInterval] = []
    private let maxHistory = 60
    
    func update(frameTime: CFTimeInterval, gpuTime: CFTimeInterval? = nil) {
        frameTimeHistory.append(frameTime)
        if frameTimeHistory.count > maxHistory {
            frameTimeHistory.removeFirst()
        }
        
        self.frameTime = frameTime * 1000.0 // Convert to ms
        if let gpu = gpuTime {
            self.gpuTime = gpu * 1000.0
        }
        
        if !frameTimeHistory.isEmpty {
            let avgFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
            self.fps = 1.0 / avgFrameTime
        }
    }
    
    func setHardwareInfo(_ info: String) {
        hardwareInfo = info
    }
    
    func setDrawCalls(_ count: Int) {
        drawCalls = count
    }
    
    func setTriangles(_ count: Int) {
        triangles = count
    }
    
    func setParticles(_ count: Int) {
        particles = count
    }
}



