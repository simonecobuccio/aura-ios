import SwiftUI

// ────────────────────────────────────────────────────────
// MARK: - CHAT BUBBLE
// ────────────────────────────────────────────────────────

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 50) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isUser ? AuraTheme.bgDeep : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isUser
                                  ? Color.white
                                  : Color.white.opacity(0.08))
                    )

                Text(AuraFormatters.timeShort.string(from: message.date))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(AuraTheme.textTertiary)
            }

            if !isUser { Spacer(minLength: 50) }
        }
    }
}
