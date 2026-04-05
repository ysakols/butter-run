import XCTest
import Combine
@testable import ButterRun

final class AutoPauseServiceTests: XCTestCase {
    var service: AutoPauseService!
    var cancellables: Set<AnyCancellable>!
    var currentTime: Date!

    override func setUp() {
        super.setUp()
        currentTime = Date()
        service = AutoPauseService(now: { [unowned self] in self.currentTime })
        service.isEnabled = true
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        service = nil
        currentTime = nil
        super.tearDown()
    }

    func test_triggersPauseAfter10Seconds() {
        var events: [AutoPauseEvent] = []
        service.eventPublisher.sink { events.append($0) }.store(in: &cancellables)

        // Feed slow speed updates, advancing time by 1 second each
        for _ in 0..<11 {
            currentTime = currentTime.addingTimeInterval(1.0)
            service.updateSpeed(0.3) // Below 0.5 m/s threshold
        }

        XCTAssertTrue(service.isPaused, "Service should be paused after 10+ seconds below speed threshold")
        XCTAssertTrue(events.contains(.autoPaused), "Should have emitted autoPaused event")
    }

    func test_doesNotPauseAt9Seconds() {
        var events: [AutoPauseEvent] = []
        service.eventPublisher.sink { events.append($0) }.store(in: &cancellables)

        for _ in 0..<9 {
            currentTime = currentTime.addingTimeInterval(1.0)
            service.updateSpeed(0.3)
        }

        XCTAssertFalse(service.isPaused, "Service should NOT be paused after only 9 seconds")
        XCTAssertTrue(events.isEmpty, "Should not have emitted any events")
    }

    func test_resumeAboveThreshold() {
        var events: [AutoPauseEvent] = []
        service.eventPublisher.sink { events.append($0) }.store(in: &cancellables)

        // First trigger a pause (11 seconds of slow speed)
        for _ in 0..<12 {
            currentTime = currentTime.addingTimeInterval(1.0)
            service.updateSpeed(0.3)
        }
        XCTAssertTrue(service.isPaused)

        // Now send fast speed to trigger resume
        service.updateSpeed(1.0) // Above 0.8 m/s threshold

        XCTAssertFalse(service.isPaused, "Service should have resumed")
        XCTAssertTrue(events.contains(.autoResumed), "Should have emitted autoResumed event")
    }

    func test_doesNotPauseWhenDisabled() {
        service.isEnabled = false
        var events: [AutoPauseEvent] = []
        service.eventPublisher.sink { events.append($0) }.store(in: &cancellables)

        for _ in 0..<20 {
            currentTime = currentTime.addingTimeInterval(1.0)
            service.updateSpeed(0.1)
        }

        XCTAssertFalse(service.isPaused)
        XCTAssertTrue(events.isEmpty)
    }

    func test_reset() {
        // Trigger a pause first
        for _ in 0..<12 {
            currentTime = currentTime.addingTimeInterval(1.0)
            service.updateSpeed(0.2)
        }
        XCTAssertTrue(service.isPaused)

        service.reset()
        XCTAssertFalse(service.isPaused)
    }

    func test_speedRecoveryResetsSlowtimer() {
        // Start with slow speed
        service.updateSpeed(0.3)

        // Advance 5 seconds
        currentTime = currentTime.addingTimeInterval(5.0)
        service.updateSpeed(0.3)

        // Recover to fast speed (resets the slow timer)
        service.updateSpeed(2.0)

        // Go slow again and advance another 5 seconds — should NOT pause
        // because the timer was reset by the fast speed
        currentTime = currentTime.addingTimeInterval(5.0)
        service.updateSpeed(0.3)

        XCTAssertFalse(service.isPaused, "Timer should have been reset by speed recovery")
    }
}
