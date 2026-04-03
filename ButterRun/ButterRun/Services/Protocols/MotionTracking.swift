import Foundation

protocol MotionTracking: AnyObject {
    var currentCadence: Double { get }
    var stepCount: Int { get }
    var isAvailable: Bool { get }
    func startTracking()
    func stopTracking()
}
