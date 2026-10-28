import SwiftUI

// ============================================================
// MARK: - TREND CHARTS VIEW (unlocked with Plus)
// ============================================================

struct TrendChartsView: View {
    @ObservedObject var dataStore: AuraDataStore
    var chartHeight: CGFloat = 140

    enum TimePeriod: String, CaseIterable {
        case week  = "W"
        case month = "M"
        case year  = "Y"

        var label: String {
            switch self {
            case .week:  return "Weekly"
            case .month: return "Monthly"
            case .year:  return "Yearly"
            }
        }
    }

    @State private var selectedChart: Int = 0
    @State private var selectedIndex: Int? = nil
    @State private var selectedPeriod: TimePeriod = .week
    private let chartTitles = ["Mood", "Sleep", "Steps", "Heart Rate"]

    // ── Pre-computed aggregations for ALL periods — switching W/M/Y is a free lookup ──
    private struct AllAgg {
        var mood:  [(label: String, value: Double)] = []
        var sleep: [(label: String, value: Double)] = []
        var steps: [(label: String, value: Double)] = []
        var hr:    [(label: String, value: Double)] = []
    }
    @State private var aggByPeriod: [TimePeriod: AllAgg] = [:]
    @State private var lastDataVersion: UInt = 0

    /// Fast O(1) lookup — no recomputation on period switch
    private var cachedMoodAgg:  [(label: String, value: Double)] { aggByPeriod[selectedPeriod]?.mood  ?? [] }
    private var cachedSleepAgg: [(label: String, value: Double)] { aggByPeriod[selectedPeriod]?.sleep ?? [] }
    private var cachedStepsAgg: [(label: String, value: Double)] { aggByPeriod[selectedPeriod]?.steps ?? [] }
    private var cachedHRAgg:    [(label: String, value: Double)] { aggByPeriod[selectedPeriod]?.hr    ?? [] }

    @Namespace private var chartNS
    @Namespace private var periodNS

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            HStack {
                SectionHeader(title: "Trend Analysis")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("PLUS")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1)
                }
                .foregroundColor(Color(red: 0.45, green: 0.75, blue: 1.0))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.15))
                )
            }

            // ── Chart type selector ──
            HStack(spacing: 4) {
                ForEach(Array(chartTitles.enumerated()), id: \.offset) { i, title in
                    Button {
                        selectedChart = i
                        selectedIndex = nil
                    } label: {
                        Text(title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(selectedChart == i ? .white : AuraTheme.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if selectedChart == i {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                        .matchedGeometryEffect(id: "chartPill", in: chartNS)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(AuraPressStyle())
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: selectedChart)

            // ── Period selector (W / M / Y) ──
            // State changes are INSTANT (no withAnimation wrapper) so
            // taps are never swallowed.  The sliding pill animates via
            // matchedGeometryEffect independently, and charts re-animate
            // via their own playEntrance().
            HStack(spacing: 0) {
                ForEach(TimePeriod.allCases, id: \.rawValue) { period in
                    Button {
                        selectedPeriod = period
                        selectedIndex = nil
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(selectedPeriod == period ? .white : AuraTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if selectedPeriod == period {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.14))
                                        .matchedGeometryEffect(id: "periodPill", in: periodNS)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(AuraPressStyle())
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: selectedPeriod)
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )

            // ── Chart area ──
            // All 4 charts live simultaneously in a ZStack.
            // Chart TYPE switch → crossfade via opacity.
            // PERIOD switch → charts re-animate internally
            //   (line draws left→right, bars grow from bottom)
            //   driven by `animationID` = selectedPeriod.rawValue.
            ZStack {
                moodChartContent
                    .opacity(selectedChart == 0 ? 1 : 0)
                    .allowsHitTesting(selectedChart == 0)
                sleepChartContent
                    .opacity(selectedChart == 1 ? 1 : 0)
                    .allowsHitTesting(selectedChart == 1)
                stepsChartContent
                    .opacity(selectedChart == 2 ? 1 : 0)
                    .allowsHitTesting(selectedChart == 2)
                heartRateChartContent
                    .opacity(selectedChart == 3 ? 1 : 0)
                    .allowsHitTesting(selectedChart == 3)
            }
            .animation(.easeInOut(duration: 0.25), value: selectedChart)
            .padding(16)
            .glassCard()
        }
        .padding(.horizontal)
        .onAppear { rebuildAllAggregations() }
        .onChange(of: dataStore.dataVersion) { _, _ in rebuildAllAggregations() }
    }

    /// Pre-computes aggregations for ALL three periods at once.
    /// Switching W/M/Y afterward is a zero-cost dictionary lookup.
    private func rebuildAllAggregations() {
        let dv = dataStore.dataVersion
        guard dv != lastDataVersion else { return }
        lastDataVersion = dv

        var result: [TimePeriod: AllAgg] = [:]
        for period in TimePeriod.allCases {
            result[period] = AllAgg(
                mood:  computeAggregatedMood(for: period),
                sleep: computeAggregatedSnapshots(keyPath: \.sleepHours, for: period),
                steps: computeAggregatedSnapshots(keyPath: \.steps, for: period)
                    .map { ($0.label, Double($0.value)) },
                hr:    computeAggregatedSnapshots(keyPath: \.heartRate, for: period)
            )
        }
        aggByPeriod = result
    }

    // ════════════════════════════════════════════════════
    // MARK: - MOOD CHART
    // ════════════════════════════════════════════════════

    private var moodChartContent: some View {
        let data = cachedMoodAgg
        let displayVal: String = {
            if let idx = selectedIndex, idx < data.count {
                return String(format: "%.0f%%", data[idx].value * 100)
            }
            return data.last.map { String(format: "%.0f%%", $0.value * 100) } ?? "–"
        }()
        let displayLabel: String = {
            if let idx = selectedIndex, idx < data.count {
                return data[idx].label
            }
            return "\(selectedPeriod.label) Mood Average"
        }()
        return VStack(alignment: .leading, spacing: 8) {
            chartHeader(title: displayLabel, current: displayVal)
            InteractiveLineChart(data: data.map(\.value),
                                 rawValues: data.map { $0.value * 100 },
                                 color: Color(red: 0.30, green: 0.90, blue: 0.50),
                                 height: chartHeight,
                                 selectedIndex: $selectedIndex,
                                 animationID: selectedPeriod.rawValue)
            chartFooter(start: data.first?.label ?? "", end: data.last?.label ?? "")
        }
    }

    private func computeAggregatedMood(for period: TimePeriod) -> [(label: String, value: Double)] {
        let cal = Calendar.current
        let sortedMoods = dataStore.sortedMoods
        guard let first = sortedMoods.first?.date else { return [] }

        var result: [(label: String, value: Double)] = []
        var cursor = cal.startOfDay(for: first)

        // Binary-search helper: find first index where date >= target
        func lowerBound(_ target: Date) -> Int {
            var lo = 0, hi = sortedMoods.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if sortedMoods[mid].date < target { lo = mid + 1 } else { hi = mid }
            }
            return lo
        }

        switch period {
        case .week:
            while cursor < Date() {
                let end = cal.date(byAdding: .day, value: 7, to: cursor)!
                let lo = lowerBound(cursor)
                let hi = lowerBound(end)
                if lo < hi {
                    let slice = sortedMoods[lo..<hi]
                    let avg = slice.map(\.mood.score).reduce(0, +) / Double(slice.count)
                    result.append((label: AuraFormatters.weekLabel.string(from: cursor), value: avg))
                }
                cursor = end
            }
        case .month:
            cursor = cal.date(from: cal.dateComponents([.year, .month], from: first))!
            while cursor < Date() {
                let end = cal.date(byAdding: .month, value: 1, to: cursor)!
                let lo = lowerBound(cursor)
                let hi = lowerBound(end)
                if lo < hi {
                    let slice = sortedMoods[lo..<hi]
                    let avg = slice.map(\.mood.score).reduce(0, +) / Double(slice.count)
                    result.append((label: AuraFormatters.monthLabel.string(from: cursor), value: avg))
                }
                cursor = end
            }
        case .year:
            cursor = cal.date(from: cal.dateComponents([.year], from: first))!
            while cursor < Date() {
                let end = cal.date(byAdding: .year, value: 1, to: cursor)!
                let lo = lowerBound(cursor)
                let hi = lowerBound(end)
                if lo < hi {
                    let slice = sortedMoods[lo..<hi]
                    let avg = slice.map(\.mood.score).reduce(0, +) / Double(slice.count)
                    result.append((label: AuraFormatters.yearLabel.string(from: cursor), value: avg))
                }
                cursor = end
            }
        }
        return result
    }

    // ════════════════════════════════════════════════════
    // MARK: - SLEEP CHART
    // ════════════════════════════════════════════════════

    private var sleepChartContent: some View {
        let data = cachedSleepAgg
        let norm = data.map { $0.value / 12.0 }
        let displayVal: String = {
            if let idx = selectedIndex, idx < data.count {
                return String(format: "%.1fh", data[idx].value)
            }
            return data.last.map { String(format: "%.1fh", $0.value) } ?? "–"
        }()
        let displayLabel: String = {
            if let idx = selectedIndex, idx < data.count {
                return data[idx].label
            }
            return "\(selectedPeriod.label) Sleep Average"
        }()
        return VStack(alignment: .leading, spacing: 8) {
            chartHeader(title: displayLabel, current: displayVal)
            InteractiveLineChart(data: norm,
                                 rawValues: data.map(\.value),
                                 color: Color(red: 0.45, green: 0.65, blue: 1.0),
                                 height: chartHeight,
                                 selectedIndex: $selectedIndex,
                                 animationID: selectedPeriod.rawValue)
            chartFooter(start: data.first?.label ?? "", end: data.last?.label ?? "")
        }
    }

    // ════════════════════════════════════════════════════
    // MARK: - STEPS CHART
    // ════════════════════════════════════════════════════

    private var stepsChartContent: some View {
        let data = cachedStepsAgg
        let maxVal = data.map(\.value).max() ?? 1
        let norm = data.map { $0.value / maxVal }
        let displayVal: String = {
            if let idx = selectedIndex, idx < data.count {
                return "\(Int(data[idx].value).formatted())"
            }
            return data.last.map { "\(Int($0.value).formatted())" } ?? "–"
        }()
        let displayLabel: String = {
            if let idx = selectedIndex, idx < data.count {
                return data[idx].label
            }
            return "\(selectedPeriod.label) Steps Average"
        }()
        return VStack(alignment: .leading, spacing: 8) {
            chartHeader(title: displayLabel, current: displayVal)
            InteractiveBarChart(data: norm,
                                rawValues: data.map(\.value),
                                color: Color(red: 1.0, green: 0.78, blue: 0.28),
                                height: chartHeight,
                                selectedIndex: $selectedIndex,
                                animationID: selectedPeriod.rawValue)
            chartFooter(start: data.first?.label ?? "", end: data.last?.label ?? "")
        }
    }

    // ════════════════════════════════════════════════════
    // MARK: - HEART RATE CHART
    // ════════════════════════════════════════════════════

    private var heartRateChartContent: some View {
        let data = cachedHRAgg
        let minHR = max((data.map(\.value).min() ?? 55) - 5, 40)
        let maxHR = (data.map(\.value).max() ?? 90) + 5
        let range = maxHR - minHR
        let norm = data.map { ($0.value - minHR) / (range > 0 ? range : 1) }
        let displayVal: String = {
            if let idx = selectedIndex, idx < data.count {
                return String(format: "%.0f bpm", data[idx].value)
            }
            return data.last.map { String(format: "%.0f bpm", $0.value) } ?? "–"
        }()
        let displayLabel: String = {
            if let idx = selectedIndex, idx < data.count {
                return data[idx].label
            }
            return "\(selectedPeriod.label) Resting HR"
        }()
        return VStack(alignment: .leading, spacing: 8) {
            chartHeader(title: displayLabel, current: displayVal)
            InteractiveLineChart(data: norm,
                                 rawValues: data.map(\.value),
                                 color: Color(red: 1.0, green: 0.42, blue: 0.38),
                                 height: chartHeight,
                                 selectedIndex: $selectedIndex,
                                 animationID: selectedPeriod.rawValue)
            chartFooter(start: data.first?.label ?? "", end: data.last?.label ?? "")
        }
    }

    // ════════════════════════════════════════════════════
    // MARK: - AGGREGATION HELPERS
    // ════════════════════════════════════════════════════

    private func computeAggregatedSnapshots<T: Numeric>(
        keyPath: KeyPath<DailySnapshot, T>,
        for period: TimePeriod
    ) -> [(label: String, value: Double)] {
        let cal = Calendar.current
        let sortedSnaps = dataStore.sortedSnaps
        guard let first = sortedSnaps.first?.date else { return [] }

        var result: [(label: String, value: Double)] = []
        var cursor: Date
        // Binary-search helper: find first index where date >= target
        func lowerBound(_ target: Date) -> Int {
            var lo = 0, hi = sortedSnaps.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if sortedSnaps[mid].date < target { lo = mid + 1 } else { hi = mid }
            }
            return lo
        }

        switch period {
        case .week:
            cursor = cal.startOfDay(for: first)
            while cursor < Date() {
                let end = cal.date(byAdding: .day, value: 7, to: cursor)!
                let lo = lowerBound(cursor)
                let hi = lowerBound(end)
                if lo < hi {
                    let values = sortedSnaps[lo..<hi].map { Double("\($0[keyPath: keyPath])") ?? 0 }
                    let avg = values.reduce(0, +) / Double(values.count)
                    result.append((label: AuraFormatters.weekLabel.string(from: cursor), value: avg))
                }
                cursor = end
            }
        case .month:
            cursor = cal.date(from: cal.dateComponents([.year, .month], from: first))!
            while cursor < Date() {
                let end = cal.date(byAdding: .month, value: 1, to: cursor)!
                let lo = lowerBound(cursor)
                let hi = lowerBound(end)
                if lo < hi {
                    let values = sortedSnaps[lo..<hi].map { Double("\($0[keyPath: keyPath])") ?? 0 }
                    let avg = values.reduce(0, +) / Double(values.count)
                    result.append((label: AuraFormatters.monthLabel.string(from: cursor), value: avg))
                }
                cursor = end
            }
        case .year:
            cursor = cal.date(from: cal.dateComponents([.year], from: first))!
            while cursor < Date() {
                let end = cal.date(byAdding: .year, value: 1, to: cursor)!
                let lo = lowerBound(cursor)
                let hi = lowerBound(end)
                if lo < hi {
                    let values = sortedSnaps[lo..<hi].map { Double("\($0[keyPath: keyPath])") ?? 0 }
                    let avg = values.reduce(0, +) / Double(values.count)
                    result.append((label: AuraFormatters.yearLabel.string(from: cursor), value: avg))
                }
                cursor = end
            }
        }
        return result
    }

    // ════════════════════════════════════════════════════
    // MARK: - CHART COMPONENTS
    // ════════════════════════════════════════════════════

    @ViewBuilder
    private func chartHeader(title: String, current: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AuraTheme.textSecondary)
                .contentTransition(.numericText())
            Spacer()
            Text(current)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .animation(.easeInOut(duration: 0.15), value: current)
    }

    @ViewBuilder
    private func chartFooter(start: String, end: String) -> some View {
        HStack {
            Text(start)
            Spacer()
            Text(end)
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundColor(AuraTheme.textTertiary)
    }
}
