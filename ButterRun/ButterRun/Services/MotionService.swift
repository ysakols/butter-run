import Foundation
import CoreMotion
import Combine

protocol MotionTracking: AnyObject {
    var currentCadence: Double { get }
    var stepCount: Int { get }
    var isAvailable: Bool { get }
    func startTracking()
    func stopTracking()
}

class MotionService: NSObject, ObservableObject, MotionTracking {
    private let pedometer = CMPedometer()

    @Published var currentCadence: Double = 0
    @Published var stepCount: Int = 0
    @Published var isAvailable: Bool = false

    override init() {
        super.init()
        isAvailable = CMPedometer.isPedometerEventMonitoringAvailable()
    }

    func startTracking() {
        guard CMPedometer.isCadenceAvailable() || CMPedometer.isStepCountingAvailable() else {
            return
        }

        pedometer.startUpdates(from: .now) { [weak self] data, error in
            guard let data = data, error == nil else { return }

            DispatchQueue.main.async {
                self?.stepCount = data.numberOfSteps.intValue

                if let cadence = data.currentCadence {
                    self?.currentCadence = cadence.doubleValue * 60.0
                }
            }
        }
    }

    func stopTracking() {
        pedometer.stopUpdates()
        currentCadence = 0
        stepCount = 0
    }
}
