import SwiftUI

// ============================================================
// MARK: - MODELS
// ============================================================

enum Mood: String, CaseIterable, Identifiable, Codable {
    case great   = "Great"
    case good    = "Good"
    case neutral = "Neutral"
    case low     = "Low"
    case awful   = "Awful"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .great:   return "heart.circle.fill"        // love it
        case .good:    return "hand.thumbsup.fill"       // thumbs up
        case .neutral: return "minus.circle.fill"        // meh
        case .low:     return "hand.thumbsdown.fill"     // thumbs down
        case .awful:   return "xmark.circle.fill"        // nope
        }
    }

    var score: Double {
        switch self {
        case .great:   return 1.0
        case .good:    return 0.75
        case .neutral: return 0.5
        case .low:     return 0.25
        case .awful:   return 0.0
        }
    }

    var color: Color {
        switch self {
        case .great:   return Color(red: 0.30, green: 0.90, blue: 0.50) // vibrant green
        case .good:    return Color(red: 0.40, green: 0.75, blue: 1.0)  // sky blue
        case .neutral: return Color(red: 0.62, green: 0.65, blue: 0.72) // cool grey
        case .low:     return Color(red: 1.0,  green: 0.72, blue: 0.28) // amber
        case .awful:   return Color(red: 1.0,  green: 0.38, blue: 0.32) // red
        }
    }
}

enum MoodSlot: String, Codable {
    case morning  = "Morning"
    case evening  = "Evening"

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .evening: return "sunset.fill"
        }
    }
}

struct MoodEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mood: Mood
    let sunlightMinutes: Double
    let slot: MoodSlot

    init(mood: Mood, sunlightMinutes: Double, slot: MoodSlot) {
        self.id = UUID()
        self.date = Date()
        self.mood = mood
        self.sunlightMinutes = sunlightMinutes
        self.slot = slot
    }

    /// For historical data generation
    init(mood: Mood, sunlightMinutes: Double, slot: MoodSlot, date: Date) {
        self.id = UUID()
        self.date = date
        self.mood = mood
        self.sunlightMinutes = sunlightMinutes
        self.slot = slot
    }
}

// ============================================================
// MARK: - MOOD HELPERS
// ============================================================

enum MoodHelpers {

    /// How many moods logged today
    static func todayCount(in entries: [MoodEntry]) -> Int {
        let cal = Calendar.current
        return entries.filter { cal.isDateInToday($0.date) }.count
    }

    /// Which slots are already used today
    static func usedSlotsToday(in entries: [MoodEntry]) -> Set<MoodSlot> {
        let cal = Calendar.current
        return Set(entries.filter { cal.isDateInToday($0.date) }.map(\.slot))
    }

    /// Next available slot, or nil if both filled
    static func nextSlot(in entries: [MoodEntry]) -> MoodSlot? {
        let used = usedSlotsToday(in: entries)
        let hour = Calendar.current.component(.hour, from: Date())

        if used.count >= 2 { return nil }

        // Before 14:00 → prefer morning; after → prefer evening
        if hour < 14 {
            return used.contains(.morning) ? .evening : .morning
        } else {
            return used.contains(.evening) ? .morning : .evening
        }
    }

    /// Dominant mood for a given date (average of that day's entries)
    static func dominantMood(for date: Date, in entries: [MoodEntry]) -> Mood? {
        let cal = Calendar.current
        let dayEntries = entries.filter { cal.isDate($0.date, inSameDayAs: date) }
        guard !dayEntries.isEmpty else { return nil }
        let avg = dayEntries.map(\.mood.score).reduce(0, +) / Double(dayEntries.count)
        // Map average back to nearest mood
        return Mood.allCases.min(by: { abs($0.score - avg) < abs($1.score - avg) })
    }
}
