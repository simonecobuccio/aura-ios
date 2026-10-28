import SwiftUI
import MapKit

// ============================================================
// MARK: - AURA MAP VIEW
// ============================================================

struct AuraMapView: View {
    @ObservedObject var weather: WeatherViewModel
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var uvColor: Color {
        switch weather.uvIndex {
        case 0...2:  return .green
        case 3...5:  return .yellow
        case 6...7:  return .orange
        case 8...10: return .red
        default:     return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Local Aura Map")
                .padding(.horizontal)

            Map(position: $position) {
                UserAnnotation()
                if let coordinate = weather.currentCoordinate {
                    Annotation("Current UV", coordinate: coordinate) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [uvColor.opacity(0.35), uvColor.opacity(0)],
                                        center: .center,
                                        startRadius: 4, endRadius: 30
                                    )
                                )
                                .frame(width: 60, height: 60)
                            Circle()
                                .stroke(uvColor, lineWidth: 2.5)
                                .background(Circle().fill(.ultraThinMaterial))
                                .frame(width: 40, height: 40)
                            Text("\(weather.uvIndex)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AuraTheme.glassBorder, lineWidth: 0.5)
            )
            .padding(.horizontal)
        }
    }
}
