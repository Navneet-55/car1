//
//  PhysicsEngine.swift
//  MetalRacingGame
//
//  Car physics simulation
//

import Foundation
import simd

/// Physics state for a car
struct CarPhysicsState {
    var position: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    var velocity: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var angularVelocity: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    
    var speed: Float {
        return length(velocity)
    }
}

class PhysicsEngine {
    private var carStates: [UUID: CarPhysicsState] = [:]
    
    /// Update physics simulation
    func update(deltaTime: Float) {
        // Update all car physics states
        for (id, _) in carStates {
            updateCar(id: id, deltaTime: deltaTime)
        }
    }
    
    /// Register a car for physics simulation
    func registerCar(id: UUID, initialState: CarPhysicsState) {
        carStates[id] = initialState
    }
    
    /// Update car physics
    func updateCar(id: UUID, deltaTime: Float) {
        guard var state = carStates[id] else { return }
        
        // Simple car physics
        // Apply gravity
        state.velocity.y -= 9.8 * deltaTime
        
        // Update position
        state.position += state.velocity * deltaTime
        
        // Update rotation from angular velocity
        let rotationDelta = simd_quatf(angle: length(state.angularVelocity) * deltaTime,
                                       axis: normalize(state.angularVelocity))
        state.rotation = simd_mul(state.rotation, rotationDelta)
        
        // Damping
        state.velocity *= 0.99
        state.angularVelocity *= 0.95
        
        // Ground collision (simple)
        if state.position.y < 0 {
            state.position.y = 0
            state.velocity.y = 0
        }
        
        carStates[id] = state
    }
    
    /// Apply force to car
    func applyForce(carId: UUID, force: SIMD3<Float>) {
        guard var state = carStates[carId] else { return }
        // Simplified: assume mass of 1000kg
        let acceleration = force / 1000.0
        state.velocity += acceleration * 0.016 // Assume 60fps
        carStates[carId] = state
    }
    
    /// Apply input to car
    func applyInput(carId: UUID, input: CarInput) {
        guard var state = carStates[carId] else { return }
        
        // Get forward direction from rotation
        let forward = state.rotation.act(SIMD3<Float>(0, 0, -1))
        let right = state.rotation.act(SIMD3<Float>(1, 0, 0))
        
        // Throttle force
        let throttleForce = forward * input.throttle * 5000.0
        state.velocity += throttleForce * 0.016
        
        // Brake force
        let brakeForce = -normalize(state.velocity) * input.brake * 3000.0
        state.velocity += brakeForce * 0.016
        
        // Steering (affects angular velocity)
        state.angularVelocity.y = input.steering * 2.0
        
        // Handbrake
        if input.handbrake {
            state.velocity *= 0.9
        }
        
        carStates[carId] = state
    }
    
    /// Get car physics state
    func getCarState(id: UUID) -> CarPhysicsState? {
        return carStates[id]
    }
}

