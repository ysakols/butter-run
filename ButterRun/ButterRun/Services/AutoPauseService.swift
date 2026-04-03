import Foundation
import Combine

enum AutoPauseEvent {
    case autoPaused
    case autoResumed
}

class AutoPauseService: ObservableObject {
    @Published private(set) var isPaused = false

    var isEnabled = true

    private let pauseSpeedThreshold: Double = 0.5   // m/s
    private let resumeSpeedThreshold: Double = 0.8   // m/s
    private let pauseDelay: TimeInterval = 10.0      // seconds

    private var slowStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    let eventPublisher = PassthroughSubject<AutoPauseEvent, Never>()

    func updateSpeed(_ speedMps: Double) {
        guard isEnabled else { return }

        if isPaused {
            // Check for resume
            if speedMps > resumeSpeedThreshold {
                isPaused = false
                slowStartTime = nil
                eventPublisher.send(.autoResumed)
            }
        } else {
            // Check for pause
            if speedMps < pauseSpeedThreshold {
                if slowStartTime == nil {
                    slowStartTime = Date()
                }
                if let start = slowStartTime,
                   Date().timeIntervalSince(start) >= pauseDelay {
                    isPaused = true
                    eventPublisher.send(.autoPaused)
                }
            } else {
                slowStartTime = nil
            }
        }
    }

    func reset() {
        isPaused = false
        slowStartTime = nil
    }
}
