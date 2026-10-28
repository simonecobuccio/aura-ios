import SwiftUI

// ────────────────────────────────────────────────────────
// MARK: - CHAT VIEW
// ────────────────────────────────────────────────────────

struct AuraChatView: View {
    @StateObject private var vm = AuraChatAIViewModel()
    @FocusState private var isFocused: Bool

    /// Avoid calling trimmingCharacters 3× per body evaluation
    private var inputIsEmpty: Bool {
        vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.35, green: 0.78, blue: 1.0),
                                        Color(red: 0.55, green: 0.35, blue: 0.95)
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Aura AI")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Your wellness companion")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(AuraTheme.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .background(AuraTheme.bgElevated)

            Divider().overlay(AuraTheme.glassBorder)

            // ── Messages ──
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {

                        // Welcome message
                        if vm.messages.isEmpty {
                            VStack(spacing: 16) {
                                Spacer(minLength: 40)

                                Image(systemName: "sparkles")
                                    .font(.system(size: 36))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.45, green: 0.75, blue: 1.0),
                                                Color(red: 0.65, green: 0.45, blue: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                                Text("Hi! I'm Aura AI")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Text("Ask me about your wellbeing trends,\ntips for better sleep, or anything\nrelated to your health journey.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AuraTheme.textSecondary)
                                    .multilineTextAlignment(.center)

                                // Quick prompts
                                VStack(spacing: 8) {
                                    quickPrompt("How's my mood trend this week?")
                                    quickPrompt("Tips for better sleep quality")
                                    quickPrompt("How can I get more daylight?")
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }

                        ForEach(vm.messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id.uuidString)
                        }

                        if vm.isLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .id("loading")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { isFocused = false }
                .onChange(of: vm.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(vm.messages.last?.id.uuidString ?? "loading",
                                       anchor: .bottom)
                    }
                }
            }

            // ── Input bar (ChatGPT-style floating capsule) ──
            HStack(alignment: .bottom, spacing: 0) {
                TextField("Ask Aura AI...", text: $vm.inputText, axis: .vertical)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .tint(Color(red: 0.45, green: 0.65, blue: 1.0))
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .padding(.leading, 18)
                    .padding(.trailing, 6)
                    .padding(.vertical, 12)
                    .submitLabel(.send)
                    .onSubmit { vm.send() }

                Button(action: { vm.send() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            inputIsEmpty ? AuraTheme.textTertiary : .white,
                            inputIsEmpty ? Color.white.opacity(0.08) : Color(red: 0.45, green: 0.75, blue: 1.0)
                        )
                }
                .disabled(inputIsEmpty)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
            .background(
                Capsule(style: .continuous)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
            .animation(.easeInOut(duration: 0.15), value: vm.inputText.isEmpty)
        }
        .background(AuraTheme.bgDeep)
    }

    @ViewBuilder
    private func quickPrompt(_ text: String) -> some View {
        Button(action: {
            vm.inputText = text
            vm.send()
        }) {
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AuraTheme.textSecondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// ────────────────────────────────────────────────────────
// MARK: - TYPING INDICATOR
// ────────────────────────────────────────────────────────

struct TypingIndicator: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { timeline in
            let phase = Int(timeline.date.timeIntervalSince1970 / 0.35) % 3
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(phase == i ? 1.0 : 0.4))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.3 : 0.8)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
