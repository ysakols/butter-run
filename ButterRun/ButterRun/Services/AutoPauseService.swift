import Foundation
import Combine

enum AutoPauseEvent {
    case autoPaused
    case autoResumed
}

/// Detects when a runner stops moving and automatically pauses/resumes the run.
///
/// Uses hysteresis to prevent spurious toggling: pauses when speed stays below 0.5 m/s
/// (≈1.1 mph) for 10 seconds, resumes immediately when speed exceeds 0.8 m/s (≈1.8 mph).
/// The higher resume threshold prevents rapid pause/resume cycles from GPS speed fluctuations
/// near the pause boundary.
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
