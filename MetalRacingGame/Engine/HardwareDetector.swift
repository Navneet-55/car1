//
//  HardwareDetector.swift
//  MetalRacingGame
//
//  Adaptive hardware detection for Apple Silicon (M1-M4+)
//

import Metal
import MetalKit
import Foundation

/// Hardware capabilities and tier detection for adaptive rendering
struct HardwareCapabilities {
    let gpuCoreCount: Int
    let hasUnifiedMemory: Bool
    let hasRayTracing: Bool
    let hasMetalFX: Bool
    let memoryBandwidth: Int64 // GB/s
    let tier: HardwareTier
    
    enum HardwareTier: Int, Comparable {
        case m1 = 1
        case m1Pro = 2
        case m1Max = 3
        case m2 = 4
        case m2Pro = 5
        case m2Max = 6
        case m3 = 7
        case m3Pro = 8
        case m3Max = 9
        case m4 = 10
        case m4Pro = 11
        case m4Max = 12
        
        static func < (lhs: HardwareTier, rhs: HardwareTier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

class HardwareDetector {
    static let shared = HardwareDetector()
    
    private let device: MTLDevice
    private var capabilities: HardwareCapabilities?
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this system")
        }
        self.device = device
        detectCapabilities()
    }
    
    /// Get detected hardware capabilities
    func getCapabilities() -> HardwareCapabilities {
        return capabilities!
    }
    
    /// Get Metal device
    func getDevice() -> MTLDevice {
        return device
    }
    
    /// Check if ray tracing is supported
    func supportsRayTracing() -> Bool {
        return capabilities?.hasRayTracing ?? false
    }
    
    /// Check if MetalFX is available
    func supportsMetalFX() -> Bool {
        return capabilities?.hasMetalFX ?? false
    }
    
    /// Get recommended render quality settings
    func getRecommendedQuality() -> RenderQuality {
        guard let caps = capabilities else {
            return .medium
        }
        
        switch caps.tier {
        case .m1, .m1Pro:
            return .medium
        case .m1Max, .m2:
            return .high
        case .m2Pro, .m2Max, .m3:
            return .high
        case .m3Pro, .m3Max, .m4:
            return .ultra
        case .m4Pro, .m4Max:
            return .ultra
        }
    }
    
    private func detectCapabilities() {
        // Detect GPU core count (approximate)
        let gpuCoreCount = estimateGPUCoreCount()
        
        // Unified memory is always available on Apple Silicon
        let hasUnifiedMemory = true
        
        // Ray tracing support (M3+)
        let hasRayTracing = device.supportsRaytracing
        
        // MetalFX support (macOS 13.0+)
        let hasMetalFX = MTKView.instancesRespond(to: Selector(("metalFXUpscaler")))
        
        // Estimate memory bandwidth based on tier
        let memoryBandwidth = estimateMemoryBandwidth()
        
        // Detect hardware tier
        let tier = detectHardwareTier(gpuCoreCount: gpuCoreCount, hasRayTracing: hasRayTracing)
        
        capabilities = HardwareCapabilities(
            gpuCoreCount: gpuCoreCount,
            hasUnifiedMemory: hasUnifiedMemory,
            hasRayTracing: hasRayTracing,
            hasMetalFX: hasMetalFX,
            memoryBandwidth: memoryBandwidth,
            tier: tier
        )
        
        print("Hardware Detection:")
        print("  Tier: \(tier)")
        print("  GPU Cores: \(gpuCoreCount)")
        print("  Ray Tracing: \(hasRayTracing)")
        print("  MetalFX: \(hasMetalFX)")
        print("  Memory Bandwidth: \(memoryBandwidth) GB/s")
    }
    
    private func estimateGPUCoreCount() -> Int {
        // Query device properties to estimate core count
        // This is approximate as Apple doesn't expose exact counts
        let deviceName = device.name.lowercased()
        
        if deviceName.contains("m4") {
            if deviceName.contains("max") {
                return 60 // M4 Max
            } else if deviceName.contains("pro") {
                return 30 // M4 Pro
            }
            return 10 // M4 base
        } else if deviceName.contains("m3") {
            if deviceName.contains("max") {
                return 40 // M3 Max
            } else if deviceName.contains("pro") {
                return 19 // M3 Pro
            }
            return 10 // M3 base
        } else if deviceName.contains("m2") {
            if deviceName.contains("max") {
                return 38 // M2 Max
            } else if deviceName.contains("pro") {
                return 19 // M2 Pro
            }
            return 8 // M2 base
        } else if deviceName.contains("m1") {
            if deviceName.contains("max") {
                return 32 // M1 Max
            } else if deviceName.contains("pro") {
                return 16 // M1 Pro
            }
            return 8 // M1 base
        }
        
        // Fallback: estimate from device memory
        let maxMemory = device.recommendedMaxWorkingSetSize
        if maxMemory >= 32 * 1024 * 1024 * 1024 { // 32GB+
            return 30
        } else if maxMemory >= 16 * 1024 * 1024 * 1024 { // 16GB+
            return 20
        }
        return 8
    }
    
    private func estimateMemoryBandwidth() -> Int64 {
        let tier = detectHardwareTier(gpuCoreCount: estimateGPUCoreCount(), hasRayTracing: device.supportsRaytracing)
        
        switch tier {
        case .m1: return 68
        case .m1Pro: return 200
        case .m1Max: return 400
        case .m2: return 100
        case .m2Pro: return 200
        case .m2Max: return 400
        case .m3: return 100
        case .m3Pro: return 150
        case .m3Max: return 300
        case .m4: return 120
        case .m4Pro: return 200
        case .m4Max: return 400
        }
    }
    
    private func detectHardwareTier(gpuCoreCount: Int, hasRayTracing: Bool) -> HardwareCapabilities.HardwareTier {
        let deviceName = device.name.lowercased()
        
        // M4 series
        if deviceName.contains("m4") {
            if deviceName.contains("max") {
                return .m4Max
            } else if deviceName.contains("pro") {
                return .m4Pro
            }
            return .m4
        }
        
        // M3 series (first with ray tracing)
        if deviceName.contains("m3") {
            if deviceName.contains("max") {
                return .m3Max
            } else if deviceName.contains("pro") {
                return .m3Pro
            }
            return .m3
        }
        
        // M2 series
        if deviceName.contains("m2") {
            if deviceName.contains("max") {
                return .m2Max
            } else if deviceName.contains("pro") {
                return .m2Pro
            }
            return .m2
        }
        
        // M1 series
        if deviceName.contains("m1") {
            if deviceName.contains("max") {
                return .m1Max
            } else if deviceName.contains("pro") {
                return .m1Pro
            }
            return .m1
        }
        
        // Fallback based on capabilities
        if hasRayTracing {
            return .m3 // Assume M3 if ray tracing available
        }
        if gpuCoreCount >= 30 {
            return .m2Max
        } else if gpuCoreCount >= 15 {
            return .m2Pro
        }
        return .m1
    }
}

/// Render quality presets
enum RenderQuality {
    case low
    case medium
    case high
    case ultra
    
    var rayTracingEnabled: Bool {
        switch self {
        case .low, .medium:
            return false
        case .high, .ultra:
            return true
        }
    }
    
    var shadowQuality: Int {
        switch self {
        case .low: return 512
        case .medium: return 1024
        case .high: return 2048
        case .ultra: return 4096
        }
    }
    
    var particleCount: Int {
        switch self {
        case .low: return 1000
        case .medium: return 5000
        case .high: return 10000
        case .ultra: return 20000
        }
    }
}

