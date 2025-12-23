//
//  RacingGame.swift
//  MetalRacingGame
//
//  Main game logic for racing
//

import Foundation
import simd

class RacingGame {
    private let physicsEngine: PhysicsEngine
    private let inputManager: InputManager
    private let capabilities: HardwareCapabilities
    
    private var playerCar: Car?
    private var aiCars: [Car] = []
    private var camera: Camera
    
    private var particleSystem: ParticleSystem?
    private var track: Track?
    
    init(physicsEngine: PhysicsEngine, inputManager: InputManager, capabilities: HardwareCapabilities, track: Track? = nil) {
        self.physicsEngine = physicsEngine
        self.inputManager = inputManager
        self.capabilities = capabilities
        self.camera = Camera()
        self.track = track
        
        setupGame()
    }
    
    func getTrack() -> Track? {
        return track
    }
    
    private func setupGame() {
        // Create player car
        let playerId = UUID()
        let playerCar = Car(id: playerId, position: SIMD3<Float>(0, 1, 0))
        self.playerCar = playerCar
        
        // Register with physics
        let initialState = CarPhysicsState(
            position: SIMD3<Float>(0, 1, 0),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            velocity: SIMD3<Float>(0, 0, 0),
            angularVelocity: SIMD3<Float>(0, 0, 0)
        )
        physicsEngine.registerCar(id: playerId, initialState: initialState)
        
        // Create AI cars
        for i in 0..<3 {
            let aiId = UUID()
            let aiCar = Car(
                id: aiId,
                position: SIMD3<Float>(Float(i) * 5.0 - 5.0, 1, -10.0)
            )
            aiCar.color = SIMD3<Float>(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
            aiCars.append(aiCar)
            
            let aiState = CarPhysicsState(
                position: aiCar.getPosition(),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                velocity: SIMD3<Float>(0, 0, -5.0), // AI cars moving forward
                angularVelocity: SIMD3<Float>(0, 0, 0)
            )
            physicsEngine.registerCar(id: aiId, initialState: aiState)
        }
    }
    
    /// Update game logic
    func update(deltaTime: Float) {
        // Update player car with input
        if let playerCar = playerCar {
            let input = inputManager.getCarInput()
            playerCar.update(input: input, physicsEngine: physicsEngine)
            
            // Update camera to follow player
            let carState = playerCar.getPhysicsState()
            camera.update(
                targetPosition: carState.position,
                targetRotation: carState.rotation,
                deltaTime: deltaTime
            )
        }
        
        // Update AI cars (simple AI)
        for aiCar in aiCars {
            // Simple AI: follow path and avoid obstacles
            let aiInput = generateAIInput(for: aiCar)
            aiCar.update(input: aiInput, physicsEngine: physicsEngine)
        }
        
        // Particles will be updated in render thread with proper command buffer
    }
    
    /// Generate AI input for autonomous cars
    private func generateAIInput(for car: Car) -> CarInput {
        var input = CarInput()
        
        // Simple AI: always throttle and steer toward a target
        input.throttle = 0.8
        input.steering = Float.random(in: -0.2...0.2) // Random slight steering
        
        return input
    }
    
    /// Get camera for rendering
    func getCamera() -> Camera {
        return camera
    }
    
    /// Get player car
    func getPlayerCar() -> Car? {
        return playerCar
    }
    
    /// Get all cars
    func getAllCars() -> [Car] {
        var cars: [Car] = []
        if let player = playerCar {
            cars.append(player)
        }
        cars.append(contentsOf: aiCars)
        return cars
    }
}

