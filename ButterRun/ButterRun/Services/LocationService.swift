import Foundation
import CoreLocation
import Combine

enum GPSSignalState {
    case strong
    case weak
    case lost
}

protocol LocationTracking: AnyObject {
    var totalDistanceMeters: Double { get }
    var currentSpeedMps: Double { get }
    var elevationGainMeters: Double { get }
    var elevationLossMeters: Double { get }
    var locationPublisher: AnyPublisher<CLLocation, Never> { get }
    var gpsSignalState: GPSSignalState { get }
    func requestPermission()
    func startTracking()
    func stopTracking()
    func pauseTracking()
    func resumeTracking()
    func encodeRoute() -> Data?
}

class LocationService: NSObject, ObservableObject, LocationTracking {
    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published private(set) var gpsSignalState: GPSSignalState = .strong

    // Run tracking state
    private(set) var locations: [CLLocation] = []
    private(set) var totalDistanceMeters: Double = 0
    private(set) var currentSpeedMps: Double = 0
    private(set) var elevationGainMeters: Double = 0
    private(set) var elevationLossMeters: Double = 0

    private var previousLocation: CLLocation?
    private var previousAltitude: Double?
    private var weakSignalStart: Date?

    private let _locationSubject = PassthroughSubject<CLLocation, Never>()
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        _locationSubject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        locations = []
        totalDistanceMeters = 0
        currentSpeedMps = 0
        elevationGainMeters = 0
        elevationLossMeters = 0
        previousLocation = nil
        previousAltitude = nil
        weakSignalStart = nil
        gpsSignalState = .strong
        isTracking = true

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func pauseTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func resumeTracking() {
        isTracking = true
        previousLocation = locations.last
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

    func encodeRoute() -> Data? {
        let coords = locations.map { [$0.coordinate.latitude, $0.coordinate.longitude] }
        return try? JSONEncoder().encode(coords)
    }

    static func decodeRoute(_ data: Data) -> [CLLocationCoordinate2D] {
        guard let coords = try? JSONDecoder().decode([[Double]].self, from: data) else {
            return []
        }
        return coords.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isTracking else { return }

            for location in newLocations {
                // GPS signal quality check
                if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 50 {
                    if self.weakSignalStart == nil {
                        self.weakSignalStart = Date()
                    }
                    if let start = self.weakSignalStart,
                       Date().timeIntervalSince(start) > 10 {
                        self.gpsSignalState = .weak
                    }
                    continue
                }

                // Signal recovered
                self.weakSignalStart = nil
                self.gpsSignalState = .strong

                // Filter out inaccurate readings for distance calculation
                guard location.horizontalAccuracy < 20 else { continue }

                // Calculate distance from previous point
                if let previous = self.previousLocation {
                    let delta = location.distance(from: previous)
                    if delta < 100 {
                        self.totalDistanceMeters += delta
                    }
                }

                // Speed
                if location.speed >= 0 {
                    self.currentSpeedMps = location.speed
                } else if let previous = self.previousLocation {
                    let timeDelta = location.timestamp.timeIntervalSince(previous.timestamp)
                    if timeDelta > 0 {
                        self.currentSpeedMps = location.distance(from: previous) / timeDelta
                    }
                }

                // Elevation tracking
                if location.verticalAccuracy >= 0 {
                    if let prevAlt = self.previousAltitude {
                        let altDelta = location.altitude - prevAlt
                        if altDelta > 0 {
                            self.elevationGainMeters += altDelta
                        } else {
                            self.elevationLossMeters += abs(altDelta)
                        }
                    }
                    self.previousAltitude = location.altitude
                }

                self.locations.append(location)
                self.previousLocation = location
                self.currentLocation = location
                self._locationSubject.send(location)
            }
        }
    }
}
