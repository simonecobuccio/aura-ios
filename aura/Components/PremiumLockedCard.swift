import SwiftUI

// ============================================================
// MARK: - PREMIUM LOCKED CARD
// ============================================================

struct PremiumLockedCard: View {
    @Binding var showPaywall: Bool

    /// Pre-computed deterministic bar heights (avoid CGFloat.random in body)
    static let fakeBars: [CGFloat] = [
        25, 42, 18, 35, 50, 30, 45, 20, 38, 52,
        28, 48, 15, 40, 33, 55, 22, 37, 46, 31
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            SectionHeader(title: "Trend Analysis")

            Button(action: { withAnimation(.spring(duration: 0.4)) { showPaywall = true } }) {
                ZStack {
                    // Blurred fake chart preview
                    VStack(spacing: 12) {
                        // Fake trend lines (deterministic heights to avoid re-layout)
                        HStack(spacing: 4) {
                            ForEach(Array(PremiumLockedCard.fakeBars.enumerated()), id: \.offset) { _, h in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(red: 0.35, green: 0.78, blue: 1.0).opacity(0.4))
                                    .frame(width: 10, height: h)
                            }
                        }
                        .frame(height: 60)

                        HStack(spacing: 20) {
                            fakeStatPill(icon: "chart.line.uptrend.xyaxis", text: "Sleep trends")
                            fakeStatPill(icon: "figure.walk.motion", text: "Activity score")
                            fakeStatPill(icon: "brain.head.profile", text: "Mood insights")
                        }
                    }
                    .padding(20)
                    .blur(radius: 6)

                    // Lock overlay
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                        }

                        Text("Unlock Trend Analysis")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Deep dive into your patterns over time")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AuraTheme.textSecondary)

                        HStack(spacing: 4) {
                            Text("Aura Plus")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.45, green: 0.75, blue: 1.0))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.45, green: 0.75, blue: 1.0))
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .glassCard()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func fakeStatPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundColor(AuraTheme.textTertiary)
    }
}
