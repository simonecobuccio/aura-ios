import SwiftUI

// ============================================================
// MARK: - AI CHAT (Groq / Llama 3.3 – Premium only)
// ============================================================

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let text: String
    let date = Date()

    enum ChatRole { case user, assistant }
}
