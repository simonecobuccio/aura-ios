import SwiftUI

// ============================================================
// MARK: - AURA RING VIEW
// ============================================================

struct AuraRingView: View {
    let score: AuraScore
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Ring layers (GPU-composited for blur + shadow performance)
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: size * 0.08)
                    .frame(width: size, height: size)

                // Glow (same arc, blurred)
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(score.color.opacity(0.22),
                            style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 12)

                // Main arc — single solid color, no AngularGradient seam
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        score.color,
                        style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: score.color.opacity(0.5), radius: 14)
            }
            .padding(30)   // room for glow + shadow before rasterisation
            .drawingGroup()   // Metal-backed: avoids per-frame blur re-rasterisation
            .padding(-30)  // collapse the extra space back

            // Centre content (outside drawingGroup for crisp text)
            VStack(spacing: 0) {
                Text("\(Int(score.composite * 100))")
                    .font(.system(size: size * 0.26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text(score.label)
                    .font(.system(size: size * 0.075, weight: .bold, design: .rounded))
                    .foregroundColor(AuraTheme.textTertiary)
                    .textCase(.uppercase)
                    .tracking(2.5)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) { animatedProgress = score.composite }
        }
        .onChange(of: score.composite) { _, newVal in
            withAnimation(.easeOut(duration: 0.9)) { animatedProgress = newVal }
        }
    }
}
