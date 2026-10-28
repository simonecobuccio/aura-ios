import SwiftUI

// ============================================================
// MARK: - CHAT TAB VIEW (Premium gate)
// ============================================================

struct ChatTabView: View {
    @Binding var isPremium: Bool

    @State private var showPaywall = false

    var body: some View {
        ZStack {
            AuraBackground()

            if isPremium {
                AuraChatView()
            } else {
                // Premium locked state
                VStack(spacing: 24) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.15),
                                        Color(red: 0.50, green: 0.35, blue: 0.95).opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text("Aura AI")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Your personal wellness companion.\nUnlock with Aura Plus.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AuraTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        withAnimation(.spring(duration: 0.4)) { showPaywall = true }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text("Unlock Aura Plus")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(AuraTheme.bgDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white)
                        )
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                    Spacer()
                }
            }

            if showPaywall {
                PaywallView(isPresented: $showPaywall, isPremium: $isPremium)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // Blur strip that protects the Dynamic Island / status-bar zone
            TopSafeAreaBlur()
        }
        .animation(.spring(duration: 0.4), value: showPaywall)
    }
}
