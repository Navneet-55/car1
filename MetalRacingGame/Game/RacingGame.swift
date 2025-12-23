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
    
    // Race systems
    private var drsSystem: DRSSystem
    private var pitStopSystem: PitStopSystem
    
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
        
        // Initialize race systems
        self.drsSystem = DRSSystem()
        self.pitStopSystem = PitStopSystem()
        
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
        
        // Update DRS system
        drsSystem.update(
            deltaTime: deltaTime,
            trackDistance: playerTrackDistance,
            speed: speed,
            braking: input.brake,
            steering: input.steering,
            drsButtonPressed: input.drsButton
        )
        
        // Update pit stop system
        pitStopSystem.update(
            deltaTime: deltaTime,
            trackDistance: playerTrackDistance,
            speed: speed,
            position: carState.position,
            pitButtonPressed: input.pitButton
        )
        
        // Handle tire change input
        if input.tireChangeButton && pitStopSystem.state == .stopped {
            pitStopSystem.cycleCompound()
        }
        
        // Apply race systems to physics
        applyRaceSystemsToPhysics(input: input, deltaTime: deltaTime)
        
        // Update player car
        playerCar.update(input: input, physicsEngine: physicsEngine)
        
        // Update camera with enhanced data (TPP only)
        let updatedCarState = playerCar.getPhysicsState()
        
        // Use ANE for predictive camera smoothing (optional, async, non-blocking)
        // For now, camera uses standard interpolation
        // ANE smoothing can be added later as an enhancement
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
                // Use ANE for AI decision optimization (optional, async, non-blocking)
                // For now, use CPU fallback directly to avoid async complexity
                // ANE optimization can be added later as an enhancement
                let aiInput = generateAIInput(for: aiCar)
                aiCar.update(input: aiInput, physicsEngine: physicsEngine)
            }
        }
        
        // Update particles (throttled in Low Battery Mode)
        if updateParticles, let particleSystem = particleSystem {
            // Particle updates would go here
            // For now, particles are updated elsewhere
        }
        
        // Update lap time
        if isLapActive {
            currentLapTime = CACurrentMediaTime() - lapStartTime
        }
    }
    
    /// Update track position based on car position
    private func updateTrackPosition(carState: CarPhysicsState, deltaTime: Float) {
        // Simplified track position calculation
        // In a real implementation, this would use track spline projection
        let speed = length(carState.velocity)
        playerTrackDistance += speed * deltaTime
        
        // Wrap around track length
        if let track = track {
            playerTrackDistance = playerTrackDistance.truncatingRemainder(dividingBy: track.length)
        }
    }
    
    /// Apply DRS and tire grip to physics
    private func applyRaceSystemsToPhysics(input: CarInput, deltaTime: Float) {
        guard let playerCar = playerCar else { return }
        
        // Get modifiers from race systems
        let drsTopSpeedBonus = drsSystem.getTopSpeedBonus()
        let drsDragMultiplier = drsSystem.getDragMultiplier()
        let tireGripMultiplier = pitStopSystem.getGripMultiplier()
        
        // Apply speed limit if pit limiter is active
        if let speedLimit = pitStopSystem.getSpeedLimit() {
            let currentSpeed = playerCar.getSpeed()
            if currentSpeed > speedLimit {
                // Physics engine will handle speed limiting
                physicsEngine.setSpeedLimit(carId: playerCar.id, limit: speedLimit)
            }
        } else {
            physicsEngine.clearSpeedLimit(carId: playerCar.id)
        }
        
        // Set physics modifiers
        physicsEngine.setDragMultiplier(carId: playerCar.id, multiplier: drsDragMultiplier)
        physicsEngine.setGripMultiplier(carId: playerCar.id, multiplier: tireGripMultiplier)
    }
    
    /// Check if car is on kerb
    private func isOnKerb(position: SIMD3<Float>) -> Bool {
        // Simplified kerb detection - check if near track edges
        // Real implementation would use track geometry
        return false
    }
    
    /// Update HUD with current state
    private func updateHUD(speed: Float, carState: CarPhysicsState) {
        guard let hudManager = hudManager else { return }
        
        let gear = calculateGear(speed: speed)
        hudManager.update(speed: speed, gear: gear)
        
        // Update DRS state
        hudManager.updateDRS(
            available: drsSystem.isDRSAvailable(),
            active: drsSystem.isDRSActive()
        )
        
        // Update tire info
        hudManager.updateTires(
            compound: pitStopSystem.currentTires.compound,
            wear: pitStopSystem.currentTires.wear
        )
        
        // Update pit limiter
        hudManager.updatePitLimiter(active: pitStopSystem.isPitLimiterActive)
        
        // Update lap time
        hudManager.updateLapTime(currentLapTime)
    }
    
    /// Generate AI input for autonomous cars
    private func generateAIInput(for car: Car) -> CarInput {
        var input = CarInput()
        
        // Simple AI: always throttle and steer toward track
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
    
    /// Get DRS system for rendering
    func getDRSSystem() -> DRSSystem {
        return drsSystem
    }
    
    /// Get pit stop system
    func getPitStopSystem() -> PitStopSystem {
        return pitStopSystem
    }
    
    /// Calculate gear based on speed
    private func calculateGear(speed: Float) -> Int {
        if speed < 50 { return 1 }
        if speed < 100 { return 2 }
        if speed < 150 { return 3 }
        if speed < 200 { return 4 }
        if speed < 250 { return 5 }
        if speed < 300 { return 6 }
        return 7
    }
}
