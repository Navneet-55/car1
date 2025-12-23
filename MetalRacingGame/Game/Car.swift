//
//  Car.swift
//  MetalRacingGame
//
//  Car entity with physics and rendering
//

import Foundation
import simd

class Car {
    let id: UUID
    private var physicsState: CarPhysicsState
    private var input: CarInput = CarInput()
    
    // Car properties
    var color: SIMD3<Float> = SIMD3<Float>(1, 0, 0) // Red by default
    var model: String = "default_car"
    
    init(id: UUID = UUID(), position: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
        self.id = id
        self.physicsState = CarPhysicsState(
            position: position,
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            velocity: SIMD3<Float>(0, 0, 0),
            angularVelocity: SIMD3<Float>(0, 0, 0)
        )
    }
    
    /// Update car with input
    func update(input: CarInput, physicsEngine: PhysicsEngine) {
        self.input = input
        physicsEngine.applyInput(carId: id, input: input)
        
        if let newState = physicsEngine.getCarState(id: id) {
            physicsState = newState
        }
    }
    
    /// Get current physics state
    func getPhysicsState() -> CarPhysicsState {
        return physicsState
    }
    
    /// Get position
    func getPosition() -> SIMD3<Float> {
        return physicsState.position
    }
    
    /// Get rotation
    func getRotation() -> simd_quatf {
        return physicsState.rotation
    }
    
    /// Get speed in km/h
    func getSpeed() -> Float {
        return physicsState.speed * 3.6 // m/s to km/h
    }
}

