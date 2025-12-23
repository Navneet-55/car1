//
//  RayTracingRenderer.swift
//  MetalRacingGame
//
//  Metal Ray Tracing for reflections, GI, and shadows
//

import Metal
import MetalKit
import simd

/// Ray tracing renderer with tiered system: hardware RT when supported, stable fallback when not
class RayTracingRenderer {
    private let device: MTLDevice
    private let capabilities: HardwareCapabilities
    private let metal4: Metal4FeatureLayer
    private let pipelineCache: PipelineCache
    
    // Ray tracing mode
    enum RayTracingMode {
        case hardware // Hardware-accelerated (M3+)
        case computeFallback // Compute-based fallback (SSR/probes)
        case disabled // Disabled for performance
    }
    
    private var mode: RayTracingMode = .disabled
    
    // Hardware ray tracing pipeline
    private var rayTracingPipeline: MTLComputePipelineState?
    private var accelerationStructure: MTLAccelerationStructure?
    
    // Fallback pipelines (SSR, reflection probes)
    private var ssrPipeline: MTLComputePipelineState?
    private var denoisingPipeline: MTLComputePipelineState?
    
    // Resources
    private var rayTracingBuffer: MTLBuffer?
    private var intersectionBuffer: MTLBuffer?
    private var denoisedTexture: MTLTexture?
    
    // Quality settings (adaptive)
    private var raySamplesPerPixel: Int = 1
    private var maxRayBounces: Int = 1
    private var reflectionDistance: Float = 100.0
    
    init(device: MTLDevice, capabilities: HardwareCapabilities, metal4: Metal4FeatureLayer) {
        self.device = device
        self.capabilities = capabilities
        self.metal4 = metal4
        
        // Create pipeline cache for ray tracing shaders
        self.pipelineCache = PipelineCache(device: device, metal4: metal4)
        
        // Determine ray tracing mode
        if capabilities.hasRayTracing {
            mode = .hardware
            print("Ray Tracing: Hardware-accelerated mode enabled")
        } else {
            mode = .computeFallback
            print("Ray Tracing: Compute-based fallback mode (SSR/probes)")
        }
        
        setupRayTracing()
    }
    
    private func setupRayTracing() {
        guard let library = device.makeDefaultLibrary() else {
            print("Warning: Failed to create Metal library for ray tracing")
            return
        }
        
        switch mode {
        case .hardware:
            // Hardware-accelerated ray tracing (M3+)
            // Use MTLAccelerationStructure for hardware RT
            if let computeFunction = library.makeFunction(name: "ray_tracing_compute") {
                rayTracingPipeline = pipelineCache.createComputePipelineState(
                    function: computeFunction,
                    name: "ray_tracing_compute"
                )
            }
            
            // Denoising pipeline (Metal 4 path when available)
            if let denoiseFunction = library.makeFunction(name: "ray_tracing_denoise") {
                denoisingPipeline = pipelineCache.createComputePipelineState(
                    function: denoiseFunction,
                    name: "ray_tracing_denoise"
                )
            }
            
        case .computeFallback:
            // Screen-space reflections (SSR) fallback
            if let ssrFunction = library.makeFunction(name: "screen_space_reflections") {
                ssrPipeline = pipelineCache.createComputePipelineState(
                    function: ssrFunction,
                    name: "screen_space_reflections"
                )
            } else {
                // Fallback to basic compute if SSR shader not available
                if let computeFunction = library.makeFunction(name: "ray_tracing_compute") {
                    ssrPipeline = pipelineCache.createComputePipelineState(
                        function: computeFunction,
                        name: "ray_tracing_compute"
                    )
                }
            }
            
        case .disabled:
            break
        }
    }
    
    /// Render reflections using tiered ray tracing system
    func renderReflections(
        commandBuffer: MTLCommandBuffer,
        renderEncoder: MTLRenderCommandEncoder,
        uniforms: MetalRenderer.Uniforms,
        renderTarget: MTLTexture,
        depthTexture: MTLTexture,
        normalTexture: MTLTexture?,
        renderQuality: RenderQuality
    ) {
        guard mode != .disabled else { return }
        
        // Adaptive quality: reduce ray tracing intensity if performance is poor
        let adaptiveSamples = max(1, raySamplesPerPixel)
        let adaptiveBounces = max(1, maxRayBounces)
        
        switch mode {
        case .hardware:
            // Hardware-accelerated ray tracing
            guard let computePipeline = rayTracingPipeline else {
                // Fallback to compute if hardware RT fails
                renderReflectionsFallback(
                    commandBuffer: commandBuffer,
                    renderTarget: renderTarget,
                    depthTexture: depthTexture,
                    normalTexture: normalTexture
                )
                return
            }
            
            // Create ray tracing output texture if needed
            if denoisedTexture == nil || 
               denoisedTexture!.width != renderTarget.width ||
               denoisedTexture!.height != renderTarget.height {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: renderTarget.pixelFormat,
                    width: renderTarget.width,
                    height: renderTarget.height,
                    mipmapped: false
                )
                descriptor.usage = [.shaderRead, .shaderWrite]
                denoisedTexture = device.makeTexture(descriptor: descriptor)
            }
            
            guard let denoised = denoisedTexture else { return }
            
            // Ray tracing pass
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                computeEncoder.setComputePipelineState(computePipeline)
                computeEncoder.setTexture(renderTarget, index: 0)
                computeEncoder.setTexture(depthTexture, index: 1)
                if let normal = normalTexture {
                    computeEncoder.setTexture(normal, index: 2)
                }
                computeEncoder.setTexture(denoised, index: 3)
                
                // Set ray tracing parameters
                var params = RayTracingParams(
                    samplesPerPixel: Int32(adaptiveSamples),
                    maxBounces: Int32(adaptiveBounces),
                    reflectionDistance: reflectionDistance,
                    cameraPosition: uniforms.cameraPosition,
                    viewMatrix: uniforms.viewMatrix,
                    projectionMatrix: uniforms.projectionMatrix
                )
                computeEncoder.setBytes(&params, length: MemoryLayout<RayTracingParams>.stride, index: 0)
                
                // Dispatch threads
                let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
                let threadgroupCount = MTLSize(
                    width: (renderTarget.width + 15) / 16,
                    height: (renderTarget.height + 15) / 16,
                    depth: 1
                )
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                computeEncoder.endEncoding()
            }
            
            // Denoising pass (Metal 4 path when available)
            if let denoisePipeline = denoisingPipeline {
                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    computeEncoder.setComputePipelineState(denoisePipeline)
                    computeEncoder.setTexture(denoised, index: 0)
                    computeEncoder.setTexture(renderTarget, index: 1)
                    
                    let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
                    let threadgroupCount = MTLSize(
                        width: (renderTarget.width + 15) / 16,
                        height: (renderTarget.height + 15) / 16,
                        depth: 1
                    )
                    computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                    computeEncoder.endEncoding()
                }
            } else {
                // Copy denoised texture to render target if no denoising
                if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                    blitEncoder.copy(from: denoised, to: renderTarget)
                    blitEncoder.endEncoding()
                }
            }
            
        case .computeFallback:
            // Screen-space reflections fallback
            renderReflectionsFallback(
                commandBuffer: commandBuffer,
                renderTarget: renderTarget,
                depthTexture: depthTexture,
                normalTexture: normalTexture
            )
            
        case .disabled:
            break
        }
    }
    
    /// Fallback reflections using SSR or probes
    private func renderReflectionsFallback(
        commandBuffer: MTLCommandBuffer,
        renderTarget: MTLTexture,
        depthTexture: MTLTexture,
        normalTexture: MTLTexture?
    ) {
        guard let ssrPipeline = ssrPipeline else { return }
        
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(ssrPipeline)
            computeEncoder.setTexture(renderTarget, index: 0)
            computeEncoder.setTexture(depthTexture, index: 1)
            if let normal = normalTexture {
                computeEncoder.setTexture(normal, index: 2)
            }
            
            let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroupCount = MTLSize(
                width: (renderTarget.width + 15) / 16,
                height: (renderTarget.height + 15) / 16,
                depth: 1
            )
            computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
            computeEncoder.endEncoding()
        }
    }
    
    /// Adjust ray tracing quality based on performance (auto-scale to protect frame pacing)
    func adjustQuality(targetFPS: Double, currentFPS: Double) {
        let fpsRatio = currentFPS / targetFPS
        
        if fpsRatio < 0.9 {
            // Performance is below target - reduce quality
            raySamplesPerPixel = max(1, raySamplesPerPixel - 1)
            maxRayBounces = max(1, maxRayBounces - 1)
            reflectionDistance = max(50.0, reflectionDistance * 0.9)
        } else if fpsRatio > 1.1 && raySamplesPerPixel < 4 {
            // Performance is above target - increase quality
            raySamplesPerPixel = min(4, raySamplesPerPixel + 1)
            maxRayBounces = min(2, maxRayBounces + 1)
            reflectionDistance = min(200.0, reflectionDistance * 1.1)
        }
    }
    
    /// Disable ray tracing if performance is critically poor
    func disableIfNeeded(currentFPS: Double, minAcceptableFPS: Double = 30.0) {
        if currentFPS < minAcceptableFPS && mode != .disabled {
            mode = .disabled
            print("Ray Tracing: Disabled due to poor performance (FPS: \(currentFPS))")
        }
    }
    
    /// Build acceleration structure for ray tracing
    func buildAccelerationStructure(geometry: [MTLAccelerationStructureGeometryDescriptor]) {
        guard capabilities.hasRayTracing else { return }
        
        // Create acceleration structure builder
        let builder = MTLAccelerationStructureDescriptor()
        // builder.geometryDescriptors = geometry
        
        // Build acceleration structure
        // This requires proper geometry setup
    }
    
    func handleResize(size: CGSize) {
        // Recreate ray tracing resources if needed
        denoisedTexture = nil
    }
}

/// Ray tracing parameters structure
struct RayTracingParams {
    var samplesPerPixel: Int32
    var maxBounces: Int32
    var reflectionDistance: Float
    var cameraPosition: SIMD3<Float>
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
}

