import Foundation
public final class DRSSystem {
    private var available: Bool = true
    private var active: Bool = false
    private var topSpeedBonus: Float = 10.0 // km/h
    private var dragMultiplier: Float = 0.9

    public init() {}

    public func update(deltaTime: Float, trackDistance: Float, speed: Float, braking: Float, steering: Float, drsButtonPressed: Bool) {
        // Simple rule: DRS available when not braking hard and steering small
        available = (braking < 0.2 && abs(steering) < 0.3)
        active = available && drsButtonPressed
        // Adjust multipliers when active
        if active {
            dragMultiplier = 0.8
            topSpeedBonus = 20.0
        } else {
            dragMultiplier = 1.0
            topSpeedBonus = 0.0
        }
    }

    public func isDRSAvailable() -> Bool { available }
    public func isDRSActive() -> Bool { active }
    public func getTopSpeedBonus() -> Float { topSpeedBonus }
    public func getDragMultiplier() -> Float { dragMultiplier }
}
