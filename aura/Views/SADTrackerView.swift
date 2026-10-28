import SwiftUI

// ============================================================
// MARK: - SAD TRACKER VIEW
// ============================================================

struct SADTrackerView: View {
    let sunlightHours: Double
    let sunriseTime:   String
    let sunsetTime:    String
    let moodEntries: [MoodEntry]

    private let recommended: Double = 2.0
    var sunlightProgress: Double { min(sunlightHours / recommended, 1.0) }

    /// 0 = sunrise, 1 = sunset, based on current clock time
    private var dayProgress: Double {
        // Try 12-hour format first ("07:18 AM"), then 24-hour ("07:18")
        var rise = AuraFormatters.time12h.date(from: sunriseTime)
        var set  = AuraFormatters.time12h.date(from: sunsetTime)

        if rise == nil || set == nil {
            rise = AuraFormatters.time24h.date(from: sunriseTime)
            set  = AuraFormatters.time24h.date(from: sunsetTime)
        }

        guard let r = rise, let s = set else { return 0.5 }

        let cal = Calendar.current
        let riseMin = Double(cal.component(.hour, from: r) * 60 + cal.component(.minute, from: r))
        let setMin  = Double(cal.component(.hour, from: s) * 60 + cal.component(.minute, from: s))
        let nowMin  = Double(cal.component(.hour, from: Date()) * 60 + cal.component(.minute, from: Date()))

        let range = setMin - riseMin
        guard range > 0 else { return 0.5 }
        return min(max((nowMin - riseMin) / range, 0), 1)
    }

    @State private var animatedProgress: Double = 0

    /// Current time as "HH:mm"
    private var currentTimeLabel: String {
        AuraFormatters.time24h.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            SectionHeader(title: "Daylight & Mood")

            VStack(spacing: 0) {

                // ── Header row ──
                HStack {
                    Text("TODAY'S DAYLIGHT WINDOW")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AuraTheme.textTertiary)
                        .tracking(1.2)
                    Spacer()
                    Text(String(format: "%.0fh", sunlightHours))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 10)

                // ── Sun Arc ──
                // A single SunArcCanvas draws curve, dot, glow, and time
                // label in ONE render pass from ONE progress value —
                // eliminating any possible desync between Shape and ViewModifier.
                SunArcCanvas(
                    progress: animatedProgress,
                    timeLabel: currentTimeLabel
                )
                .frame(height: 80)
                .padding(.top, 4)

                // ── Sunrise / Sunset: time on top, icon below ──
                HStack {
                    VStack(spacing: 3) {
                        Text(sunriseTime)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.3).opacity(0.7))
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.3).opacity(0.45))
                    }
                    Spacer()
                    VStack(spacing: 3) {
                        Text(sunsetTime)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange.opacity(0.7))
                        Image(systemName: "sunset.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.orange.opacity(0.45))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 6)

                if sunlightHours < 2 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text("Low daylight — try a walk outside")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.orange.opacity(0.75))
                    .padding(.top, 12)
                }
            }
            .padding(16)
            .glassCard()
            .onAppear {
                // Play the arc animation on first render
                animatedProgress = 0
                withAnimation(.easeOut(duration: 1.4)) {
                    animatedProgress = dayProgress
                }
            }
            .onChange(of: sunlightHours) { _, _ in
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedProgress = dayProgress
                }
            }

            if !moodEntries.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("RECENT MOOD LOG")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AuraTheme.textTertiary)
                        .tracking(1.2)

                    ForEach(moodEntries.prefix(5)) { entry in
                        HStack(spacing: 14) {
                            Image(systemName: entry.mood.symbolName)
                                .font(.system(size: 20))
                                .foregroundColor(entry.mood.color)
                                .frame(width: 26, height: 26)

                            Text(entry.mood.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)

                            Spacer()

                            // Time + sunrise/sunset icon on the right
                            HStack(spacing: 5) {
                                Text(AuraFormatters.timeShort.string(from: entry.date))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(AuraTheme.textSecondary)

                                Image(systemName: entry.slot == .morning ? "sunrise.fill" : "sunset.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(entry.slot == .morning
                                        ? Color(red: 1.0, green: 0.85, blue: 0.20)    // yellow sunrise
                                        : Color(red: 1.0, green: 0.55, blue: 0.20))   // orange sunset
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
                .padding(16)
                .glassCard()
            }
        }
        .padding(.horizontal)
    }
}
