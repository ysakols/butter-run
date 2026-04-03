import Foundation
import CoreMotion
import Combine

class MotionService: NSObject, ObservableObject, MotionTracking {
    private let pedometer = CMPedometer()
    private var isTracking = false

    @Published var currentCadence: Double = 0
    @Published var stepCount: Int = 0
    @Published var isAvailable: Bool = false

    override init() {
        super.init()
        isAvailable = CMPedometer.isStepCountingAvailable()
    }

    func startTracking() {
        guard CMPedometer.isCadenceAvailable() || CMPedometer.isStepCountingAvailable() else {
            return
        }

        isTracking = true
        pedometer.startUpdates(from: .now) { [weak self] data, error in
            guard let data = data, error == nil else { return }

            DispatchQueue.main.async {
                guard let self, self.isTracking else { return }
                self.stepCount = data.numberOfSteps.intValue

                if let cadence = data.currentCadence {
                    // Convert from steps/second to steps/minute
                    self.currentCadence = cadence.doubleValue * 60.0
                }
            }
        }
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        pedometer.stopUpdates()
        currentCadence = 0
        stepCount = 0
    }
}
