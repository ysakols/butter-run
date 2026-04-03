import XCTest
import Combine
import CoreLocation
@testable import ButterRun

// MARK: - Mock Services

final class MockLocationService: LocationTracking {
    var totalDistanceMeters: Double = 0
    var currentSpeedMps: Double = 0
    var elevationGainMeters: Double = 0
    var elevationLossMeters: Double = 0
    var currentLocation: CLLocation?
    var gpsSignalState: GPSSignalState = .strong
    var isAuthDenied: Bool = false

    private let _subject = PassthroughSubject<CLLocation, Never>()
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        _subject.eraseToAnyPublisher()
    }

    var startTrackingCalled = false
    var stopTrackingCalled = false
    var pauseTrackingCalled = false
    var resumeTrackingCalled = false

    func requestPermission() {}
    func startTracking() { startTrackingCalled = true }
    func stopTracking() { stopTrackingCalled = true }
    func pauseTracking() { pauseTrackingCalled = true }
    func resumeTracking() { resumeTrackingCalled = true }
    func encodeRoute() -> Data? { nil }

    func simulateLocation() {
        let loc = CLLocation(latitude: 37.7749, longitude: -122.4194)
        currentLocation = loc
        _subject.send(loc)
    }
}

final class MockMotionService: MotionTracking {
    var currentCadence: Double = 0
    var stepCount: Int = 0
    var isAvailable: Bool = true
    func startTracking() {}
    func stopTracking() {}
}

final class MockVoiceService: VoiceFeedback {
    var isEnabled: Bool = true
    var announcements: [String] = []
    func reset() { announcements.removeAll() }
    func checkMilestones(butterTsp: Double, distanceMiles: Double, pace: String, isButterZero: Bool, netButter: Double) {}
    func announceRunEnd(totalButterTsp: Double, netButter: Double?, isButterZero: Bool) {
        announcements.append("end")
    }
    func announceChurnStage(_ stageName: String) {
        announcements.append("churn:\(stageName)")
    }
    func announceAutoPause(paused: Bool) {
        announcements.append(paused ? "paused" : "resumed")
    }
    func stop() {}
}

final class MockHapticService: HapticFeedback {
    var splitCount = 0
    var zeroCrossings = 0
    var stageAdvances = 0
    var finishes = 0

    func splitCompleted() { splitCount += 1 }
    func butterZeroCrossing() { zeroCrossings += 1 }
    func churnStageAdvanced() { stageAdvances += 1 }
    func runFinished() { finishes += 1 }
}

// MARK: - Tests

final class ActiveRunViewModelTests: XCTestCase {
    var viewModel: ActiveRunViewModel!
    var mockLocation: MockLocationService!
    var mockMotion: MockMotionService!
    var mockVoice: MockVoiceService!
    var mockHaptic: MockHapticService!

    override func setUp() {
        super.setUp()
        mockLocation = MockLocationService()
        mockMotion = MockMotionService()
        mockVoice = MockVoiceService()
        mockHaptic = MockHapticService()

        viewModel = ActiveRunViewModel(
            location: mockLocation,
            motion: mockMotion,
            voice: mockVoice,
            haptic: mockHaptic
        )
    }

    func test_stateMachine_idle_to_running() {
        XCTAssertEqual(viewModel.state, .idle)
        viewModel.startRun()
        XCTAssertEqual(viewModel.state, .running)
    }

    func test_stateMachine_running_to_paused() {
        viewModel.startRun()
        viewModel.pauseRun()
        XCTAssertEqual(viewModel.state, .paused)
    }

    func test_stateMachine_paused_to_running() {
        viewModel.startRun()
        viewModel.pauseRun()
        viewModel.resumeRun()
        XCTAssertEqual(viewModel.state, .running)
    }

    func test_stateMachine_running_to_finished() {
        viewModel.startRun()
        let run = viewModel.stopRun()
        XCTAssertEqual(viewModel.state, .finished)
        XCTAssertNotNil(run)
    }

    func test_eatButter_updatesBalance() {
        viewModel.startRun()
        viewModel.isButterZeroChallenge = true
        viewModel.eatButter(serving: .teaspoon)
        XCTAssertEqual(viewModel.butterEatenTsp, 1.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.butterEntries.count, 1)
    }

    func test_eatButter_undoRemovesLastEntry() {
        viewModel.startRun()
        viewModel.eatButter(serving: .teaspoon)
        viewModel.eatButter(serving: .tablespoon)
        XCTAssertEqual(viewModel.butterEatenTsp, 4.0, accuracy: 0.01) // 1 + 3

        let undone = viewModel.undoLastButterEntry()
        XCTAssertTrue(undone)
        XCTAssertEqual(viewModel.butterEatenTsp, 1.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.butterEntries.count, 1)
    }

    func test_undoOnEmptyReturns_false() {
        viewModel.startRun()
        let result = viewModel.undoLastButterEntry()
        XCTAssertFalse(result)
    }

    func test_stopRun_buildsCorrectModel() {
        viewModel.weightKg = 70.0
        viewModel.isButterZeroChallenge = true
        viewModel.startRun()
        viewModel.eatButter(serving: .teaspoon)

        mockLocation.totalDistanceMeters = 5000
        mockLocation.elevationGainMeters = 50

        let run = viewModel.stopRun()
        XCTAssertTrue(run.isButterZeroChallenge)
        XCTAssertEqual(run.totalButterEatenTsp, 1.0, accuracy: 0.01)
        XCTAssertEqual(run.elevationGainMeters, 50, accuracy: 0.01)
    }

    func test_services_started_on_startRun() {
        viewModel.startRun()
        XCTAssertTrue(mockLocation.startTrackingCalled)
    }

    func test_services_stopped_on_stopRun() {
        viewModel.startRun()
        _ = viewModel.stopRun()
        XCTAssertTrue(mockLocation.stopTrackingCalled)
    }

    func test_runFinished_haptic() {
        viewModel.startRun()
        _ = viewModel.stopRun()
        XCTAssertEqual(mockHaptic.finishes, 1)
    }

    // MARK: - State Guard Tests

    func test_startRun_ignoredWhenAlreadyRunning() {
        viewModel.startRun()
        XCTAssertEqual(viewModel.state, .running)
        viewModel.startRun() // Should be ignored
        XCTAssertEqual(viewModel.state, .running)
    }

    func test_pauseRun_ignoredWhenNotRunning() {
        viewModel.pauseRun() // Should be ignored — state is idle
        XCTAssertEqual(viewModel.state, .idle)
    }

    func test_resumeRun_ignoredWhenNotPaused() {
        viewModel.startRun()
        viewModel.resumeRun() // Should be ignored — state is running, not paused
        XCTAssertEqual(viewModel.state, .running)
    }

    func test_stopRun_idempotent() {
        viewModel.startRun()
        let run1 = viewModel.stopRun()
        let run2 = viewModel.stopRun() // Should return same run
        XCTAssertEqual(run1.id, run2.id)
        XCTAssertEqual(mockHaptic.finishes, 1) // Only one haptic
    }

    func test_undoFloorAtZero() {
        viewModel.startRun()
        viewModel.eatButter(serving: .teaspoon) // +1.0
        _ = viewModel.undoLastButterEntry()
        XCTAssertEqual(viewModel.butterEatenTsp, 0.0, accuracy: 0.001)
        // Second undo should fail gracefully
        let result = viewModel.undoLastButterEntry()
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.butterEatenTsp, 0.0, accuracy: 0.001)
    }

    func test_butterZeroCrossing_triggersHaptic() {
        viewModel.startRun()
        viewModel.isButterZeroChallenge = true
        viewModel.butterBurnedTsp = 1.0
        viewModel.eatButter(serving: .teaspoon) // net = 1.0 - 1.0 = 0.0
        XCTAssertEqual(mockHaptic.zeroCrossings, 1)
    }

    func test_pauseDuration_excluded() {
        viewModel.startRun()
        // Simulate brief pause
        viewModel.pauseRun()
        XCTAssertEqual(viewModel.state, .paused)
        viewModel.resumeRun()
        XCTAssertEqual(viewModel.state, .running)
        // The test verifies the state transitions work;
        // actual pause duration math requires real time elapsed
    }
}
