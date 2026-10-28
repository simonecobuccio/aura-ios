import SwiftUI

// ============================================================

// ============================================================
// MARK: - MOOD CHECK-IN SHEET (max 2/day)
// ============================================================

struct MoodCheckInView: View {
    @Binding var isPresented:  Bool
    @ObservedObject var dataStore: AuraDataStore
    let sunlightHours:         Double

    @State private var selected: Mood

    /// The slot we're filling (nil = both slots used today)
    let currentSlot: MoodSlot?

    init(isPresented: Binding<Bool>,
         dataStore: AuraDataStore,
         sunlightHours: Double,
         lastMood: Mood?) {
        self._isPresented = isPresented
        self.dataStore = dataStore
        self.sunlightHours = sunlightHours
        self._selected = State(initialValue: lastMood ?? .neutral)
        self.currentSlot = MoodHelpers.nextSlot(in: dataStore.moodEntries)
    }

    private var todayCount: Int {
        MoodHelpers.todayCount(in: dataStore.moodEntries)
    }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)

            if let slot = currentSlot {
                // Slot indicator
                HStack(spacing: 6) {
                    Image(systemName: slot.icon)
                        .font(.system(size: 12))
                        .foregroundColor(.yellow.opacity(0.7))
                    Text("\(slot.rawValue) Check-in")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AuraTheme.textSecondary)
                    Text("(\(todayCount)/2 today)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(AuraTheme.textTertiary)
                }

                Text("How are you feeling?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    ForEach(Mood.allCases) { mood in
                        Button(action: { withAnimation(.spring()) { selected = mood } }) {
                            VStack(spacing: 8) {
                                Image(systemName: mood.symbolName)
                                    .font(.system(size: 26))
                                    .foregroundColor(selected == mood
                                                     ? mood.color : .white.opacity(0.35))
                                    .frame(width: 32, height: 32)
                                Text(mood.rawValue)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(selected == mood
                                                     ? AuraTheme.textSecondary
                                                     : AuraTheme.textTertiary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selected == mood
                                          ? Color.white.opacity(0.12) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(selected == mood
                                                    ? Color.white.opacity(0.2) : Color.clear,
                                                    lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: logMood) {
                    Text("Log Mood")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AuraTheme.bgDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white)
                        )
                }
                .padding(.horizontal)

            } else {
                // Both slots used
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0.4, green: 0.92, blue: 0.6))

                    Text("All done for today!")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("You've logged both your morning and evening moods. Come back tomorrow.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AuraTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 36)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AuraTheme.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AuraTheme.glassBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal)
    }

    private func logMood() {
        guard let slot = currentSlot else { return }
        let entry = MoodEntry(mood: selected, sunlightMinutes: sunlightHours * 60, slot: slot)
        dataStore.addMoodEntry(entry)
        withAnimation { isPresented = false }
    }
}
