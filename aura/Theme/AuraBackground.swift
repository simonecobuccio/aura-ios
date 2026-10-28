import SwiftUI

// ============================================================
// MARK: - SHARED BACKGROUND (same on every screen)
// ============================================================

struct AuraBackground: View {
    var primaryColor:   Color = Color(red: 0.30, green: 0.55, blue: 1.0)
    var secondaryColor: Color = Color(red: 0.50, green: 0.28, blue: 0.78)

    var body: some View {
        ZStack {
            AuraTheme.bgDeep

            // Top-center main glow
            RadialGradient(
                colors: [primaryColor.opacity(0.15), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: 20, endRadius: 420
            )

            // Bottom-left warm accent
            RadialGradient(
                colors: [secondaryColor.opacity(0.10), Color.clear],
                center: UnitPoint(x: 0.15, y: 0.85),
                startRadius: 10, endRadius: 340
            )

            // Top-right cool accent
            RadialGradient(
                colors: [Color(red: 0.20, green: 0.25, blue: 0.55).opacity(0.09), Color.clear],
                center: UnitPoint(x: 0.9, y: 0.12),
                startRadius: 10, endRadius: 280
            )

            // Grain
            Rectangle()
                .fill(.white.opacity(0.012))
                .blendMode(.plusLighter)
        }
        .drawingGroup()   // Metal-backed: flatten 4 gradient layers → 1 texture
        .ignoresSafeArea()
    }
}

// ============================================================
// MARK: - TOP SAFE-AREA BLUR (Dynamic Island protection)
// ============================================================

/// A translucent blur strip that sits at the top of the screen,
/// covering the status-bar / Dynamic-Island zone.  It uses
/// `.ultraThinMaterial` masked with a vertical gradient so the
/// bottom edge dissolves smoothly into the content underneath.
///
/// Drop it as the **last layer** inside any `ZStack` that contains
/// a `ScrollView` so scrolling content never clashes with the
/// system clock, signal icons, or the Dynamic Island.
struct TopSafeAreaBlur: View {
    /// Total visible height of the gradient blur below the safe area.
    var extraHeight: CGFloat = 32

    /// Cached safe-area top so we don't spin up GeometryReader every frame.
    @State private var safeTop: CGFloat = 59  // sensible default for Dynamic Island devices

    var body: some View {
        let totalH = safeTop + extraHeight

        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: totalH)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.55),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .onAppear {
                // Read safe area once from the key window
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first {
                    safeTop = window.safeAreaInsets.top
                }
            }
    }
}
