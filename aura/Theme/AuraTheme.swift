import SwiftUI

// ============================================================
// MARK: - DESIGN TOKENS
// ============================================================

enum AuraTheme {
    static let bgDeep      = Color(red: 0.04, green: 0.04, blue: 0.09)
    static let bgElevated  = Color(red: 0.09, green: 0.09, blue: 0.15)

    static let glass       = Color.white.opacity(0.05)
    static let glassBorder = Color.white.opacity(0.07)

    static let textPrimary   = Color.white
    static let textSecondary = Color(red: 0.72, green: 0.73, blue: 0.78)
    static let textTertiary  = Color(red: 0.45, green: 0.46, blue: 0.52)

    static let iconSize:  CGFloat = 21
    static let iconFrame: CGFloat = 26
}

// ============================================================
// MARK: - PRESS-DOWN BUTTON STYLE
// ============================================================

/// Snappy scale-down on press.  The release is deliberately fast
/// (no long spring) so that rapid successive taps are never eaten
/// by an in-flight animation.
struct AuraPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}
