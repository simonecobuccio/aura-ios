import SwiftUI
import Combine

@MainActor
class AuraChatAIViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false

    // Groq API key – get a free one at https://console.groq.com/keys
    // Generous free tier: 30 req/min, 14,400 req/day
    private let apiKey = "YOUR_GROQ_API_KEY"
    private let model  = "llama-3.3-70b-versatile"

    private var systemPrompt: String {
        """
        You are Aura AI, a friendly and empathetic wellness assistant inside the Aura app. \
        The app tracks mood (2x daily), sleep, steps, heart rate, UV exposure and sunlight. \
        Keep answers concise (2-4 sentences). Use a warm, supportive tone. \
        When relevant, reference the user's data patterns. \
        Never give medical diagnoses – suggest consulting a professional when appropriate.
        """
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMsg = ChatMessage(role: .user, text: text)
        messages.append(userMsg)
        inputText = ""
        isLoading = true

        Task { await callAI(userText: text) }
    }

    private func callAI(userText: String) async {
        // Build messages array (OpenAI-compatible format)
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Add conversation history (last 10 messages)
        for msg in messages.suffix(10) {
            apiMessages.append([
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.text
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": apiMessages,
            "max_tokens": 300,
            "temperature": 0.7
        ]

        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            appendError("Could not build API URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                appendError("Invalid response format.")
                return
            }

            // Check for API error
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("Groq API error: \(message)")
                if message.lowercased().contains("rate") || message.lowercased().contains("limit") {
                    appendError("I'm resting for a moment — too many requests. Try again in about 30 seconds.")
                } else if message.lowercased().contains("api key") || message.lowercased().contains("auth") {
                    appendError("API key issue. Please check your Groq key in the code.")
                } else {
                    appendError("API error: \(message)")
                }
                return
            }

            // Parse OpenAI-compatible response
            if let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                messages.append(ChatMessage(role: .assistant, text: content.trimmingCharacters(in: .whitespacesAndNewlines)))
            } else {
                let raw = String(data: data, encoding: .utf8) ?? "no data"
                print("Groq unexpected response: \(raw)")
                appendError("Unexpected response format.")
            }
        } catch {
            appendError("Network error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func appendError(_ text: String) {
        messages.append(ChatMessage(role: .assistant, text: text))
        isLoading = false
    }
}
