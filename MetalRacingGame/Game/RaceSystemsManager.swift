//
//  RaceSystemsManager.swift
//  MetalRacingGame
//
//  Manages DRS, pit stops, and tire strategy
//

import Foundation
import simd

class RaceSystemsManager {
    private(set) var drsSystem: DRSSystem
    private(set) var pitStopSystem: PitStopSystem
    
    init() {
        self.drsSystem = DRSSystem()
        self.pitStopSystem = PitStopSystem()
    }
    
    /// Update all race systems
    func update(deltaTime: Float, trackDistance: Float, speed: Float, braking: Float, steering: Float, drsButton: Bool, pitButton: Bool, tireChangeButton: Bool, carPosition: SIMD3<Float>) {
        // Update DRS system
        drsSystem.update(
            deltaTime: deltaTime,
            trackDistance: trackDistance,
            speed: speed,
            braking: braking,
            steering: steering,
            drsButtonPressed: drsButton
        )
        
        // Update pit stop system
        pitStopSystem.update(
            deltaTime: deltaTime,
            trackDistance: trackDistance,
            speed: speed,
            position: carPosition,
            pitButtonPressed: pitButton
        )
        
        // Handle tire change input
        if tireChangeButton && pitStopSystem.state == .stopped {
            pitStopSystem.cycleCompound()
        }
    }
    
    /// Apply race system effects to physics
    func applyToPhysics(physicsEngine: PhysicsEngine, carId: UUID, carSpeed: Float) {
        // Get modifiers from race systems
        let drsDragMultiplier = drsSystem.getDragMultiplier()
        let tireGripMultiplier = pitStopSystem.getGripMultiplier()
        
        // Apply speed limit if pit limiter is active
        if let speedLimit = pitStopSystem.getSpeedLimit() {
            if carSpeed > speedLimit {
                physicsEngine.setSpeedLimit(carId: carId, limit: speedLimit)
            }
        } else {
            physicsEngine.clearSpeedLimit(carId: carId)
        }
        
        // Set physics modifiers
        physicsEngine.setDragMultiplier(carId: carId, multiplier: drsDragMultiplier)
        physicsEngine.setGripMultiplier(carId: carId, multiplier: tireGripMultiplier)
    }
    
    /// Reset all race systems
    func reset() {
        drsSystem.reset()
        pitStopSystem.reset()
    }
    
    /// Update HUD with race system state
    func updateHUD(_ hudManager: HUDManager?) {
        guard let hudManager = hudManager else { return }
        
        hudManager.updateDRS(
            available: drsSystem.isDRSAvailable(),
            active: drsSystem.isDRSActive()
        )
        
        hudManager.updateTires(
            compound: pitStopSystem.currentTires.compound,
            wear: pitStopSystem.currentTires.wear
        )
        
        hudManager.updatePitLimiter(active: pitStopSystem.isPitLimiterActive)
    }
}
