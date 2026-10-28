import SwiftUI

// ============================================================
// MARK: - STAT CARD
// ============================================================

struct StatCard: View {
    let icon:  String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: AuraTheme.iconSize, weight: .medium))
                .foregroundColor(AuraTheme.textSecondary)
                .frame(width: AuraTheme.iconFrame, height: AuraTheme.iconFrame)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(AuraTheme.textTertiary)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassCard(cornerRadius: 18)
    }
}
