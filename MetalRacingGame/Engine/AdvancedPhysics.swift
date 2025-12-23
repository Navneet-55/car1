//
//  AdvancedPhysics.swift
//  MetalRacingGame
//
//  Advanced car physics with tire simulation
//

import Foundation
import simd

/// Advanced car physics with tire forces
struct TireState {
    var slipAngle: Float = 0
    var slipRatio: Float = 0
    var load: Float = 0
    var lateralForce: Float = 0
    var longitudinalForce: Float = 0
}

struct AdvancedCarPhysics {
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var velocity: SIMD3<Float>
    var angularVelocity: SIMD3<Float>
    
    // Car properties
    var mass: Float = 1200.0 // kg
    var wheelbase: Float = 2.5 // meters
    var centerOfMass: Float = 0.5 // front/rear distribution (0-1)
    
    // Tire states (simplified to 4 wheels)
    var frontLeft: TireState = TireState()
    var frontRight: TireState = TireState()
    var rearLeft: TireState = TireState()
    var rearRight: TireState = TireState()
    
    var speed: Float {
        return length(velocity)
    }
}

class AdvancedPhysicsEngine {
    private var carStates: [UUID: AdvancedCarPhysics] = [:]
    
    // Tire model parameters (Pacejka simplified)
    private let tireStiffness: Float = 50000.0
    private let maxTireLoad: Float = 4000.0
    
    func registerCar(id: UUID, initialState: AdvancedCarPhysics) {
        carStates[id] = initialState
    }
    
    func update(deltaTime: Float) {
        for (id, _) in carStates {
            updateCar(id: id, deltaTime: deltaTime)
        }
    }
    
    func applyInput(carId: UUID, input: CarInput) {
        guard var state = carStates[carId] else { return }
        
        // Calculate tire forces
        calculateTireForces(&state, input: input)
        
        // Apply forces to car
        applyTireForces(&state, deltaTime: 0.016)
        
        carStates[carId] = state
    }
    
    private func calculateTireForces(_ state: inout AdvancedCarPhysics, input: CarInput) {
        let forward = state.rotation.act(SIMD3<Float>(0, 0, -1))
        let right = state.rotation.act(SIMD3<Float>(1, 0, 0))
        let up = SIMD3<Float>(0, 1, 0)
        
        let speed = state.speed
        let angularVel = state.angularVelocity.y
        
        // Calculate slip angles for each tire
        let frontSlip = input.steering - atan2(state.wheelbase * angularVel, max(speed, 0.1))
        let rearSlip = -atan2(state.wheelbase * angularVel * (1.0 - state.centerOfMass), max(speed, 0.1))
        
        // Tire load distribution (simplified)
        let baseLoad = state.mass * 9.8 / 4.0 // Equal distribution
        let lateralTransfer = state.velocity.x * 0.1 // Lateral weight transfer
        
        // Front tires
        state.frontLeft.slipAngle = frontSlip
        state.frontLeft.load = baseLoad - lateralTransfer
        state.frontLeft.lateralForce = calculateLateralForce(slipAngle: frontSlip, load: state.frontLeft.load)
        
        state.frontRight.slipAngle = frontSlip
        state.frontRight.load = baseLoad + lateralTransfer
        state.frontRight.lateralForce = calculateLateralForce(slipAngle: frontSlip, load: state.frontRight.load)
        
        // Rear tires
        state.rearLeft.slipAngle = rearSlip
        state.rearLeft.load = baseLoad - lateralTransfer
        state.rearLeft.lateralForce = calculateLateralForce(slipAngle: rearSlip, load: state.rearLeft.load)
        
        state.rearRight.slipAngle = rearSlip
        state.rearRight.load = baseLoad + lateralTransfer
        state.rearRight.lateralForce = calculateLateralForce(slipAngle: rearSlip, load: state.rearRight.load)
        
        // Longitudinal forces (throttle/brake)
        let throttleForce = input.throttle * 8000.0
        let brakeForce = input.brake * 12000.0
        
        state.rearLeft.longitudinalForce = (throttleForce - brakeForce) * 0.5
        state.rearRight.longitudinalForce = (throttleForce - brakeForce) * 0.5
    }
    
    private func calculateLateralForce(slipAngle: Float, load: Float) -> Float {
        // Simplified Pacejka tire model
        let normalizedLoad = min(load / maxTireLoad, 1.0)
        let force = tireStiffness * slipAngle * normalizedLoad
        return clamp(force, min: -maxTireLoad, max: maxTireLoad)
    }
    
    private func applyTireForces(_ state: inout AdvancedCarPhysics, deltaTime: Float) {
        let forward = state.rotation.act(SIMD3<Float>(0, 0, -1))
        let right = state.rotation.act(SIMD3<Float>(1, 0, 0))
        
        // Combine tire forces
        var totalForce = SIMD3<Float>(0, 0, 0)
        var totalTorque = SIMD3<Float>(0, 0, 0)
        
        // Front left
        totalForce += right * state.frontLeft.lateralForce * 0.5
        totalForce += forward * state.frontLeft.longitudinalForce * 0.5
        
        // Front right
        totalForce += right * state.frontRight.lateralForce * 0.5
        totalForce += forward * state.frontRight.longitudinalForce * 0.5
        
        // Rear left
        totalForce += right * state.rearLeft.lateralForce * 0.5
        totalForce += forward * state.rearLeft.longitudinalForce * 0.5
        
        // Rear right
        totalForce += right * state.rearRight.lateralForce * 0.5
        totalForce += forward * state.rearRight.longitudinalForce * 0.5
        
        // Apply forces
        let acceleration = totalForce / state.mass
        state.velocity += acceleration * deltaTime
        
        // Apply torque for rotation
        let torqueY = (state.frontLeft.lateralForce + state.frontRight.lateralForce) * state.wheelbase * 0.5
        state.angularVelocity.y += torqueY / (state.mass * state.wheelbase * state.wheelbase) * deltaTime
        
        // Update position and rotation
        state.position += state.velocity * deltaTime
        
        let rotationDelta = simd_quatf(angle: state.angularVelocity.y * deltaTime, axis: SIMD3<Float>(0, 1, 0))
        state.rotation = simd_mul(state.rotation, rotationDelta)
        
        // Damping
        state.velocity *= 0.98
        state.angularVelocity *= 0.95
        
        // Ground collision
        if state.position.y < 0 {
            state.position.y = 0
            state.velocity.y = 0
        }
    }
    
    func getCarState(id: UUID) -> AdvancedCarPhysics? {
        return carStates[id]
    }
    
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
}

