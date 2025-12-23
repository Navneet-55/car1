//
//  InputManager.swift
//  MetalRacingGame
//
//  macOS-native input handling with DRS and pit controls
//

import AppKit
import simd

/// Input state for car control
struct CarInput {
    var throttle: Float = 0.0
    var brake: Float = 0.0
    var steering: Float = 0.0
    var handbrake: Bool = false
    
    // Race systems
    var drsButton: Bool = false
    var pitButton: Bool = false
    var tireChangeButton: Bool = false // Cycle tire compound in pit
}

class InputManager {
    static let shared = InputManager()
    
    private var currentInput = CarInput()
    private var keyStates: Set<UInt16> = []
    private var mouseDelta = SIMD2<Float>(0, 0)
    private var mousePosition = SIMD2<Float>(0, 0)
    
    // Key codes
    private let keyW: UInt16 = 0x0D
    private let keyS: UInt16 = 0x01
    private let keyA: UInt16 = 0x00
    private let keyD: UInt16 = 0x02
    private let keySpace: UInt16 = 0x31
    private let keyE: UInt16 = 0x0E // DRS button
    private let keyP: UInt16 = 0x23 // Pit button
    private let keyT: UInt16 = 0x11 // Tire change
    
    // Input smoothing
    private let steeringSpeed: Float = 0.08
    private let steeringDecay: Float = 0.92
    private let throttleBrakeSpeed: Float = 0.15
    private let throttleBrakeDecay: Float = 0.85
    
    private init() {}
    
    /// Update input state (called each frame)
    func update() {
        // Smooth throttle
        if isKeyPressed(keyCode: keyW) {
            currentInput.throttle = min(currentInput.throttle + throttleBrakeSpeed, 1.0)
        } else {
            currentInput.throttle *= throttleBrakeDecay
            if currentInput.throttle < 0.01 { currentInput.throttle = 0 }
        }
        
        // Smooth brake
        if isKeyPressed(keyCode: keyS) {
            currentInput.brake = min(currentInput.brake + throttleBrakeSpeed, 1.0)
        } else {
            currentInput.brake *= throttleBrakeDecay
            if currentInput.brake < 0.01 { currentInput.brake = 0 }
        }
        
        // Smooth steering
        var targetSteering: Float = 0.0
        if isKeyPressed(keyCode: keyA) {
            targetSteering = -1.0
        }
        if isKeyPressed(keyCode: keyD) {
            targetSteering = 1.0
        }
        
        if targetSteering != 0 {
            currentInput.steering += (targetSteering - currentInput.steering) * steeringSpeed
        } else {
            currentInput.steering *= steeringDecay
            if abs(currentInput.steering) < 0.01 { currentInput.steering = 0 }
        }
        currentInput.steering = clamp(currentInput.steering, min: -1.0, max: 1.0)
        
        // Handbrake (instant)
        currentInput.handbrake = isKeyPressed(keyCode: keySpace)
        
        // DRS button (press and hold)
        currentInput.drsButton = isKeyPressed(keyCode: keyE)
        
        // Pit button (toggle)
        currentInput.pitButton = isKeyPressed(keyCode: keyP)
        
        // Tire change button (press)
        currentInput.tireChangeButton = isKeyPressed(keyCode: keyT)
    }
    
    /// Handle key down
    func handleKeyDown(keyCode: UInt16) {
        keyStates.insert(keyCode)
    }
    
    /// Handle key up
    func handleKeyUp(keyCode: UInt16) {
        keyStates.remove(keyCode)
    }
    
    /// Handle mouse movement
    func handleMouseMove(deltaX: Float, deltaY: Float) {
        mouseDelta = SIMD2<Float>(deltaX, deltaY)
    }
    
    /// Get current car input
    func getCarInput() -> CarInput {
        return currentInput
    }
    
    /// Check if key is pressed
    func isKeyPressed(keyCode: UInt16) -> Bool {
        return keyStates.contains(keyCode)
    }
    
    /// Check if DRS button just pressed (edge detection)
    func isDRSButtonPressed() -> Bool {
        return currentInput.drsButton
    }
    
    /// Check if pit button just pressed
    func isPitButtonPressed() -> Bool {
        return currentInput.pitButton
    }
    
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
}
