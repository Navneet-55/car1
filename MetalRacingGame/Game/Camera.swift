//
//  Camera.swift
//  MetalRacingGame
//
//  Dynamic camera systems (chase, cockpit, cinematic)
//

import simd
import QuartzCore

enum CameraMode {
    case chase
    case cockpit
    case cinematic
}

class Camera {
    var position: SIMD3<Float> = SIMD3<Float>(0, 5, 10)
    var target: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var up: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    
    var mode: CameraMode = .chase
    
    // Camera parameters
    var fov: Float = 60.0 * .pi / 180.0
    var nearPlane: Float = 0.1
    var farPlane: Float = 1000.0
    var aspectRatio: Float = 16.0 / 9.0
    
    // Chase camera parameters
    var chaseDistance: Float = 15.0
    var chaseHeight: Float = 5.0
    var chaseSmoothing: Float = 0.1
    
    // Smoothing
    private var smoothPosition: SIMD3<Float> = SIMD3<Float>(0, 5, 10)
    private var smoothTarget: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    
    /// Update camera based on target (car position)
    func update(targetPosition: SIMD3<Float>, targetRotation: simd_quatf, deltaTime: Float) {
        switch mode {
        case .chase:
            updateChaseCamera(targetPosition: targetPosition, targetRotation: targetRotation, deltaTime: deltaTime)
        case .cockpit:
            updateCockpitCamera(targetPosition: targetPosition, targetRotation: targetRotation, deltaTime: deltaTime)
        case .cinematic:
            updateCinematicCamera(targetPosition: targetPosition, targetRotation: targetRotation, deltaTime: deltaTime)
        }
    }
    
    private func updateChaseCamera(targetPosition: SIMD3<Float>, targetRotation: simd_quatf, deltaTime: Float) {
        // Get car's forward direction
        let forward = targetRotation.act(SIMD3<Float>(0, 0, -1))
        let right = targetRotation.act(SIMD3<Float>(1, 0, 0))
        
        // Calculate desired camera position (behind and above car)
        let desiredPosition = targetPosition - forward * chaseDistance + SIMD3<Float>(0, chaseHeight, 0)
        
        // Smooth camera movement
        smoothPosition = mix(smoothPosition, desiredPosition, t: chaseSmoothing)
        smoothTarget = mix(smoothTarget, targetPosition, t: chaseSmoothing * 2.0)
        
        position = smoothPosition
        target = smoothTarget
    }
    
    private func updateCockpitCamera(targetPosition: SIMD3<Float>, targetRotation: simd_quatf, deltaTime: Float) {
        // Cockpit view: camera is inside the car
        let forward = targetRotation.act(SIMD3<Float>(0, 0, -1))
        position = targetPosition + SIMD3<Float>(0, 1.5, 0) // Eye height
        target = targetPosition + forward * 10.0
    }
    
    private func updateCinematicCamera(targetPosition: SIMD3<Float>, targetRotation: simd_quatf, deltaTime: Float) {
        // Cinematic view: dynamic camera angles
        let time = Float(CACurrentMediaTime())
        let offset = SIMD3<Float>(
            sin(time * 0.5) * 10.0,
            8.0 + sin(time * 0.3) * 2.0,
            cos(time * 0.5) * 10.0
        )
        
        position = targetPosition + offset
        target = targetPosition
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
}

