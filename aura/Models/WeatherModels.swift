import SwiftUI

// ============================================================
// MARK: - FREE API STRUCTS
// ============================================================

struct WeatherAPIResponse: Codable {
    let current: CurrentWeather
    let forecast: WeatherForecast?
}

struct CurrentWeather: Codable {
    let temp_c: Double
    let condition: WeatherCondition
    let uv: Double
    let is_day: Int
    let wind_kph: Double
    let wind_dir: String
    let precip_mm: Double
}

struct WeatherCondition: Codable {
    let text: String
}

struct WeatherForecast: Codable {
    let forecastday: [ForecastDay]
}

struct ForecastDay: Codable {
    let astro: AstroData
}

struct AstroData: Codable {
    let sunrise: String   // e.g. "06:42 AM"
    let sunset: String    // e.g. "07:18 PM"
}
