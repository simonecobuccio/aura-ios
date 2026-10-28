import SwiftUI
import Combine

@MainActor
final class AuraDataStore: ObservableObject {

    @Published var moodEntries: [MoodEntry] = []
    @Published var snapshots: [DailySnapshot] = []
    @Published var isLoading: Bool = true

    /// Pre-computed lookup: "yyyy-MM-dd" → dominant Mood
    @Published var moodByDay: [String: Mood] = [:]
    /// Pre-computed lookup: "yyyy-MM-dd" → true
    @Published var snapshotDays: Set<String> = []

    /// Pre-sorted caches for chart aggregation (ascending by date).
    /// Built once on load and maintained incrementally — eliminates
    /// O(n log n) re-sorts every time TrendChartsView renders.
    var sortedMoods: [MoodEntry] = []
    var sortedSnaps: [DailySnapshot] = []

    /// Monotonic version counter — bumped on every data mutation.
    /// Views can `.onChange(of: dataVersion)` instead of diffing arrays.
    @Published var dataVersion: UInt = 0

    private var hasLoaded = false
    private(set) var currentEmail: String = ""

    var moodStorageKey: String {
        "aura.moodEntries.v3.\(currentEmail)"
    }
    var snapshotStorageKey: String {
        "aura.snapshots.v3.\(currentEmail)"
    }

    func loadIfNeeded(email: String) {
        guard !hasLoaded else { return }
        hasLoaded = true
        currentEmail = email.lowercased()

        let mKey = moodStorageKey
        let sKey = snapshotStorageKey
        let isDemo = currentEmail == "demo@aura.app"

        // Attempt fast decode from UserDefaults first
        let existingMood: [MoodEntry]? = {
            guard let data = UserDefaults.standard.data(forKey: mKey),
                  let decoded = try? JSONDecoder().decode([MoodEntry].self, from: data),
                  !decoded.isEmpty else { return nil }
            return decoded
        }()

        let existingSnaps: [DailySnapshot]? = {
            guard let data = UserDefaults.standard.data(forKey: sKey),
                  let decoded = try? JSONDecoder().decode([DailySnapshot].self, from: data),
                  !decoded.isEmpty else { return nil }
            return decoded
        }()

        if let m = existingMood {
            self.moodEntries = m
            self.sortedMoods = m.sorted { $0.date < $1.date }
            self.rebuildMoodLookup(m)
        }
        if let s = existingSnaps {
            self.snapshots = s
            self.sortedSnaps = s.sorted { $0.date < $1.date }
            self.rebuildSnapshotLookup(s)
        }

        let needsMoodGen = existingMood == nil && isDemo
        let needsSnapGen = existingSnaps == nil && isDemo

        if needsMoodGen || needsSnapGen {
            // Default actor isolation is MainActor, so generation runs on the main
            // actor; it only happens once (first demo launch) and is fast.
            Task {
                let moods = needsMoodGen ? HistoricalDataGenerator.generate(months: 36) : []
                let snaps = needsSnapGen ? HistoricalDataGenerator.generateSnapshots(months: 36) : []

                let moodData = needsMoodGen ? try? JSONEncoder().encode(moods) : nil
                let snapData = needsSnapGen ? try? JSONEncoder().encode(snaps) : nil
                let sortedM  = needsMoodGen ? moods.sorted { $0.date < $1.date } : []
                let sortedS  = needsSnapGen ? snaps.sorted { $0.date < $1.date } : []

                await MainActor.run {
                    if needsMoodGen {
                        self.moodEntries = moods
                        self.sortedMoods = sortedM
                        self.rebuildMoodLookup(moods)
                        if let d = moodData { UserDefaults.standard.set(d, forKey: mKey) }
                    }
                    if needsSnapGen {
                        self.snapshots = snaps
                        self.sortedSnaps = sortedS
                        self.rebuildSnapshotLookup(snaps)
                        if let d = snapData { UserDefaults.standard.set(d, forKey: sKey) }
                    }
                    self.dataVersion &+= 1
                    self.isLoading = false
                }
            }
        } else {
            dataVersion &+= 1
            isLoading = false
        }
    }

    func addMoodEntry(_ entry: MoodEntry) {
        moodEntries.insert(entry, at: 0)

        // Maintain sorted cache incrementally (binary-insert)
        if let idx = sortedMoods.firstIndex(where: { $0.date > entry.date }) {
            sortedMoods.insert(entry, at: idx)
        } else {
            sortedMoods.append(entry)
        }

        // Update day lookup
        let key = AuraFormatters.dayKey.string(from: entry.date)
        let cal = Calendar.current
        let dayEntries = moodEntries.filter { cal.isDate($0.date, inSameDayAs: entry.date) }
        let avg = dayEntries.map(\.mood.score).reduce(0, +) / Double(dayEntries.count)
        moodByDay[key] = Mood.allCases.min(by: { abs($0.score - avg) < abs($1.score - avg) })

        dataVersion &+= 1

        // Save on background
        let entries = moodEntries
        let storageKey = moodStorageKey
        Task.detached(priority: .utility) {
            if let encoded = try? JSONEncoder().encode(entries) {
                await MainActor.run {
                    UserDefaults.standard.set(encoded, forKey: storageKey)
                }
            }
        }
    }

    func rebuildMoodLookup(_ entries: [MoodEntry]) {
        var grouped: [String: [Double]] = [:]
        for entry in entries {
            let key = AuraFormatters.dayKey.string(from: entry.date)
            grouped[key, default: []].append(entry.mood.score)
        }
        var result: [String: Mood] = [:]
        for (key, scores) in grouped {
            let avg = scores.reduce(0, +) / Double(scores.count)
            result[key] = Mood.allCases.min(by: { abs($0.score - avg) < abs($1.score - avg) })
        }
        moodByDay = result
    }

    func rebuildSnapshotLookup(_ snaps: [DailySnapshot]) {
        snapshotDays = Set(snaps.map { AuraFormatters.dayKey.string(from: $0.date) })
    }

    /// Reset for logout / account switch
    func reset() {
        hasLoaded = false
        moodEntries = []
        snapshots = []
        sortedMoods = []
        sortedSnaps = []
        moodByDay = [:]
        snapshotDays = []
        dataVersion &+= 1
        isLoading = true
        currentEmail = ""
    }
}
