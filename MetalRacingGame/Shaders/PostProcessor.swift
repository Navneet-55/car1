import Metal

final class PostProcessor {
    private let device: MTLDevice
    private let metal4: Metal4FeatureLayer
    private let pipelineCache: PipelineCache

    init(device: MTLDevice, metal4: Metal4FeatureLayer, pipelineCache: PipelineCache) {
        self.device = device
        self.metal4 = metal4
        self.pipelineCache = pipelineCache
    }

    func handleResize(size: CGSize) {
        // Recreate post-process textures if needed
    }
}
