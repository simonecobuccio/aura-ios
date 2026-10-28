import SwiftUI

// ============================================================
// MARK: - PAYWALL VIEW
// ============================================================

struct PaywallView: View {
    @Binding var isPresented: Bool
    @Binding var isPremium: Bool
    @State private var selectedCard: Int? = nil
    @State private var trialToggle: Bool = true
    @State private var showConfirmation: Bool = false

    // Fake credit cards
    private let cards: [(brand: String, last4: String, icon: String, color: Color)] = [
        ("Visa",       "4821", "creditcard.fill",
         Color(red: 0.15, green: 0.25, blue: 0.65)),
        ("Mastercard", "7390", "creditcard.fill",
         Color(red: 0.75, green: 0.20, blue: 0.15)),
        ("Amex",       "3012", "creditcard.fill",
         Color(red: 0.20, green: 0.55, blue: 0.45)),
    ]

    // Plus features
    private let features: [(icon: String, title: String, desc: String)] = [
        ("chart.line.uptrend.xyaxis", "Trend Analysis",
         "See your mood, sleep and activity patterns over weeks and months."),
        ("brain.head.profile", "AI Insights",
         "Personalised tips based on your data correlations."),
        ("bell.badge", "Smart Reminders",
         "Daily check-ins at 9:00 and 18:00 to track your mood."),
    ]

    var body: some View {
        ZStack {
            AuraBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // Nav bar
                    HStack {
                        Button(action: {
                            withAnimation(.spring(duration: 0.35)) { isPresented = false }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AuraTheme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(AuraTheme.glass))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // Header
                    VStack(spacing: 10) {
                        // Plus badge
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text("AURA PLUS")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .tracking(2)
                        }
                        .foregroundColor(Color(red: 0.45, green: 0.75, blue: 1.0))

                        Text("Unlock Your\nFull Potential")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Deep insights, trends, and AI-powered guidance")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(AuraTheme.textSecondary)
                    }

                    // Features list
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.offset) { i, feat in
                            HStack(spacing: 16) {
                                Image(systemName: feat.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color(red: 0.45, green: 0.75, blue: 1.0))
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feat.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text(feat.desc)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(AuraTheme.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 14)

                            if i < features.count - 1 {
                                Rectangle()
                                    .fill(AuraTheme.glassBorder)
                                    .frame(height: 0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .glassCard()
                    .padding(.horizontal)

                    // Price
                    VStack(spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("€15")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("/ month")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(AuraTheme.textSecondary)
                        }

                        // Free trial toggle
                        Button(action: { withAnimation { trialToggle.toggle() } }) {
                            HStack(spacing: 8) {
                                Image(systemName: trialToggle
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(trialToggle
                                                     ? Color(red: 0.45, green: 0.75, blue: 1.0)
                                                     : AuraTheme.textTertiary)

                                Text("Start with 1-month free trial")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)

                        if trialToggle {
                            Text("You won't be charged until the trial ends. Cancel anytime.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(AuraTheme.textTertiary)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        }
                    }

                    // Payment method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PAYMENT METHOD")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AuraTheme.textTertiary)
                            .tracking(1)
                            .padding(.horizontal, 4)

                        ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                            Button(action: {
                                withAnimation(.spring(duration: 0.25)) { selectedCard = i }
                            }) {
                                HStack(spacing: 14) {
                                    // Card color indicator
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(card.color)
                                        .frame(width: 44, height: 30)
                                        .overlay(
                                            Image(systemName: card.icon)
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.9))
                                        )

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(card.brand)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("•••• \(card.last4)")
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundColor(AuraTheme.textTertiary)
                                    }

                                    Spacer()

                                    Image(systemName: selectedCard == i
                                          ? "checkmark.circle.fill"
                                          : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedCard == i
                                                         ? Color(red: 0.45, green: 0.75, blue: 1.0)
                                                         : AuraTheme.textTertiary)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(selectedCard == i
                                              ? Color.white.opacity(0.08)
                                              : Color.clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(selectedCard == i
                                                        ? Color.white.opacity(0.15)
                                                        : AuraTheme.glassBorder,
                                                        lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    // Subscribe button
                    Button(action: {
                        withAnimation(.spring(duration: 0.4)) { showConfirmation = true }
                    }) {
                        Text(trialToggle ? "Start Free Trial" : "Subscribe Now")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(AuraTheme.bgDeep)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.white)
                            )
                    }
                    .padding(.horizontal, 24)
                    .disabled(selectedCard == nil)
                    .opacity(selectedCard == nil ? 0.5 : 1.0)

                    // Legal
                    Text("Recurring billing. Cancel anytime in Settings.\nTerms of Service · Privacy Policy")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(AuraTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 30)
                }
            }

            // Confirmation overlay
            if showConfirmation {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(Color(red: 0.4, green: 0.92, blue: 0.6))

                    Text(trialToggle ? "Trial Activated!" : "Welcome to Plus!")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text(trialToggle
                         ? "Your 1-month free trial is active.\nYou'll be charged €15/month after it ends."
                         : "You now have full access to Aura Plus.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AuraTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        isPremium = true
                        AuraNotificationManager.shared.enableReminders()
                        withAnimation { showConfirmation = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(duration: 0.35)) { isPresented = false }
                        }
                    }) {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AuraTheme.bgDeep)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.white)
                            )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AuraTheme.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(AuraTheme.glassBorder, lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: showConfirmation)
    }
}
