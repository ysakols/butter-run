import XCTest
import Combine
@testable import ButterRun

final class AutoPauseServiceTests: XCTestCase {
    var service: AutoPauseService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        service = AutoPauseService()
        service.isEnabled = true
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        service = nil
        super.tearDown()
    }

    func test_triggersPauseAfter10Seconds() {
        var events: [AutoPauseEvent] = []
        service.eventPublisher.sink { events.append($0) }.store(in: &cancellables)

        let expectation = expectation(description: "Auto-pause triggers")

        // Feed slow speed updates at 1-second intervals for 11 seconds
        // The service uses Date() internally, so we need real elapsed time
        DispatchQueue.global().async {
            for i in 0..<12 {
                Thread.sleep(forTimeInterval: 1.0)
                DispatchQueue.main.sync {
                    self.service.updateSpeed(0.3) // Below 0.5 m/s threshold
                }
                if i >= 10 {
                    expectation.fulfill()
                    break
                }
            }
        }

        wait(for: [expectation], timeout: 15.0)

        XCTAssertTrue(service.isPaused, "Service should be paused after 10+ seconds below speed threshold")
        XCTAssertTrue(events.contains(.autoPaused), "Should have emitted autoPaused event")
    }

    func test_doesNotPauseAt9Seconds() {
        var events: [AutoPauseEvent] = []
        service.eventPublisher.sink { events.append($0) }.store(in: &cancellables)

        let expectation = expectation(description: "Wait 9 seconds")

        DispatchQueue.global().async {
            for _ in 0..<9 {
                Thread.sleep(forTimeInterval: 1.0)
                DispatchQueue.main.sync {
                    self.service.updateSpeed(0.3)
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 12.0)

        XCTAssertFalse(service.isPaused, "Service should NOT be paused after only 9 seconds")
        XCTAssertTrue(events.isEmpty, "Should not have emitted any events")
    }

    func test_resumeAboveThreshold() {
        var events: [AutoPauseEvent] = []
        service.eventPublisher.sink { events.append($0) }.store(in: &cancellables)

        let expectation = expectation(description: "Pause then resume")

        DispatchQueue.global().async {
            // First trigger a pause (11 seconds of slow speed)
            for _ in 0..<12 {
                Thread.sleep(forTimeInterval: 1.0)
                DispatchQueue.main.sync {
                    self.service.updateSpeed(0.3)
                }
            }

            // Now send fast speed to trigger resume
            DispatchQueue.main.sync {
                self.service.updateSpeed(1.0) // Above 0.8 m/s threshold
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 16.0)

        XCTAssertFalse(service.isPaused, "Service should have resumed")
        XCTAssertTrue(events.contains(.autoResumed), "Should have emitted autoResumed event")
    }

    func test_doesNotPauseWhenDisabled() {
        service.isEnabled = false
        var events: [AutoPauseEvent] = []
        service.eventPublisher.sink { events.append($0) }.store(in: &cancellables)

        // Even with many slow speed updates, should not pause when disabled
        for _ in 0..<20 {
            service.updateSpeed(0.1)
        }

        XCTAssertFalse(service.isPaused)
        XCTAssertTrue(events.isEmpty)
    }

    func test_reset() {
        service.updateSpeed(0.2)
        service.reset()
        XCTAssertFalse(service.isPaused)
    }

    func test_speedRecoveryResetsSlowtimer() {
        // Start with slow speed
        service.updateSpeed(0.3)

        // Then recover to fast speed (resets the slow timer)
        service.updateSpeed(2.0)

        // Then go slow again — should need another 10 seconds
        service.updateSpeed(0.3)

        // Should not be paused since the slow timer was reset
        XCTAssertFalse(service.isPaused)
    }
}
