import SwiftUI

struct AuraScore {

    // ── Raw inputs ──
    var sleepScore: Double      // 0–1  from HealthViewModel
    var stepsScore: Double      // 0–1  from HealthViewModel
    var uvScore: Double         // 0–1  from WeatherViewModel
    var moodScore: Double       // 0–1  latest mood entry
    var sunlightHours: Double = 0   // raw hours today
    var heartRate: Double = 0       // latest resting BPM (0 = unknown)
    var recentMoods: [Double] = []  // last ≤5 mood scores, newest first
    var currentHour: Int = {
        Calendar.current.component(.hour, from: Date())
    }()

    // ════════════════════════════════════════════════════════════
    // MARK: - COMPOSITE
    // ════════════════════════════════════════════════════════════

    /// A thoughtful composite that mirrors how well-being actually works:
    ///
    /// 1. **Circadian dynamic weights** – what matters shifts during the day.
    ///    Morning: activity & sunlight. Afternoon: mood & UV. Evening: sleep.
    /// 2. **Diminishing returns (power 0.6)** – first improvements
    ///    are the most valuable; perfectionism has lower payoff.
    /// 3. **Sleep–mood coupling** – both low amplify each other (SAD).
    /// 4. **Mood trend** – improving trajectory earns a bonus.
    /// 5. **Sunlight curve** – continuous benefit, plateaus around 2 h.
    /// 6. **Heart-rate stress signal** – high resting HR hints at stress.
    /// 7. **Synergy & imbalance** – balance is rewarded, gaps penalised.
    ///
    var composite: Double {

        // 1. Circadian weight sets
        let w = circadianWeights

        // 2. Curved sub-scores (power 0.6 = softer than sqrt)
        let s = pow(sleepScore,  0.6)
        let a = pow(stepsScore,  0.6)
        let u = pow(uvScore,     0.6)
        let m = pow(moodScore,   0.6)

        // 3. Weighted base
        var base = (s * w.sleep) + (a * w.activity) + (u * w.sunlight) + (m * w.mood)

        // 4. Sleep–mood SAD coupling: both below 0.4 → penalty up to −0.06
        if sleepScore < 0.4 && moodScore < 0.4 {
            let severity = (0.4 - sleepScore) * (0.4 - moodScore)
            base -= severity * 0.38
        }

        // 5. Mood trend bonus (−0.04 … +0.05)
        base += moodTrendBonus

        // 6. Sunlight curve (log, plateaus ~2 h)
        if sunlightHours > 0 {
            base += min(log(1 + sunlightHours) / log(3.0), 1.0) * 0.05
        }

        // 7. Heart-rate stress signal
        if heartRate > 85 {
            let excess = min((heartRate - 85) / 35.0, 1.0)
            base -= excess * 0.04
        }

        // 8. Synergy bonus
        let pillars = [sleepScore, stepsScore, uvScore, moodScore]
        let strong  = pillars.filter { $0 >= 0.6 }.count
        if strong >= 3 { base += Double(strong - 2) * 0.03 }

        // 9. Imbalance penalty
        let avg     = pillars.reduce(0, +) / 4.0
        let weakest = pillars.min() ?? 0
        if avg - weakest > 0.30 {
            base -= (avg - weakest - 0.30) * 0.12
        }

        return min(max(base, 0), 1)
    }

    // ════════════════════════════════════════════════════════════
    // MARK: - CIRCADIAN WEIGHTS
    // ════════════════════════════════════════════════════════════

    private struct Weights {
        let sleep: Double; let activity: Double
        let sunlight: Double; let mood: Double
    }

    /// Weights shift through the day so the score reflects
    /// what is most actionable right now.
    private var circadianWeights: Weights {
        switch currentHour {
        case 5..<10:   return Weights(sleep: 0.35, activity: 0.28, sunlight: 0.17, mood: 0.20)
        case 10..<14:  return Weights(sleep: 0.22, activity: 0.28, sunlight: 0.28, mood: 0.22)
        case 14..<18:  return Weights(sleep: 0.22, activity: 0.22, sunlight: 0.22, mood: 0.34)
        case 18..<22:  return Weights(sleep: 0.34, activity: 0.18, sunlight: 0.14, mood: 0.34)
        default:       return Weights(sleep: 0.42, activity: 0.12, sunlight: 0.10, mood: 0.36)
        }
    }

    // ════════════════════════════════════════════════════════════
    // MARK: - MOOD TREND
    // ════════════════════════════════════════════════════════════

    /// Weighted slope of last ≤5 moods. Returns −0.04 … +0.05.
    private var moodTrendBonus: Double {
        guard recentMoods.count >= 2 else { return 0 }
        let entries = Array(recentMoods.prefix(5))
        var weightedDelta = 0.0, totalWeight = 0.0
        for i in 0..<(entries.count - 1) {
            let w = Double(entries.count - i)
            weightedDelta += (entries[i] - entries[i + 1]) * w
            totalWeight   += w
        }
        let slope = weightedDelta / totalWeight
        return slope > 0
            ? min(slope * 0.10, 0.05)
            : max(slope * 0.08, -0.04)
    }

    // ════════════════════════════════════════════════════════════
    // MARK: - BREAKDOWN
    // ════════════════════════════════════════════════════════════

    struct Pillar: Identifiable {
        var id: String { name }
        let name: String
        let icon: String
        let raw: Double
        let weight: Double
        let weighted: Double
    }

    var breakdown: [Pillar] {
        let w = circadianWeights
        return [
            Pillar(name: "Sleep",    icon: "bed.double.fill",
                   raw: sleepScore,  weight: w.sleep,
                   weighted: pow(sleepScore, 0.6) * w.sleep),
            Pillar(name: "Activity", icon: "figure.walk",
                   raw: stepsScore,  weight: w.activity,
                   weighted: pow(stepsScore, 0.6) * w.activity),
            Pillar(name: "Daylight", icon: "sun.max.fill",
                   raw: uvScore,     weight: w.sunlight,
                   weighted: pow(uvScore, 0.6) * w.sunlight),
            Pillar(name: "Mood",     icon: "heart.circle.fill",
                   raw: moodScore,   weight: w.mood,
                   weighted: pow(moodScore, 0.6) * w.mood),
        ]
    }

    /// Short text explaining the weakest pillar.
    var insight: String {
        guard let weakest = breakdown.min(by: { $0.raw < $1.raw }) else { return "" }
        if weakest.raw >= 0.6 { return "All pillars look solid — keep it up." }
        switch weakest.name {
        case "Sleep":    return "Sleep is your bottleneck today."
        case "Activity": return "A short walk could lift your score."
        case "Daylight": return "Try getting some outdoor light."
        case "Mood":
            return moodTrendBonus > 0.02
                ? "Mood is low but trending upward."
                : "Your mood is pulling the score down."
        default: return ""
        }
    }

    // ════════════════════════════════════════════════════════════
    // MARK: - DISPLAY
    // ════════════════════════════════════════════════════════════

    var color: Color {
        switch composite {
        case 0.78...:     return Color(red: 0.35, green: 0.78, blue: 1.0)
        case 0.60..<0.78: return Color(red: 0.4,  green: 0.92, blue: 0.6)
        case 0.40..<0.60: return Color(red: 1.0,  green: 0.78, blue: 0.28)
        default:          return Color(red: 1.0,   green: 0.42, blue: 0.32)
        }
    }

    var secondaryColor: Color {
        switch composite {
        case 0.78...:     return Color(red: 0.25, green: 0.45, blue: 0.85)
        case 0.60..<0.78: return Color(red: 0.2,  green: 0.55, blue: 0.45)
        case 0.40..<0.60: return Color(red: 0.65, green: 0.40, blue: 0.15)
        default:          return Color(red: 0.60,  green: 0.20, blue: 0.25)
        }
    }

    var label: String {
        switch composite {
        case 0.82...:     return "Radiant"
        case 0.68..<0.82: return "Thriving"
        case 0.52..<0.68: return "Balanced"
        case 0.36..<0.52: return "Drained"
        default:          return "Low Energy"
        }
    }
}
