import SwiftUI
import Observation
import CoreLocation

// MARK: - Ort

struct ResolvedPlace: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double

    static let wien = ResolvedPlace(name: "Wien", latitude: 48.2082, longitude: 16.3738)
    static let linz = ResolvedPlace(name: "Linz", latitude: 48.3069, longitude: 14.2858)
}

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    var status: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        status = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var isDenied: Bool {
        status == .denied || status == .restricted
    }

    func request() {
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            manager.requestLocation()
        }
    }

    func resolve(_ mode: PlaceMode) -> ResolvedPlace {
        switch mode {
        case .wien: return .wien
        case .linz: return .linz
        case .auto:
            if let latitude, let longitude {
                return ResolvedPlace(name: placeName ?? "Dein Standort", latitude: latitude, longitude: longitude)
            }
            return .wien
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
            manager.requestLocation()
        }
        Task { @MainActor in self.status = newStatus }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let lat = last.coordinate.latitude
        let lon = last.coordinate.longitude
        Task { @MainActor in
            self.latitude = lat
            self.longitude = lon
            await self.lookUpName(lat: lat, lon: lon)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func lookUpName(lat: Double, lon: Double) async {
        let geocoder = CLGeocoder()
        if let marks = try? await geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon)),
           let city = marks.first?.locality {
            placeName = city
        }
    }
}

// MARK: - Wetter

struct DayWeather {
    let code: Int
    let tmax: Double
    let tmin: Double
    let rain: Int

    var symbol: String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    var isRainy: Bool { rain >= 60 || (51...67).contains(code) || (80...82).contains(code) }

    var tip: String {
        if isRainy { return "Trenchcoat oder Schirm" }
        if tmax < 3 { return "Wintermantel und Schal" }
        if tmax < 12 { return "Ein warmer Mantel" }
        if tmax < 18 { return "Eine leichte Jacke" }
        if tmax > 27 { return "Luftig und leicht" }
        return "Perfektes Wetter für dein Lieblingsstück"
    }

    var summary: String { "\(Int(tmax.rounded()))° / \(Int(tmin.rounded()))°" }

    /// Leichte Lichtstimmung: warm bei Sonne, kühl bei Regen.
    var mood: Color {
        if isRainy { return Color(hex: 0x8FA6B8).opacity(0.14) }
        if code <= 2 { return Color(hex: 0xF4C77A).opacity(0.16) }
        return .clear
    }
}

private struct Forecast: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int?]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let precipitation_probability_max: [Int?]?
    }
    let daily: Daily
}

@MainActor
@Observable
final class WeatherService {
    var days: [String: DayWeather] = [:]
    private var loadedFor: ResolvedPlace?

    func refresh(for place: ResolvedPlace) async {
        if loadedFor == place, !days.isEmpty { return }
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", place.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", place.longitude)),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "16"),
        ]
        guard let url = comps.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let d = try JSONDecoder().decode(Forecast.self, from: data).daily
            var out: [String: DayWeather] = [:]
            for (i, day) in d.time.enumerated() {
                guard i < d.weather_code.count, i < d.temperature_2m_max.count, i < d.temperature_2m_min.count,
                      let code = d.weather_code[i],
                      let hi = d.temperature_2m_max[i],
                      let lo = d.temperature_2m_min[i] else { continue }
                var rain = 0
                if let probs = d.precipitation_probability_max, i < probs.count, let p = probs[i] { rain = p }
                out[day] = DayWeather(code: code, tmax: hi, tmin: lo, rain: rain)
            }
            days = out
            loadedFor = place
        } catch {
            // Ohne Internet zeigt der Kalender einfach kein Wetter.
        }
    }
}
