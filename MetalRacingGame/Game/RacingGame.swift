//
//  RacingGame.swift
//  MetalRacingGame
//
//  Main game logic with DRS, pit stops, and tire strategy
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
    private var hudManager: HUDManager?
    private var aneManager: NeuralEngineManager
    
    // Race systems manager
    private var raceSystemsManager: RaceSystemsManager
    
    // Track position tracking
    private var playerTrackDistance: Float = 0
    
    // Lap timing
    private var currentLapTime: TimeInterval = 0
    private var lapStartTime: TimeInterval = 0
    private var isLapActive: Bool = false
    
    init(physicsEngine: PhysicsEngine, inputManager: InputManager, capabilities: HardwareCapabilities, track: Track? = nil, hudManager: HUDManager? = nil) {
        self.physicsEngine = physicsEngine
        self.inputManager = inputManager
        self.capabilities = capabilities
        self.camera = Camera()
        self.track = track
        self.hudManager = hudManager
        
        // Initialize race systems manager
        self.raceSystemsManager = RaceSystemsManager()
        
        // Initialize Neural Engine manager
        self.aneManager = NeuralEngineManager.shared
        
        setupGame()
    }
    
    func setHUDManager(_ manager: HUDManager) {
        self.hudManager = manager
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
                velocity: SIMD3<Float>(0, 0, -5.0),
                angularVelocity: SIMD3<Float>(0, 0, 0)
            )
            physicsEngine.registerCar(id: aiId, initialState: aiState)
        }
        
        // Start lap timing
        lapStartTime = CACurrentMediaTime()
        isLapActive = true
    }
    
    /// Update game logic with dynamic tick rates for Low Battery Mode
    func update(deltaTime: Float, updateAI: Bool = true, updateParticles: Bool = true) {
        guard let playerCar = playerCar else { return }
        
        let input = inputManager.getCarInput()
        let carState = playerCar.getPhysicsState()
        let speed = playerCar.getSpeed()
        
        // Update track position
        updateTrackPosition(carState: carState, deltaTime: deltaTime)
        
        // Update race systems
        raceSystemsManager.update(
            deltaTime: deltaTime,
            trackDistance: playerTrackDistance,
            speed: speed,
            braking: input.brake,
            steering: input.steering,
            drsButton: input.drsButton,
            pitButton: input.pitButton,
            tireChangeButton: input.tireChangeButton,
            carPosition: carState.position
        )
        
        // Apply race systems to physics
        raceSystemsManager.applyToPhysics(physicsEngine: physicsEngine, carId: playerCar.id, carSpeed: speed)
        
        // Update player car
        playerCar.update(input: input, physicsEngine: physicsEngine, deltaTime: deltaTime)
        
        // Sync visual tire color with pit system
        playerCar.setTireColor(raceSystemsManager.pitStopSystem.getTireColor())
        
        // Update camera with enhanced data (TPP only)
        let updatedCarState = playerCar.getPhysicsState()
        camera.update(
            targetPosition: updatedCarState.position,
            targetRotation: updatedCarState.rotation,
            deltaTime: deltaTime,
            speed: speed,
            braking: input.brake,
            onKerb: isOnKerb(position: updatedCarState.position)
        )
        
        // Update HUD
        updateHUD(speed: speed, carState: updatedCarState)
        
        // Update AI cars (throttled in Low Battery Mode)
        if updateAI {
            for aiCar in aiCars {
                let aiInput = generateAIInput(for: aiCar)
                aiCar.update(input: aiInput, physicsEngine: physicsEngine, deltaTime: deltaTime)
            }
        }
        
        // Update particles (throttled in Low Battery Mode)
        if updateParticles, let particleSystem = particleSystem {
            // Particle updates would go here
        }
        
        // Update lap time
        if isLapActive {
            currentLapTime = CACurrentMediaTime() - lapStartTime
        }
    }
    
    /// Reset game to initial state
    func reset() {
        isLapActive = false
        
        // Reset player
        if let player = playerCar {
            let initialState = CarPhysicsState(
                position: SIMD3<Float>(0, 1, 0),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                velocity: SIMD3<Float>(0, 0, 0),
                angularVelocity: SIMD3<Float>(0, 0, 0)
            )
            physicsEngine.registerCar(id: player.id, initialState: initialState)
            player.setTireColor(SIMD3<Float>(1.0, 0.8, 0.0)) // Reset to medium yellow
        }
        
        // Reset AI
        for (i, aiCar) in aiCars.enumerated() {
            let initialPos = SIMD3<Float>(Float(i) * 5.0 - 5.0, 1, -10.0)
            let initialState = CarPhysicsState(
                position: initialPos,
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                velocity: SIMD3<Float>(0, 0, -5.0),
                angularVelocity: SIMD3<Float>(0, 0, 0)
            )
            physicsEngine.registerCar(id: aiCar.id, initialState: initialState)
        }
        
        // Reset race systems
        raceSystemsManager.reset()
        
        // Reset timing
        lapStartTime = CACurrentMediaTime()
        currentLapTime = 0
        playerTrackDistance = 0
        isLapActive = true
    }
    
    /// Update track position based on car position
    private func updateTrackPosition(carState: CarPhysicsState, deltaTime: Float) {
        let speed = length(carState.velocity)
        playerTrackDistance += speed * deltaTime
        
        if let track = track {
            playerTrackDistance = playerTrackDistance.truncatingRemainder(dividingBy: track.length)
        }
    }
    
    /// Check if car is on kerb
    private func isOnKerb(position: SIMD3<Float>) -> Bool {
        return false
    }
    
    /// Update HUD with current state
    private func updateHUD(speed: Float, carState: CarPhysicsState) {
        guard let hudManager = hudManager else { return }
        
        let gear = calculateGear(speed: speed)
        hudManager.update(speed: speed, gear: gear)
        
        // Update race systems in HUD
        raceSystemsManager.updateHUD(hudManager)
        
        // Update lap time
        hudManager.updateLapTime(currentLapTime)
    }
    
    /// Generate AI input for autonomous cars
    private func generateAIInput(for car: Car) -> CarInput {
        var input = CarInput()
        input.throttle = 0.8
        input.steering = Float.random(in: -0.2...0.2)
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
    
    /// Get race systems manager
    func getRaceSystemsManager() -> RaceSystemsManager {
        return raceSystemsManager
    }
    
    /// Calculate gear based on speed
    private func calculateGear(speed: Float) -> Int {
        let gears = [0, 60, 100, 140, 180, 230, 280, 330]
        for i in 1..<gears.count {
            if speed < Float(gears[i]) {
                return i
            }
        }
        return 8
    }
}
