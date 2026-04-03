import Foundation
import CoreMotion
import Combine

class MotionService: ObservableObject {
    private let pedometer = CMPedometer()

    @Published var currentCadence: Double = 0  // steps per minute
    @Published var stepCount: Int = 0
    @Published var isAvailable: Bool = false

    init() {
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
                    // CoreMotion cadence is steps/second, convert to steps/minute
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
