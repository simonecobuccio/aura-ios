import SwiftUI
import CoreLocation
import Combine

@MainActor
class WeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var temperature:   String = "--"
    @Published var condition:     String = "Loading…"
    @Published var uvIndex:       Int    = 0
    @Published var sunriseTime:   String = "6:30 AM"
    @Published var sunsetTime:    String = "7:45 PM"
    @Published var sunlightHours: Double = 13.0
    @Published var isDaytime:     Bool   = true
    @Published var isLoading:     Bool   = true
    @Published var windSpeed:     Double = 0
    @Published var windDirection: String = "--"
    @Published var precipMM:      Double = 0
    @Published var currentCoordinate: CLLocationCoordinate2D?

    private let locationManager = CLLocationManager()
    private let apiKey = "YOUR_WEATHERAPI_KEY"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        DispatchQueue.main.async { self.currentCoordinate = loc.coordinate }
        Task { await fetchFreeWeather(lat: loc.coordinate.latitude,
                                      lon: loc.coordinate.longitude) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        isLoading = false
    }

    /// Request a fresh GPS fix. Called by the map's "locate me" button
    /// so the blue dot and camera update to the real current position.
    func refreshLocation() {
        locationManager.requestLocation()
    }

    func fetchFreeWeather(lat: Double, lon: Double) async {
        // Use forecast endpoint (days=1) to get astronomy data (sunrise/sunset)
        let urlString = "https://api.weatherapi.com/v1/forecast.json?key=\(apiKey)&q=\(lat),\(lon)&days=1"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded    = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
            temperature = String(format: "%.0f°C", decoded.current.temp_c)
            condition   = decoded.current.condition.text
            uvIndex     = Int(decoded.current.uv)
            isDaytime   = decoded.current.is_day == 1
            windSpeed   = decoded.current.wind_kph
            windDirection = decoded.current.wind_dir
            precipMM    = decoded.current.precip_mm

            // Parse sunrise/sunset from astronomy data
            if let astro = decoded.forecast?.forecastday.first?.astro {
                sunriseTime = astro.sunrise.trimmingCharacters(in: .whitespaces)
                sunsetTime  = astro.sunset.trimmingCharacters(in: .whitespaces)

                // Calculate sunlight hours from sunrise/sunset
                if let rise = AuraFormatters.time12h.date(from: sunriseTime),
                   let set  = AuraFormatters.time12h.date(from: sunsetTime) {
                    let diff = set.timeIntervalSince(rise)
                    sunlightHours = max(diff / 3600.0, 0)
                }
            }

            isLoading   = false
        } catch {
            print("Error fetching weather: \(error.localizedDescription)")
            condition = "Unavailable"
            isLoading = false
        }
    }

    /// UV score: moderate exposure (2-5) is optimal for vitamin D
    /// and wellbeing. Too low = insufficient, too high = harmful.
    var uvScore: Double {
        switch uvIndex {
        case 3...5: return 1.0    // sweet spot
        case 2:     return 0.85
        case 6:     return 0.75
        case 1:     return 0.6    // too little sun
        case 7:     return 0.55
        case 8...:  return 0.3    // dangerous
        default:    return 0.4    // 0 = night or indoors
        }
    }
}
