import SwiftUI

// ============================================================
// MARK: - MOOD CALENDAR VIEW
// ============================================================

struct MoodCalendarView: View {
    @ObservedObject var dataStore: AuraDataStore

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date? = nil

    // Only the day grid needs local caching
    @State private var cachedDays: [Date?] = []

    // Cached detail data — rebuilt only when selectedDate changes
    @State private var cachedDayEntries: [MoodEntry] = []
    @State private var cachedDaySnapshot: DailySnapshot? = nil

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            SectionHeader(title: "Mood Calendar")

            VStack(spacing: 14) {
                // Month navigation
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isAtEarliestMonth
                                             ? AuraTheme.textTertiary
                                             : AuraTheme.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .disabled(isAtEarliestMonth)

                    Spacer()

                    Text(monthYearString)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(
                                calendar.isDate(displayedMonth, equalTo: Date(),
                                                toGranularity: .month)
                                ? AuraTheme.textTertiary
                                : AuraTheme.textSecondary
                            )
                            .frame(width: 36, height: 36)
                    }
                    .disabled(calendar.isDate(displayedMonth, equalTo: Date(),
                                              toGranularity: .month))
                }

                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol.prefix(2).uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(AuraTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Day grid (cached — only rebuilt when month changes)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                          spacing: 6) {
                    ForEach(cachedDays, id: \.self) { date in
                        if let date = date {
                            dayCell(for: date)
                        } else {
                            Color.clear.frame(height: 38)
                        }
                    }
                }

                // Selected day detail
                if let sel = selectedDate,
                   (!cachedDayEntries.isEmpty || cachedDaySnapshot != nil) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(AuraFormatters.dateLong.string(from: sel))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(AuraTheme.textSecondary)

                        // Mood entries
                        if !cachedDayEntries.isEmpty {
                            ForEach(cachedDayEntries) { entry in
                                HStack(spacing: 12) {
                                    Image(systemName: entry.slot.icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(.yellow.opacity(0.6))
                                        .frame(width: 18)

                                    Image(systemName: entry.mood.symbolName)
                                        .font(.system(size: 16))
                                        .foregroundColor(entry.mood.color)
                                        .frame(width: 22)

                                    Text(entry.mood.rawValue)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Text(AuraFormatters.timeShort.string(from: entry.date))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(AuraTheme.textTertiary)
                                }
                            }
                        }

                        // Health & Weather snapshot
                        if let snap = cachedDaySnapshot {
                            Rectangle()
                                .fill(AuraTheme.glassBorder)
                                .frame(height: 0.5)
                                .padding(.vertical, 4)

                            // Row 1: Temp, Sleep, Steps
                            HStack(spacing: 0) {
                                snapshotStat(icon: "thermometer.medium",
                                             value: String(format: "%.0f°C", snap.temperature),
                                             label: "Temp")
                                snapshotStat(icon: "bed.double.fill",
                                             value: String(format: "%.1fh", snap.sleepHours),
                                             label: "Sleep")
                                snapshotStat(icon: "figure.walk",
                                             value: snap.steps.formatted(),
                                             label: "Steps")
                            }

                            // Row 2: UV, Heart Rate, Sunlight window
                            HStack(spacing: 0) {
                                snapshotStat(icon: "sun.max.fill",
                                             value: "\(snap.uvIndex)",
                                             label: "UV")
                                snapshotStat(icon: "heart.fill",
                                             value: String(format: "%.0f bpm", snap.heartRate),
                                             label: "Heart Rate")
                                snapshotStat(icon: "sun.and.horizon",
                                             value: snap.sunlightWindow,
                                             label: "Daylight")
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AuraTheme.glassBorder, lineWidth: 0.5)
                            )
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .glassCard()
        }
        .padding(.horizontal)
        .animation(.spring(duration: 0.3), value: selectedDate)
        .animation(.easeInOut(duration: 0.25), value: displayedMonth)
        .onAppear { cachedDays = daysInMonth() }
        .onChange(of: displayedMonth)     { _, _ in cachedDays = daysInMonth() }
        .onChange(of: selectedDate) { _, newDate in rebuildSelectedDayCache(for: newDate) }
    }

    // MARK: - Selected day cache (avoids O(n) scans in body)

    private func rebuildSelectedDayCache(for date: Date?) {
        guard let date = date else {
            cachedDayEntries = []
            cachedDaySnapshot = nil
            return
        }
        cachedDayEntries = dataStore.moodEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
        cachedDaySnapshot = SnapshotHelpers.snapshot(for: date, in: dataStore.snapshots)
    }

    // MARK: - Day cell (O(1) lookups via dataStore)

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let dayKey = AuraFormatters.dayKey.string(from: date)
        let dominantMood = dataStore.moodByDay[dayKey]              // O(1) dictionary lookup
        let hasSnapshot = dataStore.snapshotDays.contains(dayKey)   // O(1) set lookup
        let hasData = dominantMood != nil || hasSnapshot

        Button(action: {
            if !isFuture && hasData {
                withAnimation(.spring(duration: 0.25)) {
                    if isSelected { selectedDate = nil }
                    else { selectedDate = date }
                }
            }
        }) {
            VStack(spacing: 2) {
                if let mood = dominantMood {
                    Image(systemName: mood.symbolName)
                        .font(.system(size: 14))
                        .foregroundColor(mood.color)
                } else if hasSnapshot {
                    // Day has health data but no mood — show a dot
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AuraTheme.textSecondary)
                } else {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(isFuture
                                         ? AuraTheme.textTertiary.opacity(0.4)
                                         : AuraTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected ? Color.white.opacity(0.12)
                        : isToday  ? Color.white.opacity(0.06)
                        : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isToday ? Color.white.opacity(0.15) : Color.clear,
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture || !hasData)
    }

    // MARK: - Snapshot stat mini-cell

    @ViewBuilder
    private func snapshotStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AuraTheme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(AuraTheme.textTertiary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var isAtEarliestMonth: Bool {
        guard let threeYearsAgo = calendar.date(byAdding: .month, value: -36, to: Date()) else {
            return false
        }
        return calendar.isDate(displayedMonth, equalTo: threeYearsAgo, toGranularity: .month)
    }

    private var monthYearString: String {
        AuraFormatters.monthYear.string(from: displayedMonth)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            let threeYearsAgo = calendar.date(byAdding: .month, value: -36, to: Date()) ?? Date()
            // Stay within 3 years ago … current month
            if newMonth <= Date() && newMonth >= threeYearsAgo {
                displayedMonth = newMonth
                selectedDate = nil
            }
        }
    }

    /// Returns an array of optional Dates for the calendar grid.
    /// nil entries are padding for the first week.
    private func daysInMonth() -> [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let padding = firstWeekday - calendar.firstWeekday
        let paddingCount = (padding + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: paddingCount)

        for day in range {
            var dc = comps
            dc.day = day
            days.append(calendar.date(from: dc))
        }

        return days
    }
}
