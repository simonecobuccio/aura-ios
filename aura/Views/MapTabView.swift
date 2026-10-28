import SwiftUI
import MapKit

// ============================================================
// MARK: - MAP TAB VIEW
// ============================================================

struct MapTabView: View {
    @ObservedObject var weather: WeatherViewModel

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedLayer: MapLayer = .standard
    @State private var showLayerPicker = false

    enum MapLayer: String, CaseIterable {
        case standard      = "Standard"
        case uvIndex       = "UV Index"
        case temperature   = "Temperature"
        case wind          = "Wind"
        case precipitation = "Precipitation"

        var icon: String {
            switch self {
            case .standard:      return "map"
            case .uvIndex:       return "sun.max.fill"
            case .temperature:   return "thermometer.medium"
            case .wind:          return "wind"
            case .precipitation: return "cloud.rain.fill"
            }
        }
    }

    var uvColor: Color {
        switch weather.uvIndex {
        case 0...2:  return .green
        case 3...5:  return .yellow
        case 6...7:  return .orange
        case 8...10: return .red
        default:     return .purple
        }
    }

    var precipColor: Color {
        switch weather.precipMM {
        case 0:        return Color(red: 0.55, green: 0.65, blue: 0.75)
        case 0.1...2:  return Color(red: 0.40, green: 0.70, blue: 1.0)
        case 2.1...10: return Color(red: 0.30, green: 0.50, blue: 1.0)
        default:       return Color(red: 0.25, green: 0.35, blue: 0.90)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {

            // ── Fullscreen Map ──
            Map(position: $position) {
                UserAnnotation()

                if let coord = weather.currentCoordinate {
                    // UV annotation
                    if selectedLayer == .uvIndex {
                        Annotation("UV \(weather.uvIndex)", coordinate: coord) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [uvColor.opacity(0.30), uvColor.opacity(0)],
                                            center: .center,
                                            startRadius: 8, endRadius: 40
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                Circle()
                                    .stroke(uvColor, lineWidth: 3)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .frame(width: 48, height: 48)
                                VStack(spacing: 1) {
                                    Text("\(weather.uvIndex)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("UV")
                                        .font(.system(size: 8, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }

                    // Temperature annotation
                    if selectedLayer == .temperature {
                        Annotation(weather.temperature, coordinate: coord) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [Color.orange.opacity(0.25), Color.orange.opacity(0)],
                                            center: .center,
                                            startRadius: 6, endRadius: 35
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                Circle()
                                    .stroke(Color.orange, lineWidth: 3)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .frame(width: 48, height: 48)
                                Text(weather.temperature)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    // Wind annotation
                    if selectedLayer == .wind {
                        Annotation("Wind", coordinate: coord) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [Color.cyan.opacity(0.25), Color.cyan.opacity(0)],
                                            center: .center,
                                            startRadius: 6, endRadius: 35
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                Circle()
                                    .stroke(Color.cyan, lineWidth: 3)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .frame(width: 52, height: 52)
                                VStack(spacing: 1) {
                                    Text(weather.windDirection)
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(String(format: "%.0f", weather.windSpeed))
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("km/h")
                                        .font(.system(size: 7, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                    }

                    // Precipitation annotation
                    if selectedLayer == .precipitation {
                        Annotation("Precip", coordinate: coord) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [precipColor.opacity(0.30), precipColor.opacity(0)],
                                            center: .center,
                                            startRadius: 6, endRadius: 38
                                        )
                                    )
                                    .frame(width: 75, height: 75)
                                Circle()
                                    .stroke(precipColor, lineWidth: 3)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .frame(width: 48, height: 48)
                                VStack(spacing: 1) {
                                    Image(systemName: "cloud.rain.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(String(format: "%.1f", weather.precipMM))
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("mm")
                                        .font(.system(size: 7, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .all,
                                showsTraffic: false))
            .mapControls {
                MapCompass()
            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)

            // ── Top info card ──
            VStack {
                if selectedLayer != .standard {
                    HStack(spacing: 14) {
                        Image(systemName: selectedLayer.icon)
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.45, green: 0.75, blue: 1.0))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedLayer.rawValue)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(infoText)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        Text(infoValue)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 2)
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(.top, 6)

            // ── Bottom-right controls ──
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 10) {
                        // Layer picker (appears above buttons)
                        if showLayerPicker {
                            VStack(spacing: 4) {
                                ForEach(MapLayer.allCases, id: \.rawValue) { layer in
                                    Button(action: {
                                        withAnimation(.spring(duration: 0.25)) {
                                            selectedLayer = layer
                                            showLayerPicker = false
                                        }
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: layer.icon)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(selectedLayer == layer
                                                                 ? Color(red: 0.45, green: 0.75, blue: 1.0)
                                                                 : .white)
                                            Text(layer.rawValue)
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                .foregroundColor(selectedLayer == layer
                                                                 ? Color(red: 0.45, green: 0.75, blue: 1.0)
                                                                 : .white.opacity(0.7))
                                        }
                                        .frame(width: 72)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(selectedLayer == layer
                                                      ? Color.white.opacity(0.15) : Color.clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        // Layer toggle button
                        Button(action: {
                            withAnimation(.spring(duration: 0.3)) { showLayerPicker.toggle() }
                        }) {
                            Image(systemName: "square.3.layers.3d.top.filled")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 46, height: 46)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                                )
                        }

                        // Location button
                        Button(action: {
                            weather.refreshLocation()
                            // Force SwiftUI to detect a change by toggling
                            // to .automatic first, then back to .userLocation.
                            position = .automatic
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    position = .userLocation(fallback: .automatic)
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 46, height: 46)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                                )
                        }
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 90)
                }
            }
        }
        .animation(.spring(duration: 0.3), value: selectedLayer)
    }

    private var infoText: String {
        switch selectedLayer {
        case .uvIndex:       return weather.condition
        case .temperature:   return weather.condition
        case .wind:          return weather.windDirection
        case .precipitation: return weather.condition
        default:             return ""
        }
    }

    private var infoValue: String {
        switch selectedLayer {
        case .uvIndex:       return "\(weather.uvIndex)"
        case .temperature:   return weather.temperature
        case .wind:          return String(format: "%.0f km/h", weather.windSpeed)
        case .precipitation: return String(format: "%.1f mm", weather.precipMM)
        default:             return ""
        }
    }
}
