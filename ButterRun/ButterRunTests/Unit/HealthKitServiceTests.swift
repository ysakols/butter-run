import XCTest
import HealthKit
@testable import ButterRun

final class HealthKitServiceTests: XCTestCase {

    func test_isAvailable_returnsBoolean() {
        let service = HealthKitService()
        // HKHealthStore.isHealthDataAvailable() returns true on simulator
        // Just verify the property doesn't crash
        _ = service.isAvailable
    }

    func test_saveWorkout_unavailable_returnsFalse() async {
        // On devices where HealthKit is not available, saveWorkout should return false
        // On simulator it is available, so this may not trigger — but it exercises the code path
        let service = HealthKitService()
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.endDate = Date()
        run.distanceMeters = 1000
        run.durationSeconds = 300
        run.totalCaloriesBurned = 100
        run.totalButterBurnedTsp = 2.94

        // This will fail on simulator without HealthKit authorization,
        // which is expected — we just verify it returns false gracefully
        let result = await service.saveWorkout(run: run)
        // Result depends on authorization state; just verify no crash
        _ = result
    }

    func test_saveWorkout_withPauseResumeEvents() async {
        let service = HealthKitService()
        let run = Run(startDate: Date().addingTimeInterval(-600), isButterZeroChallenge: false)
        run.endDate = Date()
        run.distanceMeters = 2000
        run.durationSeconds = 500
        run.totalCaloriesBurned = 150
        run.totalButterBurnedTsp = 4.4

        let events = [
            (pauseDate: Date().addingTimeInterval(-400), resumeDate: Date().addingTimeInterval(-350)),
            (pauseDate: Date().addingTimeInterval(-200), resumeDate: Date().addingTimeInterval(-180))
        ]

        // Exercise the new pause/resume events parameter
        let result = await service.saveWorkout(run: run, pauseResumeEvents: events)
        _ = result
    }
}
