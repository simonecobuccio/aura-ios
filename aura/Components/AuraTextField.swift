import SwiftUI

// ============================================================
// MARK: - CUSTOM TEXT FIELD
// ============================================================

struct AuraTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    @State private var isRevealed: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AuraTheme.textTertiary)
                .frame(width: 20)

            if isSecure && !isRevealed {
                SecureField("", text: $text, prompt: promptText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .tint(Color(red: 0.45, green: 0.65, blue: 1.0))
            } else {
                TextField("", text: $text, prompt: promptText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .tint(Color(red: 0.45, green: 0.65, blue: 1.0))
            }

            if isSecure {
                Button(action: { isRevealed.toggle() }) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AuraTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var promptText: Text {
        Text(placeholder)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(AuraTheme.textTertiary)
    }
}
