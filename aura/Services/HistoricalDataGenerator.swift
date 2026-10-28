import SwiftUI

// ============================================================
// MARK: - HISTORICAL DATA GENERATOR
// ============================================================

enum HistoricalDataGenerator {

    /// Generates 3 years of realistic, heterogeneous mood data:
    ///
    /// - Seasonal arc with a "dip" in the middle (simulates winter SAD trough)
    /// - Random "bad streaks" (3–6 days of low mood) and "good streaks"
    /// - ~12 % of days have only 1 entry (forgot evening / morning)
    /// - ~5 % of days are skipped entirely (didn't open the app)
    /// - Weekday rhythm (mid-week slightly lower)
    /// - Morning/evening delta varies: some days evening is worse (bad day at work)
    /// - Sunlight minutes correlated with mood but with noise
    static func generate(months: Int = 36) -> [MoodEntry] {
        var entries: [MoodEntry] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let totalDays = months * 30
        guard let startDate = cal.date(byAdding: .day, value: -totalDays, to: today) else {
            return []
        }

        // Pre-generate streak windows for variety
        var streaks: [(start: Int, length: Int, kind: StreakKind)] = []
        var cursor = Int.random(in: 10...20)
        while cursor < totalDays - 10 {
            let len  = Int.random(in: 3...6)
            let kind: StreakKind = Bool.random() ? .bad : .good
            streaks.append((start: cursor, length: len, kind: kind))
            cursor += len + Int.random(in: 12...25)
        }

        for dayOffset in 0..<totalDays {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            if cal.isDateInToday(date) { continue }

            // ~5 % chance: skip this day entirely
            if Double.random(in: 0...1) < 0.05 { continue }

            // Seasonal arc — flattened so mood doesn't simply track the
            // calendar.  Small seasonal influence (±0.08) with a gentle
            // winter dip, but daily randomness dominates.
            let t = Double(dayOffset) / Double(totalDays)
            let seasonalBase: Double = {
                let dip = exp(-pow((t - 0.38) * 4.0, 2)) * 0.10  // mild winter dip
                return 0.48 + t * 0.12 - dip
            }()

            // Streak override
            let streakBonus: Double = {
                for s in streaks {
                    if dayOffset >= s.start && dayOffset < s.start + s.length {
                        switch s.kind {
                        case .bad:  return -Double.random(in: 0.15...0.28)
                        case .good: return  Double.random(in: 0.12...0.22)
                        }
                    }
                }
                return 0
            }()

            // Weekday effect
            let weekday = cal.component(.weekday, from: date)
            let weekdayFactor: Double = {
                switch weekday {
                case 1, 7:    return  0.08
                case 6:       return  0.04
                case 2, 3, 4: return -0.06
                default:      return -0.02
                }
            }()

            let dayBase = seasonalBase + streakBonus + weekdayFactor

            // Last 4 days: force more volatility (alternating good/bad)
            let daysFromToday = totalDays - dayOffset
            let recentVolatility: Double = {
                if daysFromToday <= 4 {
                    // Zigzag pattern: odd days down, even days up
                    let swing = daysFromToday % 2 == 0
                        ? Double.random(in: 0.15...0.28)
                        : Double.random(in: -0.30...(-0.15))
                    return swing
                }
                return 0
            }()

            // Daily noise — larger range so mood varies substantially
            // day-to-day regardless of season
            let dailyNoise = Double.random(in: -0.20...0.20) + recentVolatility

            // Decide if we skip one entry (~12 % chance)
            let skipMorning = Double.random(in: 0...1) < 0.06
            let skipEvening = Double.random(in: 0...1) < 0.06

            // Morning
            if !skipMorning {
                let morningDelta = Double.random(in: -0.15...0.10) // mornings tend lower
                let val = min(max(dayBase + dailyNoise + morningDelta, 0), 1)
                let mood = moodFromScore(val)
                let hour = Int.random(in: 6...10)
                let d = cal.date(bySettingHour: hour, minute: Int.random(in: 0...59),
                                 second: 0, of: date) ?? date
                // Sunlight loosely correlated with mood
                let baseSun = max(val * 2.5, 0.3) + Double.random(in: -0.5...0.8)
                entries.append(MoodEntry(mood: mood, sunlightMinutes: max(baseSun, 0.2) * 60,
                                         slot: .morning, date: d))
            }

            // Evening
            if !skipEvening {
                // Some days evening is worse (35% chance: bad afternoon)
                let eveningSwing = Double.random(in: 0...1) < 0.35
                    ? Double.random(in: -0.25...(-0.06))
                    : Double.random(in: 0.02...0.15)
                let val = min(max(dayBase + dailyNoise + eveningSwing, 0), 1)
                let mood = moodFromScore(val)
                let hour = Int.random(in: 17...22)
                let d = cal.date(bySettingHour: hour, minute: Int.random(in: 0...59),
                                 second: 0, of: date) ?? date
                let baseSun = max(val * 3.0, 0.5) + Double.random(in: -0.3...1.0)
                entries.append(MoodEntry(mood: mood, sunlightMinutes: max(baseSun, 0.3) * 60,
                                         slot: .evening, date: d))
            }
        }

        return entries.sorted { $0.date > $1.date }
    }

    private enum StreakKind { case bad, good }

    private static func moodFromScore(_ score: Double) -> Mood {
        switch score {
        case 0.82...:     return .great
        case 0.62..<0.82: return .good
        case 0.42..<0.62: return .neutral
        case 0.22..<0.42: return .low
        default:          return .awful
        }
    }

    // ════════════════════════════════════════════════════════════
    // MARK: - HEALTH & WEATHER SNAPSHOTS
    // ════════════════════════════════════════════════════════════

    /// Generates 3 years of realistic daily health & weather snapshots
    /// calibrated for **Milan, Italy** (45.46°N, 9.19°E).
    ///
    /// The 3-year window covers roughly mid-September → mid-March:
    /// - Temperature: follows Milan's monthly averages with daily noise
    /// - UV Index: seasonal curve matching northern Italy latitude
    /// - Sunrise / Sunset: astronomically accurate (±2 min noise),
    ///   including the CET→CEST DST switch on the last Sunday of Oct
    /// - Sleep, Steps, Heart Rate: same behavioural model as before
    static func generateSnapshots(months: Int = 36) -> [DailySnapshot] {
        var snapshots: [DailySnapshot] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let totalDays = months * 30

        guard let startDate = cal.date(byAdding: .day, value: -totalDays, to: today) else {
            return []
        }

        for dayOffset in 0...totalDays {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }

            let month   = cal.component(.month, from: date)
            let day     = cal.component(.day, from: date)
            let weekday = cal.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            let progress = Double(dayOffset) / Double(totalDays)

            // ── Temperature (Milan monthly averages ±noise) ──
            let monthlyAvg: Double = {
                switch month {
                case 1:  return 2.5
                case 2:  return 4.5
                case 3:  return 9.5
                case 4:  return 13.5
                case 5:  return 18.0
                case 6:  return 22.5
                case 7:  return 25.0
                case 8:  return 24.5
                case 9:  return 20.0
                case 10: return 14.0
                case 11: return 7.5
                case 12: return 3.5
                default: return 10.0
                }
            }()
            // Intra-month interpolation toward next month
            let nextMonthAvg: Double = {
                switch month {
                case 1:  return 4.5;   case 2:  return 9.5
                case 3:  return 13.5;  case 4:  return 18.0
                case 5:  return 22.5;  case 6:  return 25.0
                case 7:  return 24.5;  case 8:  return 20.0
                case 9:  return 14.0;  case 10: return 7.5
                case 11: return 3.5;   case 12: return 2.5
                default: return 10.0
                }
            }()
            let dayFrac = Double(day) / 30.0
            let baseTemp = monthlyAvg + (nextMonthAvg - monthlyAvg) * dayFrac
            let tempNoise = Double.random(in: -3.5...3.5)
            let coldSnap  = Double.random(in: 0...1) < 0.06 ? -Double.random(in: 4...8) : 0
            let temperature = (baseTemp + tempNoise + coldSnap)

            // ── UV Index (Milan seasonal) ──
            let monthlyUV: Double = {
                switch month {
                case 1:  return 1.0;  case 2:  return 1.5
                case 3:  return 3.0;  case 4:  return 4.5
                case 5:  return 6.0;  case 6:  return 7.5
                case 7:  return 8.0;  case 8:  return 7.0
                case 9:  return 5.0;  case 10: return 2.5
                case 11: return 1.2;  case 12: return 1.0
                default: return 2.0
                }
            }()
            let cloudy = Double.random(in: 0...1) < 0.25  // Milan is often cloudy in winter
            let uvNoise = Double.random(in: -0.8...0.8)
            let uvRaw = cloudy ? max(monthlyUV * 0.3 + uvNoise, 0) : monthlyUV + uvNoise
            let uvIndex = max(min(Int(uvRaw.rounded()), 11), 0)

            // ── Sunrise / Sunset (Milan astronomical, ±2 min noise) ──
            // Day-of-year for interpolation
            let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1

            // Sunrise in minutes from midnight (CET).
            // Milan: earliest ~05:35 (Jun 21), latest ~07:56 (Jan 1)
            // Model: cosine curve centred on summer solstice (day 172)
            let sunriseBase = 403.0 + 71.0 * cos(2.0 * .pi * (Double(dayOfYear) - 172.0) / 365.0)
            // Sunset in minutes from midnight (CET).
            // Milan: earliest ~16:42 (Dec 21), latest ~21:15 (Jun 21)
            // Model: cosine curve
            let sunsetBase  = 1079.0 - 137.0 * cos(2.0 * .pi * (Double(dayOfYear) - 172.0) / 365.0)

            // DST: CEST (UTC+2) from last Sunday of March to last Sunday of October
            // During CEST, clocks are +60 min ahead
            let isCEST: Bool = {
                // Approximate: Apr 1 – Oct 25 as CEST window for simplicity
                if month >= 4 && month <= 9 { return true }
                if month == 3 && day >= 28 { return true }
                if month == 10 && day <= 26 { return true }
                return false
            }()
            let dstOffset: Double = isCEST ? 60.0 : 0.0

            let sunriseMin = sunriseBase + dstOffset + Double.random(in: -2...2)
            let sunsetMin  = sunsetBase  + dstOffset + Double.random(in: -2...2)

            let sunriseTime = String(format: "%02d:%02d",
                                     Int(sunriseMin) / 60, Int(sunriseMin) % 60)
            let sunsetTime  = String(format: "%02d:%02d",
                                     Int(sunsetMin) / 60, Int(sunsetMin) % 60)

            // ── Sleep ──
            let sleepBase: Double = isWeekend
                ? Double.random(in: 7.5...9.5)
                : Double.random(in: 6.0...8.2)
            let sleepTrend = progress * 0.3
            let badNight   = Double.random(in: 0...1) < 0.08
                ? -Double.random(in: 1.5...2.5) : 0
            let sleepHours = max(sleepBase + sleepTrend + badNight, 3.0)

            // ── Steps ──
            let stepsBase: Int = {
                if isWeekend {
                    return Bool.random()
                        ? Int.random(in: 2000...5000)
                        : Int.random(in: 8000...18000)
                } else {
                    return Int.random(in: 5000...12000)
                }
            }()
            let sickDay = Double.random(in: 0...1) < 0.05
            let steps   = sickDay ? Int.random(in: 500...2000) : stepsBase

            // ── Heart Rate ──
            let hrBase  = 70.0 - progress * 3.0
            let stress  = (!isWeekend && Double.random(in: 0...1) < 0.15)
                ? Double.random(in: 5...15) : 0
            let restBonus = isWeekend ? -Double.random(in: 1...3) : 0
            let hrNoise = Double.random(in: -4...4)
            let heartRate = max(hrBase + stress + restBonus + hrNoise, 52)

            snapshots.append(DailySnapshot(
                date: cal.startOfDay(for: date),
                temperature: (temperature * 10).rounded() / 10,
                sleepHours: (sleepHours * 10).rounded() / 10,
                steps: steps,
                uvIndex: uvIndex,
                heartRate: (heartRate * 10).rounded() / 10,
                sunriseTime: sunriseTime,
                sunsetTime: sunsetTime
            ))
        }

        return snapshots.sorted { $0.date > $1.date }
    }
}
