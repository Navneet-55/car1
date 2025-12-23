//
//  PitStopSystem.swift
//  MetalRacingGame
//
//  Strategic pit stop system with tire changes and speed limiter
//

import Foundation
import simd

/// Tire compound types (FIA standard)
enum TireCompound: String, CaseIterable {
    case soft = "SOFT"
    case medium = "MEDIUM"
    case hard = "HARD"
    
    var color: SIMD3<Float> {
        switch self {
        case .soft: return SIMD3<Float>(1.0, 0.2, 0.2) // Red
        case .medium: return SIMD3<Float>(1.0, 0.8, 0.0) // Yellow
        case .hard: return SIMD3<Float>(1.0, 1.0, 1.0) // White
        }
    }
    
    var gripMultiplier: Float {
        switch self {
        case .soft: return 1.15 // +15% grip
        case .medium: return 1.0 // Baseline
        case .hard: return 0.90 // -10% grip
        }
    }
    
    var wearRate: Float {
        switch self {
        case .soft: return 1.5 // Wears 50% faster
        case .medium: return 1.0 // Baseline
        case .hard: return 0.6 // Wears 40% slower
        }
    }
    
    var optimalTemp: Float {
        switch self {
        case .soft: return 90.0 // °C
        case .medium: return 100.0
        case .hard: return 110.0
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

/// Pit stop state
enum PitStopState {
    case racing // Normal racing
    case approachingPit // In pit entry zone
    case pitLaneEntry // Entering pit lane
    case pitLane // In pit lane with speed limiter
    case stopping // Slowing to pit box
    case stopped // At pit box
    case tireChange // Changing tires
    case releasing // Being released
    case pitLaneExit // Exiting pit lane
}

/// Tire state
struct TireState {
    var compound: TireCompound = .medium
    var wear: Float = 0.0 // 0-100%
    var temperature: Float = 80.0 // °C
    var grip: Float = 1.0 // Current grip level
    
    /// Calculate current grip based on wear, temp, and compound
    mutating func updateGrip() {
        // Base grip from compound
        var baseGrip = compound.gripMultiplier
        
        // Wear penalty (grip drops significantly above 70% wear)
        let wearPenalty: Float
        if wear < 50 {
            wearPenalty = 0
        } else if wear < 70 {
            wearPenalty = (wear - 50) / 100.0 // 0-20% penalty
        } else {
            wearPenalty = 0.2 + (wear - 70) / 50.0 // 20-80% penalty (cliff)
        }
        
        // Temperature window (optimal temp ± 15°C)
        let tempDiff = abs(temperature - compound.optimalTemp)
        let tempPenalty = max(0, (tempDiff - 15) / 50.0) // Penalty outside window
        
        grip = baseGrip * (1.0 - wearPenalty) * (1.0 - tempPenalty)
        grip = max(0.3, min(1.2, grip)) // Clamp grip
    }
}

/// Pit stop system
class PitStopSystem {
    // Current state
    private(set) var state: PitStopState = .racing
    private(set) var isPitLimiterActive: Bool = false
    
    // Tire state
    private(set) var currentTires = TireState()
    private(set) var selectedCompound: TireCompound = .medium
    
    // Pit lane parameters
    let pitLaneSpeedLimit: Float = 80.0 // km/h
    let pitLaneEntryDistance: Float = 4500.0 // Track distance for pit entry
    let pitLaneExitDistance: Float = 100.0 // Track distance for pit exit
    let pitBoxPosition: SIMD3<Float> = SIMD3<Float>(50, 0, 4600) // Pit box location
    
    // Pit stop timing
    private var pitStopTimer: Float = 0
    private let basePitStopDuration: Float = 2.5 // Base tire change time
    private let tireChangeDuration: Float = 2.0 // Per set
    
    // Animation
    private(set) var pitStopProgress: Float = 0 // 0-1 for animations
    
    // Track temperature (affects tire behavior)
    var trackTemperature: Float = 35.0 // °C
    
    init() {
        // Start with medium tires
        currentTires.compound = .medium
        currentTires.updateGrip()
    }
    
    /// Update pit stop system
    func update(deltaTime: Float, trackDistance: Float, speed: Float, position: SIMD3<Float>, pitButtonPressed: Bool) {
        // Update tire state
        updateTireState(deltaTime: deltaTime, speed: speed)
        
        // State machine
        switch state {
        case .racing:
            isPitLimiterActive = false
            if isNearPitEntry(trackDistance: trackDistance) && pitButtonPressed {
                state = .approachingPit
            }
            
        case .approachingPit:
            if !isNearPitEntry(trackDistance: trackDistance) {
                state = .racing // Aborted pit entry
            } else if isInPitLane(position: position) {
                state = .pitLaneEntry
                isPitLimiterActive = true
            }
            
        case .pitLaneEntry:
            isPitLimiterActive = true
            if speed <= pitLaneSpeedLimit + 5 {
                state = .pitLane
            }
            
        case .pitLane:
            isPitLimiterActive = true
            if isNearPitBox(position: position) {
                state = .stopping
            }
            
        case .stopping:
            isPitLimiterActive = true
            if speed < 5 {
                state = .stopped
                pitStopTimer = 0
            }
            
        case .stopped:
            isPitLimiterActive = true
            // Player can select tire compound here
            if pitButtonPressed {
                state = .tireChange
                pitStopTimer = 0
            }
            
        case .tireChange:
            isPitLimiterActive = true
            pitStopTimer += deltaTime
            pitStopProgress = pitStopTimer / (basePitStopDuration + tireChangeDuration)
            
            if pitStopTimer >= basePitStopDuration + tireChangeDuration {
                // Tire change complete
                applyTireChange()
                state = .releasing
                pitStopTimer = 0
            }
            
        case .releasing:
            isPitLimiterActive = true
            pitStopTimer += deltaTime
            if pitStopTimer >= 0.5 { // Brief release animation
                state = .pitLaneExit
            }
            
        case .pitLaneExit:
            isPitLimiterActive = true
            if !isInPitLane(position: position) {
                state = .racing
                isPitLimiterActive = false
            }
        }
    }
    
    /// Update tire state (wear, temperature, grip)
    private func updateTireState(deltaTime: Float, speed: Float) {
        // Wear increases with speed and compound
        let wearIncrease = (speed / 300.0) * currentTires.compound.wearRate * deltaTime * 0.1
        currentTires.wear = min(100, currentTires.wear + wearIncrease)
        
        // Temperature changes based on speed and track temp
        let targetTemp = trackTemperature + (speed / 300.0) * 70.0
        currentTires.temperature += (targetTemp - currentTires.temperature) * deltaTime * 0.5
        
        // Update grip
        currentTires.updateGrip()
    }
    
    /// Check if near pit entry
    private func isNearPitEntry(trackDistance: Float) -> Bool {
        return abs(trackDistance - pitLaneEntryDistance) < 200
    }
    
    /// Check if in pit lane
    private func isInPitLane(position: SIMD3<Float>) -> Bool {
        // Simple pit lane check (offset from main track)
        return position.x > 30 && position.x < 80
    }
    
    /// Check if near pit box
    private func isNearPitBox(position: SIMD3<Float>) -> Bool {
        return length(position - pitBoxPosition) < 10
    }
    
    /// Apply tire change
    private func applyTireChange() {
        currentTires.compound = selectedCompound
        currentTires.wear = 0
        currentTires.temperature = 70.0 // Fresh tires start cooler
        currentTires.updateGrip()
    }
    
    /// Select tire compound (while stopped)
    func selectCompound(_ compound: TireCompound) {
        if state == .stopped {
            selectedCompound = compound
        }
    }
    
    /// Cycle to next compound
    func cycleCompound() {
        let compounds = TireCompound.allCases
        if let currentIndex = compounds.firstIndex(of: selectedCompound) {
            let nextIndex = (currentIndex + 1) % compounds.count
            selectedCompound = compounds[nextIndex]
        }
    }
    
    /// Get speed limit (pit limiter)
    func getSpeedLimit() -> Float? {
        return isPitLimiterActive ? pitLaneSpeedLimit : nil
    }
    
    /// Get current grip multiplier
    func getGripMultiplier() -> Float {
        return currentTires.grip
    }
    
    /// Get tire color for rendering
    func getTireColor() -> SIMD3<Float> {
        return currentTires.compound.color
    }
    
    /// Check if currently in pit stop sequence
    func isInPitSequence() -> Bool {
        return state != .racing
    }
    
    /// Get pit stop duration estimate
    func getEstimatedPitDuration() -> Float {
        return basePitStopDuration + tireChangeDuration
    }
    
    /// Request pit entry
    func requestPitEntry() {
        if state == .racing {
            state = .approachingPit
        }
    }
    
    /// Abort pit entry
    func abortPitEntry() {
        if state == .approachingPit {
            state = .racing
        }
    }
}

