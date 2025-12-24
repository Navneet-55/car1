import Foundation

final class PerformanceMonitor: ObservableObject {
    @Published var frameTimeMS: Double = 0
    @Published var gpuTimeMS: Double = 0
    @Published var drawCalls: Int = 0
    @Published var triangles: Int = 0
    @Published var hardwareInfo: String = ""

    func update(frameTime: CFTimeInterval, gpuTime: CFTimeInterval) {
        frameTimeMS = frameTime * 1000.0
        gpuTimeMS = gpuTime * 1000.0
    }
    func setDrawCalls(_ value: Int) { drawCalls = value }
    func setTriangles(_ value: Int) { triangles = value }
    func setHardwareInfo(_ info: String) { hardwareInfo = info }
}
