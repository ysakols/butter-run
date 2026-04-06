import XCTest
@testable import ButterRun

/// Testable subclass that captures speech output instead of using AVSpeechSynthesizer.
private class TestableVoiceFeedbackService: VoiceFeedbackService {
    var spokenMessages: [String] = []

    override func announceForTesting(_ text: String) {
        spokenMessages.append(text)
    }
}

/// Tests for VoiceFeedbackService milestone detection logic.
final class VoiceFeedbackServiceTests: XCTestCase {

    private func makeService() -> TestableVoiceFeedbackService {
        TestableVoiceFeedbackService()
    }

    // MARK: - Half teaspoon milestone

    func test_halfTeaspoonMilestone() {
        let service = makeService()
        service.checkMilestones(butterTsp: 0.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        XCTAssertEqual(service.spokenMessages.count, 1)
        XCTAssertTrue(service.spokenMessages[0].contains("Half a teaspoon"))
    }

    // MARK: - Reset

    func test_reset_allowsReannouncement() {
        let service = makeService()
        service.checkMilestones(butterTsp: 0.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        XCTAssertEqual(service.spokenMessages.count, 1)

        service.reset()
        service.spokenMessages.removeAll()

        service.checkMilestones(butterTsp: 0.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        XCTAssertEqual(service.spokenMessages.count, 1, "Half-tsp should re-announce after reset")
    }

    // MARK: - Disabled

    func test_disabled_skipsAllAnnouncements() {
        let service = makeService()
        service.isEnabled = false
        service.checkMilestones(butterTsp: 5.0, distanceMeters: 5000, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        XCTAssertTrue(service.spokenMessages.isEmpty, "No announcements when disabled")
    }

    func test_disabled_thenReenabled_announces() {
        let service = makeService()
        service.isEnabled = false
        service.checkMilestones(butterTsp: 0.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        XCTAssertTrue(service.spokenMessages.isEmpty)

        service.isEnabled = true
        service.checkMilestones(butterTsp: 0.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        XCTAssertEqual(service.spokenMessages.count, 1, "Should announce after re-enabling")
    }

    // MARK: - Stop

    func test_stop_doesNotCrash() {
        let service = makeService()
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        service.stop()
        // Verify service is still usable after stop
        service.spokenMessages.removeAll()
        service.checkMilestones(butterTsp: 2.0, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        XCTAssertFalse(service.spokenMessages.isEmpty, "Should still announce after stop")
    }

    // MARK: - Deduplication

    func test_sameButterLevel_doesNotReannounce() {
        let service = makeService()
        service.checkMilestones(butterTsp: 1.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        let countAfterFirst = service.spokenMessages.count

        service.checkMilestones(butterTsp: 1.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        XCTAssertEqual(service.spokenMessages.count, countAfterFirst, "Same level should not re-announce")
    }

    // MARK: - Kilometer mode

    func test_kmMode_triggersDistanceMilestone() {
        let service = makeService()
        service.checkMilestones(butterTsp: 0.3, distanceMeters: 1100, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: false)
        XCTAssertTrue(service.spokenMessages.contains { $0.contains("Kilometer 1") }, "Should announce km milestone")
    }

    func test_kmMode_doesNotReannounce() {
        let service = makeService()
        service.checkMilestones(butterTsp: 0.3, distanceMeters: 1100, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: false)
        let countAfterFirst = service.spokenMessages.count

        service.checkMilestones(butterTsp: 0.3, distanceMeters: 1100, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: false)
        XCTAssertEqual(service.spokenMessages.count, countAfterFirst, "Same distance should not re-announce")
    }

    // MARK: - Mile mode

    func test_mileMode_triggersDistanceMilestone() {
        let service = makeService()
        service.checkMilestones(butterTsp: 0.3, distanceMeters: 1700, pace: "8:00", isButterZero: false, netButter: 0, usesMiles: true)
        XCTAssertTrue(service.spokenMessages.contains { $0.contains("Mile 1") }, "Should announce mile milestone")
    }

    // MARK: - Butter Zero

    func test_butterZeroNearZero_announcesThenDeduplicates() {
        let service = makeService()
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.2, usesMiles: true)
        XCTAssertTrue(service.spokenMessages.contains { $0.contains("Butter Zero") }, "Should announce near-zero")

        let countAfterFirst = service.spokenMessages.count
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.1, usesMiles: true)
        XCTAssertEqual(service.spokenMessages.count, countAfterFirst, "Should not re-announce near-zero")
    }

    func test_butterZeroReset_afterDriftAwayAndBack() {
        let service = makeService()
        // Near zero — triggers announcement
        service.checkMilestones(butterTsp: 1.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.2, usesMiles: true)
        let firstNearZeroCount = service.spokenMessages.filter { $0.contains("Butter Zero") }.count
        XCTAssertEqual(firstNearZeroCount, 1)

        // Drift away (abs > 1.0) — resets hasAnnouncedNearZero
        service.checkMilestones(butterTsp: 2.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 1.5, usesMiles: true)

        // Approach zero again — should re-announce
        service.checkMilestones(butterTsp: 3.0, distanceMeters: 0, pace: "5:00", isButterZero: true, netButter: 0.1, usesMiles: true)
        let secondNearZeroCount = service.spokenMessages.filter { $0.contains("Butter Zero") }.count
        XCTAssertEqual(secondNearZeroCount, 2, "Should re-announce after drifting away and back")
    }

    // MARK: - Tablespoon milestone (every 3 tsp)

    func test_tablespoonMilestone_at3Tsp() {
        let service = makeService()
        service.checkMilestones(butterTsp: 1.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        service.checkMilestones(butterTsp: 2.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)
        service.checkMilestones(butterTsp: 3.5, distanceMeters: 0, pace: "5:00", isButterZero: false, netButter: 0, usesMiles: true)

        XCTAssertTrue(service.spokenMessages.contains { $0.contains("tablespoon") }, "Should announce tablespoon at 3 tsp")
    }

    // MARK: - Run end announcement

    func test_announceRunEnd() {
        let service = makeService()
        service.announceRunEnd(totalButterTsp: 5.5, netButter: nil, isButterZero: false)
        XCTAssertEqual(service.spokenMessages.count, 1)
        XCTAssertTrue(service.spokenMessages[0].contains("5.5"))
        XCTAssertTrue(service.spokenMessages[0].contains("Run complete"))
    }

    func test_announceRunEnd_butterZero() {
        let service = makeService()
        service.announceRunEnd(totalButterTsp: 3.0, netButter: 0.1, isButterZero: true)
        XCTAssertEqual(service.spokenMessages.count, 1)
        XCTAssertTrue(service.spokenMessages[0].contains("Butter Zero score"))
    }
}
