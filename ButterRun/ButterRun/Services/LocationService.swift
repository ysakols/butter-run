import Foundation
import CoreLocation
import Combine

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
    @Published private(set) var isAuthDenied: Bool = false

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
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func pauseTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func resumeTracking() {
        isTracking = true
        previousLocation = locations.last
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
    }

    func encodeRoute() -> Data? {
        let simplified = simplifyRoute(locations, maxPoints: 5000)
        let coords = simplified.map { [$0.coordinate.latitude, $0.coordinate.longitude] }
        return try? JSONEncoder().encode(coords)
    }

    // MARK: - Route Simplification (Douglas-Peucker)

    private func simplifyRoute(_ points: [CLLocation], maxPoints: Int) -> [CLLocation] {
        guard points.count > maxPoints else { return points }
        let epsilon = findEpsilon(points: points, targetCount: maxPoints)
        return douglasPeucker(points, epsilon: epsilon)
    }

    private func findEpsilon(points: [CLLocation], targetCount: Int) -> Double {
        var lo = 0.0, hi = 100.0
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            let simplified = douglasPeucker(points, epsilon: mid)
            if simplified.count > targetCount {
                lo = mid
            } else {
                hi = mid
            }
        }
        return hi
    }

    private func douglasPeucker(_ points: [CLLocation], epsilon: Double) -> [CLLocation] {
        guard points.count > 2 else { return points }
        var maxDist = 0.0
        var index = 0
        let first = points.first!, last = points.last!
        for i in 1..<(points.count - 1) {
            let d = perpendicularDistance(point: points[i], lineStart: first, lineEnd: last)
            if d > maxDist {
                maxDist = d
                index = i
            }
        }
        if maxDist > epsilon {
            let left = douglasPeucker(Array(points[0...index]), epsilon: epsilon)
            let right = douglasPeucker(Array(points[index...]), epsilon: epsilon)
            return Array(left.dropLast()) + right
        } else {
            return [first, last]
        }
    }

    private func perpendicularDistance(point: CLLocation, lineStart: CLLocation, lineEnd: CLLocation) -> Double {
        let a = point.distance(from: lineStart)
        let b = point.distance(from: lineEnd)
        let c = lineStart.distance(from: lineEnd)
        guard c > 0 else { return a }
        let s = (a + b + c) / 2
        let area = sqrt(max(0, s * (s - a) * (s - b) * (s - c)))
        return (2 * area) / c
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
            self?.isAuthDenied = (manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted)
        }
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // iOS paused updates due to battery pressure — surface GPS lost state
        DispatchQueue.main.async { [weak self] in
            self?.gpsSignalState = .lost
        }
        // Re-enable updates immediately since we need continuous tracking for running
        manager.startUpdatingLocation()
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
                    if let start = self.weakSignalStart {
                        let elapsed = Date().timeIntervalSince(start)
                        if elapsed > 60 {
                            self.gpsSignalState = .lost
                        } else if elapsed > 10 {
                            self.gpsSignalState = .weak
                        }
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
