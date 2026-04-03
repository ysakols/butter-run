import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false

    // Run tracking state
    private(set) var locations: [CLLocation] = []
    private(set) var totalDistanceMeters: Double = 0
    private(set) var currentSpeedMps: Double = 0
    private(set) var elevationGainMeters: Double = 0
    private(set) var elevationLossMeters: Double = 0

    private var previousLocation: CLLocation?
    private var previousAltitude: Double?

    let locationPublisher = PassthroughSubject<CLLocation, Never>()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // meters — balances accuracy vs battery
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
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
        isTracking = true
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }

    func pauseTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }

    func resumeTracking() {
        isTracking = true
        previousLocation = locations.last
        locationManager.startUpdatingLocation()
    }

    /// Encode route as a simple array of lat/lon pairs for persistence.
    func encodeRoute() -> Data? {
        let coords = locations.map { [$0.coordinate.latitude, $0.coordinate.longitude] }
        return try? JSONEncoder().encode(coords)
    }

    /// Decode stored route data back to coordinates.
    static func decodeRoute(_ data: Data) -> [CLLocationCoordinate2D] {
        guard let coords = try? JSONDecoder().decode([[Double]].self, from: data) else {
            return []
        }
        return coords.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
        guard isTracking else { return }

        for location in newLocations {
            // Filter out inaccurate readings
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 20 else {
                continue
            }

            // Calculate distance from previous point
            if let previous = previousLocation {
                let delta = location.distance(from: previous)
                // Sanity check: ignore teleports (> 100m between 5m filter updates)
                if delta < 100 {
                    totalDistanceMeters += delta
                }
            }

            // Speed (use GPS speed if available, else calculate)
            if location.speed >= 0 {
                currentSpeedMps = location.speed
            } else if let previous = previousLocation {
                let timeDelta = location.timestamp.timeIntervalSince(previous.timestamp)
                if timeDelta > 0 {
                    currentSpeedMps = location.distance(from: previous) / timeDelta
                }
            }

            // Elevation tracking
            if location.verticalAccuracy >= 0 {
                if let prevAlt = previousAltitude {
                    let altDelta = location.altitude - prevAlt
                    if altDelta > 0 {
                        elevationGainMeters += altDelta
                    } else {
                        elevationLossMeters += abs(altDelta)
                    }
                }
                previousAltitude = location.altitude
            }

            locations.append(location)
            previousLocation = location
            currentLocation = location
            locationPublisher.send(location)
        }
    }
}
