import SwiftUI
import MapKit

// ============================================================
// MARK: - CONTENT VIEW (entry point)
// ============================================================

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()

    var body: some View {
        Group {
            if auth.isLoggedIn {
                MainTabView(auth: auth)
                    .transition(.opacity)
            } else {
                LoginView(auth: auth)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: auth.isLoggedIn)
    }
}

struct MainTabView: View {
    @ObservedObject var auth: AuthViewModel

    // Shared state
    @StateObject private var weather = WeatherViewModel()
    @StateObject private var dataStore = AuraDataStore()
    @State private var isPremium: Bool = false
    @State private var selectedTab: Int = 0

    /// Background Map stays alive until the user visits the Map tab,
    /// keeping MapKit's Metal pipeline and tile cache warm.
    @State private var mapPreWarmed = false

    var premiumKey: String {
        "aura.premium.\(auth.userEmail.lowercased())"
    }

    var body: some View {
        // Native TabView — iOS 26+ automatically adopts Liquid Glass.
        //
        // The first three tabs (Home, Trends, Map) sit together in
        // one Liquid Glass pill on the left. The Aura AI tab uses
        // role: .search which makes iOS 26 render it as a separate
        // floating glass circle on the right — exactly like the
        // pattern Apple uses in its own apps (e.g. App Store, Music).
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView(auth: auth, weather: weather, dataStore: dataStore, isPremium: $isPremium)
            }

            Tab("Trends", systemImage: "chart.line.uptrend.xyaxis", value: 1) {
                TrendsTabView(dataStore: dataStore, isPremium: $isPremium)
            }

            Tab("Map", systemImage: "map.fill", value: 2) {
                MapTabView(weather: weather)
            }

            // role: .search → iOS 26 visually separates this tab
            // as a floating Liquid Glass circle on the bottom-right,
            // distinct from the main tab pill.
            Tab("Aura AI", systemImage: "sparkles", value: 3, role: .search) {
                ChatTabView(isPremium: $isPremium)
            }
        }
        // Collapse tabs into a single dot when user scrolls content
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.white)
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // ── MapKit pre-warmer ──
        // A full-size Map with the same style as MapTabView renders
        // behind the TabView at near-zero opacity.  This forces
        // MapKit to fully init its Metal shaders, tile cache, and
        // display-link pipeline while the user is on the Home tab.
        // Removed only when the user actually visits the Map tab.
        .background {
            if !mapPreWarmed {
                Map {
                    UserAnnotation()
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .all,
                                    showsTraffic: false))
                .mapControls { MapCompass() }
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .ignoresSafeArea()
            }
        }
        .task {
            // MKMapSnapshotter — belt-and-suspenders: forces MapKit to
            // load shaders + tiles on a BG thread immediately at launch.
            let opts = MKMapSnapshotter.Options()
            opts.size = CGSize(width: 512, height: 512)
            opts.mapType = .standard
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                MKMapSnapshotter(options: opts).start { _, _ in cont.resume() }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Map tab visited — remove background prewarmer
            if newTab == 2 {
                // Small delay so the real Map has a frame to appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    mapPreWarmed = true
                }
            }
        }
        .onChange(of: isPremium) { _, newVal in
            UserDefaults.standard.set(newVal, forKey: premiumKey)
            if newVal {
                AuraNotificationManager.shared.enableReminders()
            } else {
                AuraNotificationManager.shared.disableReminders()
            }
        }
        .onAppear {
            // Reset demo premium
            if auth.userEmail.lowercased() == "demo@aura.app" {
                UserDefaults.standard.set(false, forKey: premiumKey)
            }
            isPremium = UserDefaults.standard.bool(forKey: premiumKey)
            if isPremium {
                AuraNotificationManager.shared.enableReminders()
            }
            // Load data once for all tabs
            dataStore.loadIfNeeded(email: auth.userEmail)
        }
    }
}

#Preview {
    ContentView()
}
