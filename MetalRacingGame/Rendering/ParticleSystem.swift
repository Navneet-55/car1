//
//  ParticleSystem.swift
//  MetalRacingGame
//
//  GPU-driven particle system for smoke, sparks, debris
//

import Metal
import MetalKit
import simd

/// GPU-driven particle system
class ParticleSystem {
    private let device: MTLDevice
    private var particleBuffer: MTLBuffer?
    private var computePipeline: MTLComputePipelineState?
    
    struct Particle {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
        var color: SIMD4<Float>
        var life: Float
        var size: Float
    }
    
    private var particles: [Particle] = []
    private let maxParticles: Int
    
    init(device: MTLDevice, maxParticles: Int = 10000) {
        self.device = device
        self.maxParticles = maxParticles
        
        setupParticles()
        setupComputePipeline()
    }
    
    private func setupParticles() {
        let bufferSize = MemoryLayout<Particle>.stride * maxParticles
        particleBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)
    }
    
    private func setupComputePipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        if let computeFunction = library.makeFunction(name: "update_particles") {
            do {
                computePipeline = try device.makeComputePipelineState(function: computeFunction)
            } catch {
                print("Warning: Failed to create particle compute pipeline: \(error)")
            }
        }
    }
    
    /// Emit particles
    func emit(position: SIMD3<Float>, count: Int, type: ParticleType) {
        for _ in 0..<count {
            if particles.count < maxParticles {
                let particle = createParticle(at: position, type: type)
                particles.append(particle)
            }
        }
    }
    
    private func createParticle(at position: SIMD3<Float>, type: ParticleType) -> Particle {
        var velocity = SIMD3<Float>(
            Float.random(in: -1...1),
            Float.random(in: 0...2),
            Float.random(in: -1...1)
        )
        
        var color = SIMD4<Float>(1, 1, 1, 1)
        var life: Float = 1.0
        var size: Float = 0.1
        
        switch type {
        case .smoke:
            color = SIMD4<Float>(0.3, 0.3, 0.3, 0.8)
            life = Float.random(in: 2...5)
            size = Float.random(in: 0.2...0.5)
        case .spark:
            color = SIMD4<Float>(1, 0.8, 0, 1)
            life = Float.random(in: 0.1...0.5)
            size = Float.random(in: 0.05...0.1)
        case .debris:
            color = SIMD4<Float>(0.5, 0.5, 0.5, 1)
            life = Float.random(in: 1...3)
            size = Float.random(in: 0.1...0.3)
        }
        
        return Particle(
            position: position,
            velocity: velocity,
            color: color,
            life: life,
            size: size
        )
    }
    
    /// Update particles on GPU
    func update(commandBuffer: MTLCommandBuffer, deltaTime: Float) {
        guard let computePipeline = computePipeline,
              let particleBuffer = particleBuffer else { return }
        
        // Update particle buffer
        let pointer = particleBuffer.contents().bindMemory(to: Particle.self, capacity: maxParticles)
        for (index, particle) in particles.enumerated() {
            pointer[index] = particle
        }
        
        // Dispatch compute shader
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(computePipeline)
            encoder.setBuffer(particleBuffer, offset: 0, index: 0)
            
            var dt = deltaTime
            encoder.setBytes(&dt, length: MemoryLayout<Float>.stride, index: 1)
            
            let threadgroupSize = MTLSize(width: 256, height: 1, depth: 1)
            let threadgroupCount = MTLSize(
                width: (particles.count + 255) / 256,
                height: 1,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }
        
        // Read back and filter dead particles
        particles = particles.filter { $0.life > 0 }
    }
    
    /// Get particles for rendering
    func getParticles() -> [Particle] {
        return particles
    }
}

enum ParticleType {
    case smoke
    case spark
    case debris
}

