import CoreLocation
import Foundation

enum WeatherLinkStatus: Equatable {
    case disabled
    case locating
    case checking
    case dry
    case raining
    case snowing
    case permissionDenied
    case unavailable
}

enum WeatherEffect: String, Codable, Equatable {
    case none
    case rain
    case snow
}

struct CoarseWeatherCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    static func rounded(latitude: Double, longitude: Double) -> CoarseWeatherCoordinate {
        CoarseWeatherCoordinate(
            latitude: (latitude * 100).rounded() / 100,
            longitude: (longitude * 100).rounded() / 100
        )
    }
}

struct WeatherObservation: Equatable {
    let weatherCode: Int
    let rain: Double
    let showers: Double
    let snowfall: Double

    var effect: WeatherEffect {
        WeatherConditionEvaluator.effect(
            weatherCode: weatherCode,
            rain: rain,
            showers: showers,
            snowfall: snowfall
        )
    }

    var isRaining: Bool {
        effect == .rain
    }

    var isSnowing: Bool { effect == .snow }
}

enum WeatherConditionEvaluator {
    private static let rainCodes = Set([
        51, 53, 55, 56, 57,
        61, 63, 65, 66, 67,
        80, 81, 82,
        95, 96, 99
    ])

    private static let snowCodes = Set([
        71, 73, 75, 77,
        85, 86
    ])

    static func effect(
        weatherCode: Int,
        rain: Double,
        showers: Double,
        snowfall: Double
    ) -> WeatherEffect {
        if snowfall > 0 || snowCodes.contains(weatherCode) { return .snow }
        if rain > 0 || showers > 0 || rainCodes.contains(weatherCode) { return .rain }
        return .none
    }

    static func isRaining(weatherCode: Int, rain: Double, showers: Double) -> Bool {
        effect(weatherCode: weatherCode, rain: rain, showers: showers, snowfall: 0) == .rain
    }
}

final class WeatherClient {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        session = URLSession(configuration: configuration)
    }

    @discardableResult
    func fetchCurrent(
        at coordinate: CoarseWeatherCoordinate,
        completion: @escaping (Result<WeatherObservation, Error>) -> Void
    ) -> URLSessionDataTask? {
        guard let url = Self.url(for: coordinate) else {
            completion(.failure(WeatherClientError.invalidURL))
            return nil
        }

        let task = session.dataTask(with: url) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard
                let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode),
                let data
            else {
                completion(.failure(WeatherClientError.invalidResponse))
                return
            }
            do {
                completion(.success(try Self.decode(data: data)))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
        return task
    }

    static func decode(data: Data) throws -> WeatherObservation {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return WeatherObservation(
            weatherCode: response.current.weatherCode,
            rain: response.current.rain ?? 0,
            showers: response.current.showers ?? 0,
            snowfall: response.current.snowfall ?? 0
        )
    }

    private static func url(for coordinate: CoarseWeatherCoordinate) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        let locale = Locale(identifier: "en_US_POSIX")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", locale: locale, coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", locale: locale, coordinate.longitude)),
            URLQueryItem(name: "current", value: "weather_code,rain,showers,snowfall"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }

    private struct Response: Decodable {
        let current: Current
    }

    private struct Current: Decodable {
        let weatherCode: Int
        let rain: Double?
        let showers: Double?
        let snowfall: Double?

        enum CodingKeys: String, CodingKey {
            case weatherCode = "weather_code"
            case rain
            case showers
            case snowfall
        }
    }

    private enum WeatherClientError: LocalizedError {
        case invalidURL
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无法生成天气请求地址"
            case .invalidResponse: return "天气服务返回了异常响应"
            }
        }
    }
}

final class WeatherLinkManager: NSObject, CLLocationManagerDelegate {
    private static let refreshInterval: TimeInterval = 15 * 60
    private static let locationRefreshInterval: TimeInterval = 6 * 60 * 60
    private static let weatherCacheLifetime: TimeInterval = 30 * 60

    private enum Key {
        static let enabled = "QuotaGrove.weatherLink.enabled"
        static let latitude = "QuotaGrove.weatherLink.latitude"
        static let longitude = "QuotaGrove.weatherLink.longitude"
        static let locationUpdatedAt = "QuotaGrove.weatherLink.locationUpdatedAt"
        static let raining = "QuotaGrove.weatherLink.raining"
        static let effect = "QuotaGrove.weatherLink.effect"
        static let weatherUpdatedAt = "QuotaGrove.weatherLink.weatherUpdatedAt"
    }

    var onChange: ((WeatherLinkStatus, WeatherEffect) -> Void)?

    private let defaults: UserDefaults
    private let locationManager = CLLocationManager()
    private let client = WeatherClient()
    private var refreshTimer: Timer?
    private var weatherTask: URLSessionDataTask?
    private var weatherRequestID: UUID?
    private var locationRequestInProgress = false

    private(set) var status: WeatherLinkStatus = .disabled
    private(set) var weatherEffect: WeatherEffect = .none

    var isEnabled: Bool { defaults.bool(forKey: Key.enabled) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 10_000
    }

    func startIfEnabled() {
        guard isEnabled else {
            apply(status: .disabled, effect: .none)
            return
        }
        scheduleRefreshTimer()
        restoreFreshWeatherCache()
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.enabled)
        if enabled {
            startIfEnabled()
        } else {
            stop()
            apply(status: .disabled, effect: .none)
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        weatherTask?.cancel()
        weatherTask = nil
        weatherRequestID = nil
        locationManager.stopUpdatingLocation()
        locationRequestInProgress = false
    }

    func refresh() {
        guard isEnabled else { return }
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let coordinate = cachedCoordinate(), locationCacheIsFresh() {
                fetchWeather(at: coordinate)
            } else {
                requestCurrentLocation()
            }
        case .notDetermined:
            apply(status: .locating, effect: weatherEffect)
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            apply(status: .permissionDenied, effect: .none)
        @unknown default:
            apply(status: .unavailable, effect: .none)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isEnabled else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            refresh()
        case .denied, .restricted:
            apply(status: .permissionDenied, effect: .none)
        case .notDetermined:
            apply(status: .locating, effect: weatherEffect)
        @unknown default:
            apply(status: .unavailable, effect: .none)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationRequestInProgress = false
        guard isEnabled, let location = locations.last else { return }
        let coordinate = CoarseWeatherCoordinate.rounded(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        defaults.set(coordinate.latitude, forKey: Key.latitude)
        defaults.set(coordinate.longitude, forKey: Key.longitude)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.locationUpdatedAt)
        fetchWeather(at: coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationRequestInProgress = false
        guard isEnabled else { return }
        if let coordinate = cachedCoordinate() {
            fetchWeather(at: coordinate)
        } else {
            apply(status: .unavailable, effect: freshCachedEffect() ?? .none)
        }
    }

    private func requestCurrentLocation() {
        guard !locationRequestInProgress else { return }
        locationRequestInProgress = true
        apply(status: .locating, effect: weatherEffect)
        locationManager.requestLocation()
    }

    private func fetchWeather(at coordinate: CoarseWeatherCoordinate) {
        weatherTask?.cancel()
        let requestID = UUID()
        weatherRequestID = requestID
        apply(status: .checking, effect: weatherEffect)
        weatherTask = client.fetchCurrent(at: coordinate) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.isEnabled,
                      self.weatherRequestID == requestID
                else {
                    return
                }
                self.weatherTask = nil
                self.weatherRequestID = nil
                switch result {
                case let .success(observation):
                    self.defaults.set(observation.effect.rawValue, forKey: Key.effect)
                    self.defaults.set(observation.isRaining, forKey: Key.raining)
                    self.defaults.set(Date().timeIntervalSince1970, forKey: Key.weatherUpdatedAt)
                    let nextStatus: WeatherLinkStatus
                    switch observation.effect {
                    case .none: nextStatus = .dry
                    case .rain: nextStatus = .raining
                    case .snow: nextStatus = .snowing
                    }
                    self.apply(
                        status: nextStatus,
                        effect: observation.effect
                    )
                case .failure:
                    if let cachedEffect = self.freshCachedEffect() {
                        self.apply(status: .unavailable, effect: cachedEffect)
                    } else {
                        self.apply(status: .unavailable, effect: .none)
                    }
                }
            }
        }
    }

    private func scheduleRefreshTimer() {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cachedCoordinate() -> CoarseWeatherCoordinate? {
        guard
            defaults.object(forKey: Key.latitude) != nil,
            defaults.object(forKey: Key.longitude) != nil
        else {
            return nil
        }
        return CoarseWeatherCoordinate(
            latitude: defaults.double(forKey: Key.latitude),
            longitude: defaults.double(forKey: Key.longitude)
        )
    }

    private func locationCacheIsFresh() -> Bool {
        let timestamp = defaults.double(forKey: Key.locationUpdatedAt)
        return timestamp > 0 && Date().timeIntervalSince1970 - timestamp < Self.locationRefreshInterval
    }

    private func freshCachedEffect() -> WeatherEffect? {
        let timestamp = defaults.double(forKey: Key.weatherUpdatedAt)
        guard timestamp > 0,
              Date().timeIntervalSince1970 - timestamp < Self.weatherCacheLifetime
        else {
            return nil
        }
        if let rawValue = defaults.string(forKey: Key.effect),
           let effect = WeatherEffect(rawValue: rawValue) {
            return effect
        }
        return defaults.bool(forKey: Key.raining) ? .rain : WeatherEffect.none
    }

    private func restoreFreshWeatherCache() {
        guard let cachedEffect = freshCachedEffect() else { return }
        let cachedStatus: WeatherLinkStatus
        switch cachedEffect {
        case .none: cachedStatus = .dry
        case .rain: cachedStatus = .raining
        case .snow: cachedStatus = .snowing
        }
        apply(status: cachedStatus, effect: cachedEffect)
    }

    private func apply(status: WeatherLinkStatus, effect: WeatherEffect) {
        self.status = status
        weatherEffect = effect
        onChange?(status, effect)
    }
}
