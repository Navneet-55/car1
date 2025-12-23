//
//  InputManager.swift
//  MetalRacingGame
//
//  macOS-native input handling
//

import AppKit
import simd

/// Input state for car control
struct CarInput {
    var throttle: Float = 0.0
    var brake: Float = 0.0
    var steering: Float = 0.0
    var handbrake: Bool = false
}

class InputManager {
    static let shared = InputManager()
    
    private var currentInput = CarInput()
    private var keyStates: Set<UInt16> = []
    private var mouseDelta = SIMD2<Float>(0, 0)
    private var mousePosition = SIMD2<Float>(0, 0)
    
    private init() {}
    
    /// Update input state (called each frame)
    func update() {
        // Reset steering for smooth interpolation
        if !isKeyPressed(keyCode: 0) && !isKeyPressed(keyCode: 2) {
            currentInput.steering *= 0.9 // Decay steering
        }
    }
    
    /// Handle key down
    func handleKeyDown(keyCode: UInt16) {
        keyStates.insert(keyCode)
        updateInputFromKeys()
    }
    
    /// Handle key up
    func handleKeyUp(keyCode: UInt16) {
        keyStates.remove(keyCode)
        updateInputFromKeys()
    }
    
    /// Handle mouse movement
    func handleMouseMove(deltaX: Float, deltaY: Float) {
        mouseDelta = SIMD2<Float>(deltaX, deltaY)
        // Use mouse for camera control or steering
    }
    
    /// Get current car input
    func getCarInput() -> CarInput {
        return currentInput
    }
    
    /// Check if key is pressed
    func isKeyPressed(keyCode: UInt16) -> Bool {
        return keyStates.contains(keyCode)
    }
    
    private func updateInputFromKeys() {
        // WASD controls
        // W = Throttle (0x0D)
        // S = Brake (0x01)
        // A = Left (0x00)
        // D = Right (0x02)
        // Space = Handbrake (0x31)
        
        // Throttle
        if isKeyPressed(keyCode: 0x0D) { // W
            currentInput.throttle = min(currentInput.throttle + 0.1, 1.0)
        } else {
            currentInput.throttle = max(currentInput.throttle - 0.1, 0.0)
        }
        
        // Brake
        if isKeyPressed(keyCode: 0x01) { // S
            currentInput.brake = min(currentInput.brake + 0.1, 1.0)
        } else {
            currentInput.brake = max(currentInput.brake - 0.1, 0.0)
        }
        
        // Steering
        var steeringDelta: Float = 0.0
        if isKeyPressed(keyCode: 0x00) { // A
            steeringDelta = -0.05
        }
        if isKeyPressed(keyCode: 0x02) { // D
            steeringDelta = 0.05
        }
        currentInput.steering = clamp(currentInput.steering + steeringDelta, min: -1.0, max: 1.0)
        
        // Handbrake
        currentInput.handbrake = isKeyPressed(keyCode: 0x31) // Space
    }
    
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
}

