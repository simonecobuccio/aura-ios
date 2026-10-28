import SwiftUI

// ============================================================
// MARK: - TRENDS TAB VIEW
// ============================================================

struct TrendsTabView: View {
    @ObservedObject var dataStore: AuraDataStore
    @Binding var isPremium: Bool

    @State private var showPaywall = false

    var body: some View {
        ZStack {
            AuraBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Trends")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Your wellness over time")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(AuraTheme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    if isPremium {
                        TrendChartsView(dataStore: dataStore,
                                        chartHeight: 260)
                    } else {
                        PremiumLockedCard(showPaywall: $showPaywall)
                    }

                    Spacer(minLength: 100)
                }
            }

            // Blur strip that protects the Dynamic Island / status-bar zone
            TopSafeAreaBlur()

            if showPaywall {
                PaywallView(isPresented: $showPaywall, isPremium: $isPremium)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: showPaywall)
    }
}
