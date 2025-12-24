import Metal
import simd

final class F1Car {
    private let device: MTLDevice
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?

    struct MaterialProps { var color: SIMD3<Float>; var metallic: Float; var roughness: Float }
    private var material = MaterialProps(color: SIMD3<Float>(0.8, 0.1, 0.1), metallic: 0.2, roughness: 0.4)

    init(device: MTLDevice) {
        self.device = device
        buildSimpleGeometry()
    }

    private func buildSimpleGeometry() {
        // Simple pyramid/box-ish placeholder
        let vertices: [Float] = [
            -0.5, 0, -1, 0,0,
             0.5, 0, -1, 1,0,
             0.5, 0,  1, 1,1,
            -0.5, 0,  1, 0,1
        ]
        let indices: [UInt16] = [0,1,2, 2,3,0]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: [])
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])
    }

    func getVertexBuffer() -> MTLBuffer? { vertexBuffer }
    func getIndexBuffer() -> MTLBuffer? { indexBuffer }
    func getIndexCount() -> Int { 6 }

    func getMaterialProperties() -> MaterialProps { material }
}
