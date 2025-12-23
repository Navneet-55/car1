//
//  PowerManager.swift
//  MetalRacingGame
//
//  Power and thermal management for Low Battery Mode
//  Monitors conditions and provides quality scaling recommendations
//

import Foundation
import IOKit.pwr_mgt

/// Thermal state
enum ThermalState {
    case normal
    case warning
    case critical
}

/// Power manager for thermal/power awareness
class PowerManager {
    static let shared = PowerManager()
    
    private var thermalState: ThermalState = .normal
    private var isLowPowerModeEnabled: Bool = false
    private var lowBatteryModeActive: Bool = false
    
    // Frame time tracking for quality adjustment
    private var frameTimeHistory: [CFTimeInterval] = []
    private let maxHistorySize = 60
    
    private init() {
        // Monitor thermal state
        startThermalMonitoring()
        
        // Monitor power state
        startPowerMonitoring()
        
        print("Power Manager initialized")
    }
    
    /// Start thermal monitoring
    private func startThermalMonitoring() {
        // In a real implementation, this would use IOKit to monitor thermal state
        // For now, we'll use a simple heuristic based on frame times
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateThermalState()
        }
    }
    
    /// Start power monitoring
    private func startPowerMonitoring() {
        // Check if low power mode is enabled
        // In a real implementation, this would check system power settings
        // For now, we'll rely on Settings.shared.isLowBatteryMode
    }
    
    /// Update thermal state based on performance
    private func updateThermalState() {
        guard !frameTimeHistory.isEmpty else { return }
        
        let avgFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        
        if avgFrameTime > 0.033 { // > 30ms (thermal throttling likely)
            thermalState = .critical
        } else if avgFrameTime > 0.025 { // > 40ms (warning)
            thermalState = .warning
        } else {
            thermalState = .normal
        }
    }
    
    /// Update frame time history
    func recordFrameTime(_ frameTime: CFTimeInterval) {
        frameTimeHistory.append(frameTime)
        if frameTimeHistory.count > maxHistorySize {
            frameTimeHistory.removeFirst()
        }
    }
    
    /// Get recommended quality scaling (0.0 to 1.0)
    func getRecommendedQualityScaling() -> Float {
        var scale: Float = 1.0
        
        // Reduce quality if thermal state is critical
        if thermalState == .critical {
            scale *= 0.7
        } else if thermalState == .warning {
            scale *= 0.85
        }
        
        // Reduce quality if low battery mode is active
        if lowBatteryModeActive {
            scale *= 0.8
        }
        
        // Reduce quality if frame times are high
        if !frameTimeHistory.isEmpty {
            let avgFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
            if avgFrameTime > 0.020 { // > 50ms
                scale *= 0.9
            }
        }
        
        return max(0.5, scale) // Never go below 50% quality
    }
    
    /// Get recommended ANE target (0.0 = disabled, 1.0 = full)
    func getRecommendedANETarget() -> Float {
        if lowBatteryModeActive {
            return 0.0 // Disable ANE in low battery mode
        }
        
        if thermalState == .critical {
            return 0.0 // Disable ANE if thermal critical
        } else if thermalState == .warning {
            return 0.5 // Throttle ANE if thermal warning
        }
        
        return 1.0 // Full ANE usage
    }
    
    /// Set low battery mode active
    func setLowBatteryModeActive(_ active: Bool) {
        lowBatteryModeActive = active
        if active {
            print("Power Manager: Low Battery Mode activated")
        } else {
            print("Power Manager: Low Battery Mode deactivated")
        }
    }
    
    /// Get thermal state
    func getThermalState() -> ThermalState {
        return thermalState
    }
    
    /// Get low battery mode status
    func isLowBatteryModeActive() -> Bool {
        return lowBatteryModeActive
    }
}

