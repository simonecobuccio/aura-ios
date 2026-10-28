import SwiftUI

// ============================================================
// MARK: - DAILY SNAPSHOT (historical health & weather data)
// ============================================================

struct DailySnapshot: Identifiable, Codable {
    let id: UUID
    let date: Date
    let temperature: Double    // °C
    let sleepHours: Double
    let steps: Int
    let uvIndex: Int
    let heartRate: Double      // resting BPM
    let sunriseTime: String    // "HH:mm" format
    let sunsetTime: String     // "HH:mm" format

    init(date: Date, temperature: Double, sleepHours: Double,
         steps: Int, uvIndex: Int, heartRate: Double,
         sunriseTime: String, sunsetTime: String) {
        self.id = UUID()
        self.date = date
        self.temperature = temperature
        self.sleepHours = sleepHours
        self.steps = steps
        self.uvIndex = uvIndex
        self.heartRate = heartRate
        self.sunriseTime = sunriseTime
        self.sunsetTime = sunsetTime
    }

    /// Convenience: daylight window formatted for display ("06:28 – 18:29")
    var sunlightWindow: String { "\(sunriseTime) – \(sunsetTime)" }
}

enum SnapshotHelpers {
    /// Find snapshot for a specific date
    static func snapshot(for date: Date, in snapshots: [DailySnapshot]) -> DailySnapshot? {
        let cal = Calendar.current
        return snapshots.first { cal.isDate($0.date, inSameDayAs: date) }
    }
}
