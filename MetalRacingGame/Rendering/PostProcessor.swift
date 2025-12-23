//
//  PostProcessor.swift
//  MetalRacingGame
//
//  Post-processing effects (motion blur, bloom, tone mapping)
//

import Metal
import MetalKit
import simd

/// Post-processing effects pipeline
class PostProcessor {
    private let device: MTLDevice
    private let metal4: Metal4FeatureLayer
    private let pipelineCache: PipelineCache
    private var motionBlurPipeline: MTLComputePipelineState?
    private var bloomPipeline: MTLComputePipelineState?
    private var toneMapPipeline: MTLComputePipelineState?
    
    // Textures
    private var historyTexture: MTLTexture?
    private var bloomTexture: MTLTexture?
    
    // Settings
    var motionBlurEnabled: Bool = true
    var motionBlurStrength: Float = 0.5
    var bloomEnabled: Bool = true
    var bloomIntensity: Float = 0.3
    
    init(device: MTLDevice, metal4: Metal4FeatureLayer, pipelineCache: PipelineCache) {
        self.device = device
        self.metal4 = metal4
        self.pipelineCache = pipelineCache
        setupPipelines()
    }
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        // Motion blur (use pipeline cache - Metal 4 compiler path when available)
        if let function = library.makeFunction(name: "motion_blur") {
            motionBlurPipeline = pipelineCache.createComputePipelineState(function: function, name: "motion_blur")
        }
        
        // Bloom (use pipeline cache)
        if let function = library.makeFunction(name: "bloom") {
            bloomPipeline = pipelineCache.createComputePipelineState(function: function, name: "bloom")
        }
        
        // Tone mapping (use pipeline cache)
        if let function = library.makeFunction(name: "tone_map") {
            toneMapPipeline = pipelineCache.createComputePipelineState(function: function, name: "tone_map")
        }
    }
    
    /// Apply post-processing effects
    func process(commandBuffer: MTLCommandBuffer,
                 inputTexture: MTLTexture,
                 outputTexture: MTLTexture,
                 velocityTexture: MTLTexture?,
                 deltaTime: Float) {
        
        var currentTexture = inputTexture
        
        // Motion blur
        if motionBlurEnabled, let pipeline = motionBlurPipeline, let velocity = velocityTexture {
            if let encoder = commandBuffer.makeComputeCommandEncoder() {
                encoder.setComputePipelineState(pipeline)
                encoder.setTexture(currentTexture, index: 0)
                encoder.setTexture(velocity, index: 1)
                encoder.setTexture(outputTexture, index: 2)
                
                var strength = motionBlurStrength
                encoder.setBytes(&strength, length: MemoryLayout<Float>.stride, index: 0)
                
                let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
                let threadgroupCount = MTLSize(
                    width: (outputTexture.width + 15) / 16,
                    height: (outputTexture.height + 15) / 16,
                    depth: 1
                )
                encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                encoder.endEncoding()
                
                currentTexture = outputTexture
            }
        }
        
        // Bloom (simplified - would need multiple passes for proper bloom)
        if bloomEnabled, let pipeline = bloomPipeline {
            // Create bloom texture if needed
            if bloomTexture == nil || bloomTexture!.width != inputTexture.width / 2 {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: inputTexture.pixelFormat,
                    width: inputTexture.width / 2,
                    height: inputTexture.height / 2,
                    mipmapped: false
                )
                descriptor.usage = [.shaderRead, .shaderWrite]
                bloomTexture = device.makeTexture(descriptor: descriptor)
            }
            
            if let encoder = commandBuffer.makeComputeCommandEncoder(), let bloom = bloomTexture {
                encoder.setComputePipelineState(pipeline)
                encoder.setTexture(currentTexture, index: 0)
                encoder.setTexture(bloom, index: 1)
                
                var intensity = bloomIntensity
                encoder.setBytes(&intensity, length: MemoryLayout<Float>.stride, index: 0)
                
                let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
                let threadgroupCount = MTLSize(
                    width: (bloom.width + 15) / 16,
                    height: (bloom.height + 15) / 16,
                    depth: 1
                )
                encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                encoder.endEncoding()
            }
        }
    }
    
    func handleResize(size: CGSize) {
        historyTexture = nil
        bloomTexture = nil
    }
}

