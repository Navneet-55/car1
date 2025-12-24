//
//  DRSSystem.swift
//  MetalRacingGame
//
//  FIA-aligned Drag Reduction System
//

import Foundation
import simd

/// DRS zone definition
struct DRSZone {
    let id: Int
    let detectionPoint: Float // Track distance where availability is checked
    let activationStart: Float // Track distance where DRS can be activated
    let activationEnd: Float // Track distance where DRS zone ends
    let name: String
    
    func isInZone(trackDistance: Float) -> Bool {
        return trackDistance >= activationStart && trackDistance <= activationEnd
    }
    
    func canActivate(trackDistance: Float) -> Bool {
        return isInZone(trackDistance)
    }
}

/// DRS state
enum DRSState {
    case unavailable // Not in DRS zone or conditions not met
    case available // In DRS zone, can be activated
    case active // DRS is open
    case cooldown // Brief cooldown after closing
}

/// FIA-aligned DRS system
class DRSSystem {
    // DRS state
    private(set) var state: DRSState = .unavailable
    private(set) var isOpen: Bool = false
    
    // DRS zones (Silverstone has 2 DRS zones)
    private var zones: [DRSZone] = []
    private var currentZone: DRSZone? = nil
    
    // DRS physics effects
    let topSpeedBoost: Float = 15.0 // km/h top speed increase
    let dragReduction: Float = 0.25 // 25% drag reduction when open
    
    // Auto-disable thresholds (FIA rules)
    private let brakingThreshold: Float = 0.1 // DRS closes if braking > 10%
    private let steeringThreshold: Float = 0.3 // DRS closes if steering > 30%
    
    // Cooldown
    private var cooldownTimer: Float = 0
    private let cooldownDuration: Float = 0.5 // 0.5s cooldown after closing
    
    // Wing animation
    private(set) var wingAngle: Float = 0 // 0 = closed, 1 = open
    private let wingOpenSpeed: Float = 5.0 // Opens in ~0.2s
    private let wingCloseSpeed: Float = 8.0 // Closes in ~0.125s
    
    init() {
        setupSilverstoneZones()
    }
    
    /// Setup DRS zones for Silverstone
    private func setupSilverstoneZones() {
        // Silverstone has 2 DRS zones:
        // 1. Wellington Straight (after Turn 5)
        // 2. Hangar Straight (after Chapel)
        
        // Zone 1: Wellington Straight
        zones.append(DRSZone(
            id: 1,
            detectionPoint: 1200.0, // Detection before Turn 5
            activationStart: 1400.0,
            activationEnd: 2100.0,
            name: "Wellington Straight"
        ))
        
        // Zone 2: Hangar Straight
        zones.append(DRSZone(
            id: 2,
            detectionPoint: 3500.0, // Detection before Chapel
            activationStart: 3700.0,
            activationEnd: 4800.0,
            name: "Hangar Straight"
        ))
    }
    
    /// Update DRS system state
    func update(deltaTime: Float, trackDistance: Float, speed: Float, braking: Float, steering: Float, drsButtonPressed: Bool) {
        // Update cooldown
        if cooldownTimer > 0 {
            cooldownTimer -= deltaTime
            if cooldownTimer <= 0 {
                cooldownTimer = 0
                state = .unavailable
            }
        }
        
        // Check if in any DRS zone
        var inZone = false
        for zone in zones {
            if zone.canActivate(trackDistance: trackDistance) {
                inZone = true
                currentZone = zone
                break
            }
        }
        
        if !inZone {
            currentZone = nil
        }
        
        // State machine
        switch state {
        case .unavailable:
            if inZone {
                state = .available
            }
            // Close wing if open
            if isOpen {
                closeDRS()
            }
            
        case .available:
            if !inZone {
                state = .unavailable
            } else if drsButtonPressed && canActivateDRS(braking: braking, steering: steering) {
                activateDRS()
            }
            
        case .active:
            // Check auto-disable conditions
            if shouldAutoDisable(braking: braking, steering: steering, inZone: inZone) {
                deactivateDRS()
            }
            
        case .cooldown:
            // Wait for cooldown to expire
            break
        }
        
        // Update wing animation
        updateWingAnimation(deltaTime: deltaTime)
    }
    
    /// Reset DRS system to initial state
    func reset() {
        state = .unavailable
        isOpen = false
        currentZone = nil
        cooldownTimer = 0
        wingAngle = 0
    }
    
    /// Check if DRS can be activated
    private func canActivateDRS(braking: Float, steering: Float) -> Bool {
        return braking < brakingThreshold && abs(steering) < steeringThreshold
    }
    
    /// Check if DRS should auto-disable
    private func shouldAutoDisable(braking: Float, steering: Float, inZone: Bool) -> Bool {
        // DRS auto-disables under:
        // 1. Braking
        // 2. Excessive steering
        // 3. Exiting the DRS zone
        return braking >= brakingThreshold || abs(steering) >= steeringThreshold || !inZone
    }
    
    /// Activate DRS
    private func activateDRS() {
        isOpen = true
        state = .active
    }
    
    /// Deactivate DRS
    private func deactivateDRS() {
        closeDRS()
        state = .cooldown
        cooldownTimer = cooldownDuration
    }
    
    /// Close DRS wing
    private func closeDRS() {
        isOpen = false
    }
    
    /// Update wing animation
    private func updateWingAnimation(deltaTime: Float) {
        let targetAngle: Float = isOpen ? 1.0 : 0.0
        let speed = isOpen ? wingOpenSpeed : wingCloseSpeed
        
        if wingAngle < targetAngle {
            wingAngle = min(wingAngle + speed * deltaTime, targetAngle)
        } else if wingAngle > targetAngle {
            wingAngle = max(wingAngle - speed * deltaTime, targetAngle)
        }
    }
    
    /// Get drag multiplier based on DRS state
    func getDragMultiplier() -> Float {
        // Interpolate based on wing angle
        return 1.0 - (dragReduction * wingAngle)
    }
    
    /// Get top speed bonus based on DRS state
    func getTopSpeedBonus() -> Float {
        return topSpeedBoost * wingAngle
    }
    
    /// Check if DRS is available for activation
    func isDRSAvailable() -> Bool {
        return state == .available
    }
    
    /// Check if DRS is currently active
    func isDRSActive() -> Bool {
        return state == .active && isOpen
    }
    
    /// Get current zone name (if any)
    func getCurrentZoneName() -> String? {
        return currentZone?.name
    }
    
    /// Get all DRS zones for track rendering
    func getZones() -> [DRSZone] {
        return zones
    }
    
    /// Check if currently in a DRS zone (for ANE integration)
    func isDRSZoneActive() -> Bool {
        return currentZone != nil && (state == .available || state == .active)
    }
}
