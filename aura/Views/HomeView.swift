import SwiftUI

// ============================================================
// MARK: - HOME VIEW
// ============================================================

struct HomeView: View {
    @ObservedObject var auth: AuthViewModel
    @ObservedObject var weather: WeatherViewModel
    @ObservedObject var dataStore: AuraDataStore
    @Binding var isPremium: Bool

    @StateObject private var health  = HealthViewModel()

    @State private var showMoodSheet: Bool         = false
    @State private var showPaywall:   Bool         = false

    /// The last logged mood (used for button icon + mood sheet pre-selection)
    var lastMood: Mood? { dataStore.moodEntries.first?.mood }

    /// Remaining slots today
    var slotsLeftToday: Int {
        2 - MoodHelpers.todayCount(in: dataStore.moodEntries)
    }

    /// Cached Aura score — updated only when inputs change
    @State private var auraScore: AuraScore = AuraScore(
        sleepScore: 0, stepsScore: 0, uvScore: 0, moodScore: 0.5
    )

    private func recomputeAuraScore() {
        auraScore = AuraScore(
            sleepScore:    health.sleepScore,
            stepsScore:    health.stepsScore,
            uvScore:       weather.uvScore,
            moodScore:     dataStore.moodEntries.first?.mood.score ?? 0.5,
            sunlightHours: weather.sunlightHours,
            heartRate:     health.heartRate,
            recentMoods:   Array(dataStore.moodEntries.prefix(5).map { $0.mood.score })
        )
    }

    /// Lightweight fingerprint that combines every input the score
    /// depends on. A single `.onChange` replaces 6 separate ones,
    /// cutting diffing work by ~5× on every publish cycle.
    private var scoreFingerprint: UInt64 {
        var h: UInt64 = 0
        h ^= health.sleepHours.bitPattern
        h ^= UInt64(health.steps) &* 2654435761
        h ^= health.heartRate.bitPattern &* 40503
        h ^= UInt64(weather.uvIndex) &* 2246822519
        h ^= weather.sunlightHours.bitPattern &* 3266489917
        h ^= UInt64(dataStore.dataVersion) &* 2891336453
        return h
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            AuraBackground(
                primaryColor: auraScore.color,
                secondaryColor: auraScore.secondaryColor
            )
            .animation(.easeInOut(duration: 1.6), value: auraScore.composite)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 28) {

                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your Aura")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text(AuraFormatters.dateLong.string(from: Date()))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(AuraTheme.textTertiary)
                        }
                        Spacer()

                        HStack(spacing: 10) {
                            // Profile menu
                            Menu {
                                if !auth.userName.isEmpty {
                                    Label(auth.userName, systemImage: "person.fill")
                                }
                                if !auth.userEmail.isEmpty {
                                    Label(auth.userEmail, systemImage: "envelope")
                                }
                                Divider()
                                Button(role: .destructive, action: {
                                    withAnimation(.easeInOut(duration: 0.4)) { auth.logout() }
                                }) {
                                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            } label: {
                                Circle()
                                    .fill(AuraTheme.glass)
                                    .overlay(Circle().stroke(AuraTheme.glassBorder, lineWidth: 0.5))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundColor(.white)
                                    )
                            }

                            // Mood button
                            Button(action: { withAnimation(.spring()) { showMoodSheet = true } }) {
                                ZStack(alignment: .topTrailing) {
                                    Circle()
                                        .fill(AuraTheme.glass)
                                        .overlay(Circle().stroke(AuraTheme.glassBorder, lineWidth: 0.5))
                                        .frame(width: 42, height: 42)
                                        .overlay(
                                            Group {
                                                if let mood = lastMood {
                                                    Image(systemName: mood.symbolName)
                                                        .font(.system(size: 18, weight: .medium))
                                                        .foregroundColor(mood.color)
                                                } else {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.system(size: 18, weight: .medium))
                                                        .foregroundColor(AuraTheme.textSecondary)
                                                }
                                            }
                                        )

                                    if slotsLeftToday > 0 {
                                        Text("\(slotsLeftToday)")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .frame(width: 15, height: 15)
                                            .background(Circle().fill(Color(red: 0.35, green: 0.78, blue: 1.0)))
                                            .offset(x: 2, y: -2)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // Ring
                    if weather.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(height: 240)
                    } else {
                        AuraRingView(score: auraScore, size: 230)
                    }

                    // Weather chip
                    HStack(spacing: 7) {
                        Image(systemName: weather.isDaytime ? "sun.max.fill" : "moon.stars.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow.opacity(0.8))
                        Text(weather.condition)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AuraTheme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AuraTheme.glass)
                            .overlay(Capsule().stroke(AuraTheme.glassBorder, lineWidth: 0.5))
                    )
                    .padding(.top, -10)

                    // Insight nudge
                    if !auraScore.insight.isEmpty && !weather.isLoading {
                        Text(auraScore.insight)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AuraTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, -4)
                    }

                    HStack(spacing: 10) {
                        StatCard(icon: "thermometer.medium", label: "Temp",
                                 value: weather.temperature)
                        StatCard(icon: "bed.double.fill", label: "Sleep",
                                 value: health.sleepHours > 0
                                    ? String(format: "%.1fh", health.sleepHours) : "–")
                        StatCard(icon: "figure.walk", label: "Steps",
                                 value: health.steps > 0
                                    ? "\(health.steps.formatted())" : "–")
                    }
                    .padding(.horizontal)

                    HStack(spacing: 10) {
                        StatCard(icon: "sun.max.fill", label: "UV Index",
                                 value: "\(weather.uvIndex)")
                        StatCard(icon: "heart.fill", label: "Heart Rate",
                                 value: health.heartRate > 0
                                    ? "\(Int(health.heartRate)) bpm" : "–")
                        StatCard(icon: "brain.head.profile", label: "Mood",
                                 value: dataStore.moodEntries.first?.mood.rawValue ?? "–")
                    }
                    .padding(.horizontal)

                    Rectangle()
                        .fill(AuraTheme.glassBorder)
                        .frame(height: 0.5)
                        .padding(.horizontal, 32)

                    // Mood Calendar
                    MoodCalendarView(dataStore: dataStore)

                    Rectangle()
                        .fill(AuraTheme.glassBorder)
                        .frame(height: 0.5)
                        .padding(.horizontal, 32)

                    SADTrackerView(
                        sunlightHours: weather.sunlightHours,
                        sunriseTime:   weather.sunriseTime,
                        sunsetTime:    weather.sunsetTime,
                        moodEntries:   dataStore.moodEntries
                    )

                    Spacer(minLength: 100)
                }
            }

            // Blur strip that protects the Dynamic Island / status-bar zone
            TopSafeAreaBlur()

            // Mood sheet
            if showMoodSheet {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showMoodSheet = false } }
                    .transition(.opacity)

                MoodCheckInView(
                    isPresented:   $showMoodSheet,
                    dataStore:     dataStore,
                    sunlightHours: weather.sunlightHours,
                    lastMood:      lastMood
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Paywall
            if showPaywall {
                PaywallView(isPresented: $showPaywall, isPremium: $isPremium)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: showMoodSheet)
        .animation(.spring(duration: 0.4), value: showPaywall)
        .onAppear {
            health.requestAuthorization()
            recomputeAuraScore()
        }
        // One fingerprint replaces 6 separate .onChange — SwiftUI diffs a single UInt64
        .onChange(of: scoreFingerprint) { _, _ in recomputeAuraScore() }
    }
}
