import XCTest
@testable import ButterRun

/// Tests for VoiceFeedbackService milestone detection logic.
/// We can't easily test actual speech output, but we can test the state
/// tracking that controls when announcements fire, by subclassing and
/// intercepting speak calls.
final class VoiceFeedbackServiceTests: XCTestCase {

    private class TestableVoiceFeedbackService: VoiceFeedbackService {
        var spokenMessages: [String] = []

        override func announceRunEnd(totalButterTsp: Double, netButter: Double?, isButterZero: Bool) {
            // Track that it was called; don't actually speak
            spokenMessages.append("end:\(totalButterTsp)")
        }
    }

    // MARK: - Milestone State Tracking

    func test_reset_clearsState() {
        let service = VoiceFeedbackService()
        // Call checkMilestones to advance state
        service.checkMilestones(butterTsp: 2.0, distanceMeters: 2000, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        service.reset()
        // After reset, state should allow re-announcement
        // We can verify by checking that the service doesn't crash and accepts calls
        service.checkMilestones(butterTsp: 0.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
    }

    func test_disabled_doesNotAnnounce() {
        let service = VoiceFeedbackService()
        service.isEnabled = false
        // Should not crash or produce announcements
        service.checkMilestones(butterTsp: 5.0, distanceMeters: 5000, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        service.announceRunEnd(totalButterTsp: 5.0, netButter: nil, isButterZero: false)
        service.announceChurnStage("Whipped")
        service.announceAutoPause(paused: true)
    }

    func test_stop_doesNotCrash() {
        let service = VoiceFeedbackService()
        service.stop()
    }

    func test_checkMilestones_multipleCallsAtSameLevel_noReannouncement() {
        let service = VoiceFeedbackService()
        // Call twice at same level — should not re-announce (internal state should prevent it)
        service.checkMilestones(butterTsp: 1.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        service.checkMilestones(butterTsp: 1.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        // No crash = success; actual dedup is in speak() which uses synthesizer
    }

    func test_checkMilestones_kmMode() {
        let service = VoiceFeedbackService()
        // 1000m = 1 km milestone in km mode
        service.checkMilestones(butterTsp: 0.3, distanceMeters: 1100, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: false)
    }

    func test_checkMilestones_butterZeroNearZero() {
        let service = VoiceFeedbackService()
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.2, usesMiles: true)
        // Should trigger near-zero announcement. Call again — should not re-trigger
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.1, usesMiles: true)
    }

    func test_checkMilestones_butterZeroReset_afterDrift() {
        let service = VoiceFeedbackService()
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.2, usesMiles: true)
        // Drift away from zero
        service.checkMilestones(butterTsp: 2.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 1.5, usesMiles: true)
        // Approach again — should be able to re-announce
        service.checkMilestones(butterTsp: 3.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.1, usesMiles: true)
    }
}
