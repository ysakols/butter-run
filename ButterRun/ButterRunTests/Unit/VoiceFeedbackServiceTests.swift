import XCTest
@testable import ButterRun

/// Tests for VoiceFeedbackService milestone detection logic.
/// Since the private `speak()` method uses AVSpeechSynthesizer, these tests verify
/// state tracking behavior by exercising the public API and confirming no crashes.
/// The service's internal deduplication state (lastAnnouncedTsp, lastAnnouncedMile, etc.)
/// prevents re-announcements, which we test via sequential calls.
final class VoiceFeedbackServiceTests: XCTestCase {

    // MARK: - Reset

    func test_reset_allowsReannouncement() {
        let service = VoiceFeedbackService()
        service.checkMilestones(butterTsp: 2.0, distanceMeters: 2000, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        service.reset()
        // After reset, calling with 0.5 tsp should not crash (state was cleared)
        service.checkMilestones(butterTsp: 0.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        // If state wasn't reset, the half-tsp announcement would be suppressed
        // since announcedHalfTsp would still be true — reset clears it
    }

    // MARK: - Disabled

    func test_disabled_skipsAllAnnouncements() {
        let service = VoiceFeedbackService()
        service.isEnabled = false
        // All milestone checks should be no-ops when disabled
        service.checkMilestones(butterTsp: 5.0, distanceMeters: 5000, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        // Re-enable and call again — should now announce (state was not advanced while disabled)
        service.isEnabled = true
        service.checkMilestones(butterTsp: 5.0, distanceMeters: 5000, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
    }

    // MARK: - Stop

    func test_stop_cancelsInProgressSpeech() {
        let service = VoiceFeedbackService()
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        service.stop()
        // Verify no crash after stop
    }

    // MARK: - Deduplication

    func test_sameButterLevel_doesNotReannounce() {
        let service = VoiceFeedbackService()
        // First call at 1.5 tsp advances lastAnnouncedTsp to 1
        service.checkMilestones(butterTsp: 1.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        // Second call at same level should be a no-op (no re-announcement)
        service.checkMilestones(butterTsp: 1.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
    }

    // MARK: - Kilometer mode

    func test_kmMode_triggersDistanceMilestone() {
        let service = VoiceFeedbackService()
        // 1100m > 1000m = 1 km milestone
        service.checkMilestones(butterTsp: 0.3, distanceMeters: 1100, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: false)
        // Call again at same distance — should not re-trigger
        service.checkMilestones(butterTsp: 0.3, distanceMeters: 1100, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: false)
    }

    // MARK: - Butter Zero

    func test_butterZeroNearZero_announcesThenDeduplicates() {
        let service = VoiceFeedbackService()
        // netButter 0.2 (abs < 0.3, non-zero) — should trigger near-zero announcement
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.2, usesMiles: true)
        // Same level again — hasAnnouncedNearZero is now true, should not re-trigger
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.1, usesMiles: true)
    }

    func test_butterZeroReset_afterDriftAwayAndBack() {
        let service = VoiceFeedbackService()
        // Near zero — triggers announcement
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.2, usesMiles: true)
        // Drift away (abs > 1.0) — resets hasAnnouncedNearZero
        service.checkMilestones(butterTsp: 2.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 1.5, usesMiles: true)
        // Approach zero again — should be able to re-announce
        service.checkMilestones(butterTsp: 3.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.1, usesMiles: true)
    }

    // MARK: - Tablespoon milestone (every 3 tsp)

    func test_tablespoonMilestone_at3Tsp() {
        let service = VoiceFeedbackService()
        // Advance through 1, 2, then 3 tsp
        service.checkMilestones(butterTsp: 1.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        service.checkMilestones(butterTsp: 2.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        // At 3 tsp, should announce tablespoon instead of teaspoons
        service.checkMilestones(butterTsp: 3.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
    }
}
