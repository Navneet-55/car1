import Metal
import simd

final class Track {
    private let device: MTLDevice
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    let length: Float

    init(device: MTLDevice, length: Float) {
        self.device = device
        self.length = length
        buildSimpleGeometry()
    }

    private func buildSimpleGeometry() {
        // Simple rectangle loop as placeholder
        let vertices: [Float] = [
            -50, 0, -200, 0, 0,
             50, 0, -200, 1, 0,
             50, 0,  200, 1, 1,
            -50, 0,  200, 0, 1
        ]
        let indices: [UInt16] = [0,1,2, 2,3,0]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: [])
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])
    }

    func getVertexBuffer() -> MTLBuffer? { vertexBuffer }
    func getIndexBuffer() -> MTLBuffer? { indexBuffer }
    func getIndexCount() -> Int { 6 }
}
