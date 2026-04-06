import XCTest
import HealthKit
@testable import ButterRun

final class HealthKitServiceTests: XCTestCase {

    func test_isAvailable_returnsExpectedValue() {
        let service = HealthKitService()
        // On simulator, HealthKit is available; on macOS it may not be
        let available = service.isAvailable
        XCTAssertEqual(available, HKHealthStore.isHealthDataAvailable())
    }

    func test_saveWorkout_withoutAuthorization_returnsFalse() async throws {
        let service = HealthKitService()
        try XCTSkipUnless(service.isAvailable, "HealthKit not available on this platform")
        try XCTSkipUnless(HealthKitService.hasHealthKitEntitlement(), "HealthKit entitlement not present")
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.endDate = Date()
        run.distanceMeters = 1000
        run.durationSeconds = 300
        run.totalCaloriesBurned = 100
        run.totalButterBurnedTsp = 2.94

        // Without HealthKit authorization, saveWorkout should fail gracefully
        let result = await service.saveWorkout(run: run)
        XCTAssertFalse(result, "saveWorkout should return false without authorization")
    }

    func test_saveWorkout_withPauseResumeEvents_returnsFalse() async throws {
        let service = HealthKitService()
        try XCTSkipUnless(service.isAvailable, "HealthKit not available on this platform")
        try XCTSkipUnless(HealthKitService.hasHealthKitEntitlement(), "HealthKit entitlement not present")

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

        let result = await service.saveWorkout(run: run, pauseResumeEvents: events)
        XCTAssertFalse(result, "saveWorkout should return false without authorization")
    }

    func test_readWeight_withoutAuthorization_returnsNil() async throws {
        let service = HealthKitService()
        try XCTSkipUnless(service.isAvailable, "HealthKit not available on this platform")

        let weight = await service.readWeight()
        // Without authorization, readWeight should return nil
        XCTAssertNil(weight)
    }
}
