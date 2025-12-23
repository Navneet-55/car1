//
//  Camera.swift
//  MetalRacingGame
//
//  TPP-only camera with dynamic chase, speed-based effects, and smoothing
//

import simd
import QuartzCore

/// Camera mode - TPP only (cockpit/cinematic removed per policy)
enum CameraMode {
    case chase // Primary TPP chase camera
}

/// Camera shake data
struct CameraShake {
    var intensity: Float = 0.0
    var frequency: Float = 0.0
    var decay: Float = 0.95
}

class Camera {
    var position: SIMD3<Float> = SIMD3<Float>(0, 5, 10)
    var target: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var up: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    
    // TPP-only mode (non-negotiable)
    private(set) var mode: CameraMode = .chase
    
    // Camera parameters
    var fov: Float = 60.0 * .pi / 180.0
    var baseFov: Float = 60.0 * .pi / 180.0
    var nearPlane: Float = 0.1
    var farPlane: Float = 2000.0
    var aspectRatio: Float = 16.0 / 9.0
    
    // Dynamic chase camera parameters
    private let baseChaseDistance: Float = 12.0
    private let maxChaseDistance: Float = 18.0 // Pulls back at high speed
    private let baseChaseHeight: Float = 4.0
    private let maxChaseHeight: Float = 6.0
    private let chaseSmoothing: Float = 0.08 // Smooth but responsive
    private let targetSmoothing: Float = 0.15
    
    // Speed-based camera effects
    private let fovSpeedMultiplier: Float = 0.08 // FOV increase per 100 km/h
    private let maxFovIncrease: Float = 15.0 * .pi / 180.0 // Max FOV boost
    
    // Camera shake
    private var shake = CameraShake()
    private var shakeOffset: SIMD3<Float> = .zero
    private var lastKerbTime: Float = 0
    
    // Smoothing buffers
    private var smoothPosition: SIMD3<Float> = SIMD3<Float>(0, 5, 10)
    private var smoothTarget: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var smoothFov: Float = 60.0 * .pi / 180.0
    
    // Motion sickness prevention
    private let maxPositionDelta: Float = 2.0 // Max position change per frame
    private let maxRotationDelta: Float = 0.1 // Max rotation change per frame
    private var lastPosition: SIMD3<Float> = .zero
    
    // Current car state for effects
    private var currentSpeed: Float = 0
    private var currentBraking: Float = 0
    private var isOnKerb: Bool = false
    
    /// Update camera with car state and physics data
    func update(targetPosition: SIMD3<Float>, targetRotation: simd_quatf, deltaTime: Float, speed: Float = 0, braking: Float = 0, onKerb: Bool = false) {
        currentSpeed = speed
        currentBraking = braking
        isOnKerb = onKerb
        
        // Always use chase camera (TPP policy)
        updateChaseCamera(targetPosition: targetPosition, targetRotation: targetRotation, deltaTime: deltaTime)
        
        // Apply camera shake
        updateCameraShake(deltaTime: deltaTime)
        
        // Apply motion sickness prevention
        applyMotionSmoothing()
    }
    
    /// Legacy update method for compatibility
    func update(targetPosition: SIMD3<Float>, targetRotation: simd_quatf, deltaTime: Float) {
        update(targetPosition: targetPosition, targetRotation: targetRotation, deltaTime: deltaTime, speed: 0, braking: 0, onKerb: false)
    }
    
    /// Dynamic chase camera with speed-based distance scaling
    private func updateChaseCamera(targetPosition: SIMD3<Float>, targetRotation: simd_quatf, deltaTime: Float) {
        // Get car's forward direction
        let forward = targetRotation.act(SIMD3<Float>(0, 0, -1))
        
        // Calculate speed factor (0-1 based on 0-350 km/h)
        let speedFactor = min(currentSpeed / 350.0, 1.0)
        
        // Dynamic distance - pulls back at high speed for better spatial awareness
        let dynamicDistance = baseChaseDistance + (maxChaseDistance - baseChaseDistance) * speedFactor
        
        // Dynamic height - slightly higher at speed
        let dynamicHeight = baseChaseHeight + (maxChaseHeight - baseChaseHeight) * speedFactor * 0.5
        
        // Calculate desired camera position (behind and above car)
        var desiredPosition = targetPosition - forward * dynamicDistance + SIMD3<Float>(0, dynamicHeight, 0)
        
        // Add slight offset during braking (camera moves forward slightly)
        if currentBraking > 0.3 {
            let brakeOffset = forward * currentBraking * 1.5
            desiredPosition += brakeOffset
        }
        
        // Smooth camera movement with adaptive smoothing
        // Faster response at low speed, smoother at high speed
        let adaptiveSmoothing = chaseSmoothing * (1.0 + speedFactor * 0.5)
        smoothPosition = mix(smoothPosition, desiredPosition, t: adaptiveSmoothing)
        
        // Look slightly ahead of car at high speed
        let lookAheadDistance = speedFactor * 5.0
        let lookAheadTarget = targetPosition + forward * lookAheadDistance
        smoothTarget = mix(smoothTarget, lookAheadTarget, t: targetSmoothing)
        
        // Apply base position and target
        position = smoothPosition + shakeOffset
        target = smoothTarget
        
        // Dynamic FOV - increases with speed for sense of motion
        let targetFov = baseFov + min(speedFactor * fovSpeedMultiplier * 100.0 * .pi / 180.0, maxFovIncrease)
        smoothFov = mix(smoothFov, targetFov, t: 0.05)
        fov = smoothFov
    }
    
    /// Update camera shake based on driving conditions
    private func updateCameraShake(deltaTime: Float) {
        // Base shake from speed (subtle vibration)
        let speedShake = currentSpeed / 350.0 * 0.02
        
        // Kerb shake (stronger, rhythmic)
        var kerbShake: Float = 0
        if isOnKerb {
            lastKerbTime = Float(CACurrentMediaTime())
            kerbShake = 0.08
        } else if Float(CACurrentMediaTime()) - lastKerbTime < 0.2 {
            kerbShake = 0.04 // Lingering shake after kerb
        }
        
        // Braking shake (forward/back)
        let brakeShake = currentBraking * 0.03
        
        // Combine shake intensities
        shake.intensity = speedShake + kerbShake + brakeShake
        
        // Generate shake offset
        let time = Float(CACurrentMediaTime())
        let shakeX = sin(time * 45.0) * shake.intensity * 0.3
        let shakeY = cos(time * 38.0) * shake.intensity * 0.2
        let shakeZ = sin(time * 52.0) * shake.intensity * 0.15
        
        shakeOffset = SIMD3<Float>(shakeX, shakeY, shakeZ)
        
        // Decay shake
        shake.intensity *= shake.decay
    }
    
    /// Apply motion smoothing to prevent motion sickness
    private func applyMotionSmoothing() {
        // Limit position delta per frame
        let positionDelta = position - lastPosition
        let deltaLength = length(positionDelta)
        
        if deltaLength > maxPositionDelta {
            let clampedDelta = normalize(positionDelta) * maxPositionDelta
            position = lastPosition + clampedDelta
        }
        
        lastPosition = position
    }
    
    /// Trigger kerb shake
    func triggerKerbShake() {
        isOnKerb = true
        lastKerbTime = Float(CACurrentMediaTime())
    }
    
    /// Get view matrix
    func getViewMatrix() -> float4x4 {
        return float4x4.lookAt(eye: position, target: target, up: up)
    }
    
    /// Get projection matrix
    func getProjectionMatrix() -> float4x4 {
        return float4x4.perspective(fovY: fov, aspect: aspectRatio, near: nearPlane, far: farPlane)
    }
    
    /// Set aspect ratio
    func setAspectRatio(_ aspect: Float) {
        aspectRatio = aspect
    }
    
    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        return a + (b - a) * t
    }
    
    private func mix(_ a: Float, _ b: Float, t: Float) -> Float {
        return a + (b - a) * t
    }
}
