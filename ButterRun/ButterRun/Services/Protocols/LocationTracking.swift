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
    var currentLocation: CLLocation? { get }
    var gpsSignalState: GPSSignalState { get }
    var isAuthDenied: Bool { get }
    var locationPublisher: AnyPublisher<CLLocation, Never> { get }
    func requestPermission()
    func startTracking()
    func stopTracking()
    func pauseTracking()
    func resumeTracking()
    func encodeRoute() -> Data?
    /// Async route encoding — may run heavy simplification off the main thread.
    @MainActor func encodeRouteAsync() async -> Data?
    /// Whether new route points have been added since the last encode.
    var routeIsDirty: Bool { get }
    /// Subtract drift distance accumulated during auto-pause
    func subtractDistance(_ meters: Double)
}

extension LocationTracking {
    /// Default implementation: delegates to the synchronous encodeRoute().
    @MainActor func encodeRouteAsync() async -> Data? {
        encodeRoute()
    }
}
