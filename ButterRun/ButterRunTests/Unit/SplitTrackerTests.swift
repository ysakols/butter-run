import XCTest
@testable import ButterRun

final class SplitTrackerTests: XCTestCase {

    func test_noSplitBeforeBoundary() {
        let tracker = SplitTracker(splitDistanceMeters: 1609.344, weightKg: 70)
        tracker.start()
        tracker.update(totalDistanceMeters: 1500, elapsedSeconds: 600, elevationGainMeters: 0, currentSpeedMph: 6.0)
        XCTAssertEqual(tracker.completedSplits.count, 0)
    }

    func test_splitAtExactBoundary() {
        let tracker = SplitTracker(splitDistanceMeters: 1609.344, weightKg: 70)
        tracker.start()
        tracker.update(totalDistanceMeters: 1609.344, elapsedSeconds: 480, elevationGainMeters: 0, currentSpeedMph: 6.0)
        XCTAssertEqual(tracker.completedSplits.count, 1)
    }

    func test_multipleSplitsInOneUpdate() {
        let tracker = SplitTracker(splitDistanceMeters: 1609.344, weightKg: 70)
        tracker.start()
        tracker.update(totalDistanceMeters: 3500, elapsedSeconds: 1200, elevationGainMeters: 0, currentSpeedMph: 6.0)
        XCTAssertEqual(tracker.completedSplits.count, 2)
    }

    func test_splitPaceCalculation() {
        let tracker = SplitTracker(splitDistanceMeters: 1609.344, weightKg: 70)
        tracker.start()
        tracker.update(totalDistanceMeters: 1609.344, elapsedSeconds: 480, elevationGainMeters: 0, currentSpeedMph: 6.0)

        guard let split = tracker.completedSplits.first else {
            XCTFail("Expected one split")
            return
        }
        // Pace = 480s / (1609.344/1000) km = ~298 s/km
        XCTAssertEqual(split.paceSecondsPerKm, 298.0, accuracy: 2.0)
    }

    func test_finalSplit_partial() {
        let tracker = SplitTracker(splitDistanceMeters: 1609.344, weightKg: 70)
        tracker.start()
        tracker.update(totalDistanceMeters: 2500, elapsedSeconds: 900, elevationGainMeters: 0, currentSpeedMph: 6.0)

        let finalSplit = tracker.finalSplit(
            totalDistanceMeters: 2500,
            elapsedSeconds: 900,
            elevationGainMeters: 0,
            currentSpeedMph: 6.0
        )
        XCTAssertNotNil(finalSplit)
        XCTAssertTrue(finalSplit?.isPartial ?? false)
    }

    func test_finalSplit_tinyRemainder() {
        let tracker = SplitTracker(splitDistanceMeters: 1609.344, weightKg: 70)
        tracker.start()
        tracker.update(totalDistanceMeters: 1615, elapsedSeconds: 482, elevationGainMeters: 0, currentSpeedMph: 6.0)

        let finalSplit = tracker.finalSplit(
            totalDistanceMeters: 1615,
            elapsedSeconds: 482,
            elevationGainMeters: 0,
            currentSpeedMph: 6.0
        )
        // Remainder is ~5.7m, less than 10m, should return nil
        XCTAssertNil(finalSplit)
    }
}
