import SwiftUI

// ============================================================
// MARK: - PRE-BUILT HAPTIC GENERATORS (avoid alloc in gestures)
// ============================================================

enum AuraHaptics {
    static let medium: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        return g
    }()

    static let light: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        return g
    }()

    /// Throttled haptic — fires at most once per interval to avoid
    /// saturating the Taptic Engine during fast chart scrubbing.
    private static var lastLightFire: CFTimeInterval = 0
    static func throttledLight(interval: CFTimeInterval = 0.045) {
        let now = CACurrentMediaTime()
        guard now - lastLightFire >= interval else { return }
        lastLightFire = now
        light.impactOccurred()
    }
}
