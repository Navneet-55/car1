import Foundation
import simd

public enum TireCompound {
    case soft, medium, hard
}

public struct Tires {
    var compound: TireCompound
    var wear: Float
}

public enum PitStopState {
    case idle, entering, stopped, exiting
}

public final class PitStopSystem {
    var currentTires: Tires = Tires(compound: .medium, wear: 0)
    var state: PitStopState = .idle
    var isPitLimiterActive: Bool = false

    init() {}

    func update(deltaTime: Float, trackDistance: Float, speed: Float, position: SIMD3<Float>, pitButtonPressed: Bool) {
        if pitButtonPressed {
            state = .stopped
            isPitLimiterActive = true
        } else {
            state = .idle
            isPitLimiterActive = false
        }
        currentTires.wear = max(0, min(1, currentTires.wear + deltaTime * 0.001))
    }

    func cycleCompound() {
        switch currentTires.compound {
        case .soft:
            currentTires.compound = .medium
        case .medium:
            currentTires.compound = .hard
        case .hard:
            currentTires.compound = .soft
        }
        currentTires.wear = 0
    }

    func getGripMultiplier() -> Float {
        let baseGrip: Float
        switch currentTires.compound {
        case .soft: baseGrip = 1.1
        case .medium: baseGrip = 1.0
        case .hard: baseGrip = 0.9
        }
        return baseGrip - currentTires.wear * 0.3
    }

    func getSpeedLimit() -> Float? {
        return isPitLimiterActive ? 80 : nil
    }

    func getTireColor() -> SIMD3<Float> {
        switch currentTires.compound {
        case .soft:
            return SIMD3<Float>(1, 0, 0)
        case .medium:
            return SIMD3<Float>(1, 0.8, 0)
        case .hard:
            return SIMD3<Float>(1, 1, 1)
        }
    }
}
