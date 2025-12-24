import Foundation
import simd

final class HUDManager: ObservableObject {
    @Published var speed: Float = 0
    @Published var gear: Int = 1
    @Published var mode: String = "Race"
    @Published var showLapTimer: Bool = true
    @Published var lapTime: TimeInterval = 0
    @Published var drsState: (available: Bool, active: Bool) = (false, false)
    @Published var tireCompound: TireCompound = .medium
    @Published var tireWear: Float = 0
    @Published var isPitLimiterActive: Bool = false

    func update(speed: Float, gear: Int) {
        self.speed = speed
        self.gear = gear
    }

    func updateDRS(available: Bool, active: Bool) {
        self.drsState = (available, active)
    }

    func updateTires(compound: TireCompound, wear: Float) {
        self.tireCompound = compound
        self.tireWear = wear
    }

    func updatePitLimiter(active: Bool) {
        self.isPitLimiterActive = active
    }

    func updateLapTime(_ time: TimeInterval) {
        self.lapTime = time
    }
}
