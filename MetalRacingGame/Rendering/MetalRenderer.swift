//
//  MetalRenderer.swift
//  MetalRacingGame
//
//  Main Metal 3 rendering pipeline with PBR and HDR
//

import Metal
import MetalKit
import simd

/// Main renderer handling PBR, HDR, and rendering pipeline
class MetalRenderer {
    private let device: MTLDevice
    private let capabilities: HardwareCapabilities
    private var view: MTKView
    
    // Render pipeline state
    private var renderPipelineState: MTLRenderPipelineState?
    private var depthStencilState: MTLDepthStencilState?
    
    // Buffers
    private var uniformBuffer: MTLBuffer?
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    
    // Textures
    private var depthTexture: MTLTexture?
    private var colorTexture: MTLTexture?
    
    // Ray tracing
    private var rayTracingRenderer: RayTracingRenderer?
    
    // MetalFX
    private var metalFXUpscaler: MetalFXUpscaler?
    
    // Post-processing
    private var postProcessor: PostProcessor?
    
    // Track rendering
    private var track: Track?
    
    // Frame data
    private var frameIndex: Int = 0
    private let maxFramesInFlight = 3
    
    // Uniforms
    struct Uniforms {
        var viewMatrix: float4x4
        var projectionMatrix: float4x4
        var modelMatrix: float4x4
        var cameraPosition: SIMD3<Float>
        var lightDirection: SIMD3<Float>
        var lightColor: SIMD3<Float>
        var time: Float
    }
    
    init(device: MTLDevice, view: MTKView, capabilities: HardwareCapabilities) {
        self.device = device
        self.view = view
        self.capabilities = capabilities
        
        setupView()
        setupBuffers()
        setupPipeline()
        setupDepthStencil()
        
        // Initialize MetalFX if available
        if capabilities.hasMetalFX {
            metalFXUpscaler = MetalFXUpscaler(device: device, view: view)
        }
        
        // Initialize post-processor
        postProcessor = PostProcessor(device: device)
        
        // Initialize track
        track = Track(device: device, length: 1000.0)
    }
    
    func setRayTracingRenderer(_ renderer: RayTracingRenderer) {
        self.rayTracingRenderer = renderer
    }
    
    private func setupView() {
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 1
        view.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
    }
    
    private func setupBuffers() {
        // Create uniform buffer (triple buffered)
        let uniformBufferSize = MemoryLayout<Uniforms>.stride * maxFramesInFlight
        uniformBuffer = device.makeBuffer(length: uniformBufferSize, options: .storageModeShared)
        
        // Create simple test geometry (will be replaced with actual car/track models)
        createTestGeometry()
    }
    
    private func createTestGeometry() {
        // Simple quad for testing
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 0.0, 0.0,
             1.0, -1.0, 0.0, 1.0, 0.0,
             1.0,  1.0, 0.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 0.0, 1.0
        ]
        
        let indices: [UInt16] = [
            0, 1, 2,
            2, 3, 0
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: [])
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])
    }
    
    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create Metal library")
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.sampleCount = view.sampleCount
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create render pipeline: \(error)")
        }
    }
    
    private func setupDepthStencil() {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }
    
    func render(commandBuffer: MTLCommandBuffer, frameIndex: Int, game: RacingGame?) {
        self.frameIndex = frameIndex
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor,
              let pipelineState = renderPipelineState,
              let drawable = view.currentDrawable else {
            return
        }
        
        // Update uniforms
        updateUniforms(game: game)
        
        // Create render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Set buffers
        if let uniformBuffer = uniformBuffer {
            let uniformOffset = MemoryLayout<Uniforms>.stride * frameIndex
            renderEncoder.setVertexBuffer(uniformBuffer, offset: uniformOffset, index: 0)
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: uniformOffset, index: 0)
        }
        
        // Render track
        if let track = track,
           let trackVertexBuffer = track.getVertexBuffer(),
           let trackIndexBuffer = track.getIndexBuffer() {
            renderEncoder.setVertexBuffer(trackVertexBuffer, offset: 0, index: 1)
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: track.getIndexCount(),
                indexType: .uint16,
                indexBuffer: trackIndexBuffer,
                indexBufferOffset: 0
            )
        }
        
        // Render cars
        if let vertexBuffer = vertexBuffer, let indexBuffer = indexBuffer {
            if let cars = game?.getAllCars() {
                for car in cars {
                    let carState = car.getPhysicsState()
                    let carPosition = carState.position
                    let carRotation = carState.rotation
                    
                    // Create model matrix for car
                    var modelMatrix = float4x4.identity()
                    modelMatrix = float4x4.translation(carPosition) * modelMatrix
                    modelMatrix = float4x4.rotation(quaternion: carRotation) * modelMatrix
                    modelMatrix = float4x4.scale(SIMD3<Float>(2, 1, 4)) * modelMatrix
                    
                    // Update model matrix in uniforms
                    var uniforms = getCurrentUniforms()
                    uniforms.modelMatrix = modelMatrix
                    let uniformOffset = MemoryLayout<Uniforms>.stride * frameIndex
                    if let uniformBuffer = uniformBuffer {
                        let uniformPointer = uniformBuffer.contents().advanced(by: uniformOffset).bindMemory(to: Uniforms.self, capacity: 1)
                        uniformPointer.pointee = uniforms
                    }
                    
                    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 1)
                    renderEncoder.drawIndexedPrimitives(
                        type: .triangle,
                        indexCount: 6,
                        indexType: .uint16,
                        indexBuffer: indexBuffer,
                        indexBufferOffset: 0
                    )
                }
            }
        }
        
        // Ray tracing pass (if enabled)
        if let rayTracingRenderer = rayTracingRenderer, capabilities.hasRayTracing {
            rayTracingRenderer.renderReflections(
                commandBuffer: commandBuffer,
                renderEncoder: renderEncoder,
                uniforms: getCurrentUniforms()
            )
        }
        
        renderEncoder.endEncoding()
    }
    
    private func updateUniforms(game: RacingGame?) {
        guard let uniformBuffer = uniformBuffer else { return }
        
        let uniformOffset = MemoryLayout<Uniforms>.stride * frameIndex
        let uniformPointer = uniformBuffer.contents().advanced(by: uniformOffset).bindMemory(to: Uniforms.self, capacity: 1)
        
        // Get camera from game
        let camera = game?.getCamera() ?? Camera()
        
        var uniforms = Uniforms(
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: camera.getProjectionMatrix(),
            modelMatrix: matrix_identity_float4x4,
            cameraPosition: camera.position,
            lightDirection: SIMD3<Float>(0.5, -1.0, 0.3),
            lightColor: SIMD3<Float>(1.0, 0.95, 0.9),
            time: Float(CACurrentMediaTime())
        )
        
        uniformPointer.pointee = uniforms
    }
    
    private func getCurrentUniforms() -> Uniforms {
        guard let uniformBuffer = uniformBuffer else {
            return Uniforms(
                viewMatrix: matrix_identity_float4x4,
                projectionMatrix: matrix_identity_float4x4,
                modelMatrix: matrix_identity_float4x4,
                cameraPosition: SIMD3<Float>(0, 0, 0),
                lightDirection: SIMD3<Float>(0, -1, 0),
                lightColor: SIMD3<Float>(1, 1, 1),
                time: 0
            )
        }
        
        let uniformOffset = MemoryLayout<Uniforms>.stride * frameIndex
        let uniformPointer = uniformBuffer.contents().advanced(by: uniformOffset).bindMemory(to: Uniforms.self, capacity: 1)
        return uniformPointer.pointee
    }
    
    func handleResize(size: CGSize) {
        // Recreate depth texture if needed
        // MetalFX will handle upscaling
        postProcessor?.handleResize(size: size)
    }
    
    func getTrack() -> Track? {
        return track
    }
}

// Matrix utilities
typealias float4x4 = simd_float4x4

extension float4x4 {
    static func identity() -> float4x4 {
        return matrix_identity_float4x4
    }
    
    static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let f = 1.0 / tan(fovY / 2.0)
        return float4x4(
            SIMD4<Float>(f / aspect, 0, 0, 0),
            SIMD4<Float>(0, f, 0, 0),
            SIMD4<Float>(0, 0, (far + near) / (near - far), -1),
            SIMD4<Float>(0, 0, (2 * far * near) / (near - far), 0)
        )
    }
    
    static func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
        let z = normalize(eye - target)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        
        return float4x4(
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        )
    }
    
    static func translation(_ translation: SIMD3<Float>) -> float4x4 {
        return float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        )
    }
    
    static func rotation(quaternion: simd_quatf) -> float4x4 {
        let q = quaternion
        let x = q.imag.x
        let y = q.imag.y
        let z = q.imag.z
        let w = q.real
        
        return float4x4(
            SIMD4<Float>(1 - 2*(y*y + z*z), 2*(x*y + z*w), 2*(x*z - y*w), 0),
            SIMD4<Float>(2*(x*y - z*w), 1 - 2*(x*x + z*z), 2*(y*z + x*w), 0),
            SIMD4<Float>(2*(x*z + y*w), 2*(y*z - x*w), 1 - 2*(x*x + y*y), 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    static func scale(_ scale: SIMD3<Float>) -> float4x4 {
        return float4x4(
            SIMD4<Float>(scale.x, 0, 0, 0),
            SIMD4<Float>(0, scale.y, 0, 0),
            SIMD4<Float>(0, 0, scale.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    static func * (lhs: float4x4, rhs: float4x4) -> float4x4 {
        return matrix_multiply(lhs, rhs)
    }
}

