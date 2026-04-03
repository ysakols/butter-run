import UIKit

protocol HapticFeedback {
    func splitCompleted()
    func butterZeroCrossing()
    func churnStageAdvanced()
    func runFinished()
}

class HapticService: HapticFeedback {
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    init() {
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
    }

    func splitCompleted() {
        impactMedium.impactOccurred()
    }

    func butterZeroCrossing() {
        notification.notificationOccurred(.success)
    }

    func churnStageAdvanced() {
        impactHeavy.impactOccurred()
    }

    func runFinished() {
        notification.notificationOccurred(.success)
    }
}
