import CoreMotion
import Foundation
import Observation

/// Counts reps from the wrist's movement while a set is going: each rep is
/// one clear push of acceleration above a threshold, then back below it
/// (hysteresis), at least 0.6 s apart. It's an estimate — the count only
/// fills in the number, and the athlete confirms or turns the crown.
@MainActor
@Observable
final class RepCounter {
    private(set) var count = 0
    private(set) var isCounting = false
    private let motion = CMMotionManager()
    private var armed = true
    private var lastRep = Date.distantPast

    /// Peak detection on the acceleration magnitude (in g, gravity removed).
    nonisolated static func isRep(magnitude: Double, armed: Bool, sinceLast: TimeInterval) -> (rep: Bool, armed: Bool) {
        if armed, magnitude > 0.35, sinceLast > 0.6 { return (true, false) }
        if !armed, magnitude < 0.12 { return (false, true) }
        return (false, armed)
    }

    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    func start() {
        guard motion.isDeviceMotionAvailable, !isCounting else { return }
        count = 0
        armed = true
        isCounting = true
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let a = data.userAcceleration
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            MainActor.assumeIsolated { self?.process(magnitude) }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        isCounting = false
    }

    private func process(_ magnitude: Double) {
        let result = Self.isRep(magnitude: magnitude, armed: armed, sinceLast: Date.now.timeIntervalSince(lastRep))
        armed = result.armed
        if result.rep {
            count += 1
            lastRep = .now
        }
    }
}
