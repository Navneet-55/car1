//
//  PhysicsEngine.swift
//  MetalRacingGame
//
//  Car physics simulation with DRS and tire dynamics
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

/// Per-car physics modifiers
struct CarPhysicsModifiers {
    var dragMultiplier: Float = 1.0
    var gripMultiplier: Float = 1.0
    var speedLimit: Float? = nil
}

class PhysicsEngine {
    private var carStates: [UUID: CarPhysicsState] = [:]
    private var carModifiers: [UUID: CarPhysicsModifiers] = [:]
    
    // F1 car constants
    private let carMass: Float = 798.0 // F1 minimum weight (kg)
    private let maxEnginePower: Float = 1000000.0 // ~1000 HP in watts
    private let baseMaxSpeed: Float = 350.0 / 3.6 // ~350 km/h in m/s
    private let downforceCoefficient: Float = 2.5 // F1 downforce
    private let baseDragCoefficient: Float = 0.8
    private let baseTireGrip: Float = 1.2 // High grip for F1 tires
    private let trackFriction: Float = 0.9
    
    /// Update physics simulation
    func update(deltaTime: Float) {
        for (id, _) in carStates {
            updateCar(id: id, deltaTime: deltaTime)
        }
    }
    
    /// Register a car for physics simulation
    func registerCar(id: UUID, initialState: CarPhysicsState) {
        carStates[id] = initialState
        carModifiers[id] = CarPhysicsModifiers()
    }
    
    /// Update car physics with realistic F1 dynamics
    func updateCar(id: UUID, deltaTime: Float) {
        guard var state = carStates[id] else { return }
        let modifiers = carModifiers[id] ?? CarPhysicsModifiers()
        
        let speed = state.speed
        
        // Get directions
        let forward = state.rotation.act(SIMD3<Float>(0, 0, -1))
        let up = state.rotation.act(SIMD3<Float>(0, 1, 0))
        
        // Apply downforce (increases with speed)
        let downforce = downforceCoefficient * speed * speed * up
        let normalForce = SIMD3<Float>(0, carMass * 9.8, 0) + downforce
        
        // Apply drag (air resistance) with DRS modifier
        let effectiveDrag = baseDragCoefficient * modifiers.dragMultiplier
        if speed > 0.1 {
            let dragForce = -normalize(state.velocity) * effectiveDrag * speed * speed * 0.5
            state.velocity += dragForce / carMass * deltaTime
        }
        
        // Track collision and ground constraint
        if state.position.y < 0.3 {
            state.position.y = 0.3
            state.velocity.y = max(0, state.velocity.y)
            
            // Apply friction with grip modifier
            let effectiveGrip = baseTireGrip * modifiers.gripMultiplier
            if speed > 0.1 {
                let frictionForce = -normalize(state.velocity) * trackFriction * length(normalForce) * 0.1 * effectiveGrip
                state.velocity += frictionForce / carMass * deltaTime
            }
        }
        
        // Update position
        state.position += state.velocity * deltaTime
        
        // Update rotation from angular velocity
        if length(state.angularVelocity) > 0.001 {
            let rotationDelta = simd_quatf(angle: length(state.angularVelocity) * deltaTime,
                                           axis: normalize(state.angularVelocity))
            state.rotation = simd_mul(state.rotation, rotationDelta)
        }
        
        // Angular damping
        state.angularVelocity *= 0.98
        
        // Apply speed limit (pit limiter)
        if let speedLimit = modifiers.speedLimit {
            let speedLimitMS = speedLimit / 3.6 // Convert km/h to m/s
            if speed > speedLimitMS {
                state.velocity = normalize(state.velocity) * speedLimitMS
            }
        } else {
            // Normal max speed
            if speed > baseMaxSpeed {
                state.velocity = normalize(state.velocity) * baseMaxSpeed
            }
        }
        
        carStates[id] = state
    }
    
    /// Apply force to car
    func applyForce(carId: UUID, force: SIMD3<Float>, deltaTime: Float) {
        guard var state = carStates[carId] else { return }
        let acceleration = force / carMass
        state.velocity += acceleration * deltaTime
        carStates[carId] = state
    }
    
    /// Apply input to car with realistic F1 physics
    func applyInput(carId: UUID, input: CarInput, deltaTime: Float) {
        guard var state = carStates[carId] else { return }
        let modifiers = carModifiers[carId] ?? CarPhysicsModifiers()
        
        let speed = state.speed
        let forward = state.rotation.act(SIMD3<Float>(0, 0, -1))
        let right = state.rotation.act(SIMD3<Float>(1, 0, 0))
        
        // Check if speed limited (pit lane)
        let isSpeedLimited = modifiers.speedLimit != nil
        
        // Engine power (varies with speed - F1 power curve)
        let powerMultiplier = 1.0 - (speed / baseMaxSpeed) * 0.3
        var engineForce = forward * input.throttle * maxEnginePower * powerMultiplier / max(speed, 1.0)
        
        // Reduce power if speed limited
        if isSpeedLimited {
            let speedLimitMS = (modifiers.speedLimit ?? 80) / 3.6
            if speed >= speedLimitMS * 0.9 {
                engineForce *= 0.1 // Drastically reduce power near limit
            }
        }
        
        state.velocity += engineForce / carMass * deltaTime
        
        // Brake force (F1 carbon brakes)
        if speed > 0.1 {
            let brakeForce = -normalize(state.velocity) * input.brake * 15000.0
            state.velocity += brakeForce / carMass * deltaTime
        }
        
        // Steering (speed-dependent with grip modifier)
        let effectiveGrip = baseTireGrip * modifiers.gripMultiplier
        let steeringSensitivity = (1.0 - (speed / baseMaxSpeed) * 0.5) * effectiveGrip
        let steeringAngle = input.steering * steeringSensitivity
        
        // Apply steering torque
        state.angularVelocity.y = steeringAngle * 3.0
        
        // Lateral grip with tire modifier
        let lateralForce = right * steeringAngle * effectiveGrip * speed * 0.5
        state.velocity += lateralForce / carMass * deltaTime
        
        // Handbrake (drift/oversteer)
        if input.handbrake {
            state.velocity *= 0.95
            state.angularVelocity.y *= 1.5
        }
        
        carStates[carId] = state
    }
    
    /// Get car physics state
    func getCarState(id: UUID) -> CarPhysicsState? {
        return carStates[id]
    }
    
    // MARK: - Physics Modifiers (DRS, Tires, Pit Limiter)
    
    /// Set drag multiplier (for DRS)
    func setDragMultiplier(carId: UUID, multiplier: Float) {
        if carModifiers[carId] == nil {
            carModifiers[carId] = CarPhysicsModifiers()
        }
        carModifiers[carId]?.dragMultiplier = multiplier
    }
    
    /// Set grip multiplier (for tire compound/wear)
    func setGripMultiplier(carId: UUID, multiplier: Float) {
        if carModifiers[carId] == nil {
            carModifiers[carId] = CarPhysicsModifiers()
        }
        carModifiers[carId]?.gripMultiplier = multiplier
    }
    
    /// Set speed limit (for pit lane)
    func setSpeedLimit(carId: UUID, limit: Float) {
        if carModifiers[carId] == nil {
            carModifiers[carId] = CarPhysicsModifiers()
        }
        carModifiers[carId]?.speedLimit = limit
    }
    
    /// Clear speed limit
    func clearSpeedLimit(carId: UUID) {
        carModifiers[carId]?.speedLimit = nil
    }
    
    /// Get current modifiers for debugging
    func getModifiers(carId: UUID) -> CarPhysicsModifiers? {
        return carModifiers[carId]
    }
}
