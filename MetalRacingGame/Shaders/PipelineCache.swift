import Metal

final class PipelineCache {
    private let device: MTLDevice
    private let metal4: Metal4FeatureLayer

    init(device: MTLDevice, metal4: Metal4FeatureLayer) {
        self.device = device
        self.metal4 = metal4
    }

    func warmupShaders() {
        // In a real implementation, precompile all needed pipelines
    }

    func createRenderPipelineState(descriptor: MTLRenderPipelineDescriptor, name: String) -> MTLRenderPipelineState? {
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("PipelineCache: Failed to create render pipeline \(name): \(error)")
            return nil
        }
    }

    func createComputePipelineState(function: MTLFunction, name: String) -> MTLComputePipelineState? {
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            print("PipelineCache: Failed to create compute pipeline \(name): \(error)")
            return nil
        }
    }
}
