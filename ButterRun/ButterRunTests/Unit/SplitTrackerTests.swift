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

    func test_butterBurnedPerSplit() {
        let tracker = SplitTracker(splitDistanceMeters: 1000, weightKg: 70)
        tracker.start()
        // First split: 1.5 tsp total
        tracker.update(totalDistanceMeters: 1000, elapsedSeconds: 300, elevationGainMeters: 0, currentSpeedMph: 6.0, butterBurnedTsp: 1.5)
        XCTAssertEqual(tracker.completedSplits.count, 1)
        XCTAssertEqual(tracker.completedSplits[0].butterBurnedTsp, 1.5, accuracy: 0.01)

        // Second split: 3.0 tsp total -> 1.5 tsp for this split
        tracker.update(totalDistanceMeters: 2000, elapsedSeconds: 600, elevationGainMeters: 0, currentSpeedMph: 6.0, butterBurnedTsp: 3.0)
        XCTAssertEqual(tracker.completedSplits.count, 2)
        XCTAssertEqual(tracker.completedSplits[1].butterBurnedTsp, 1.5, accuracy: 0.01)
    }

    func test_finalSplit_butterBurned() {
        let tracker = SplitTracker(splitDistanceMeters: 1609.344, weightKg: 70)
        tracker.start()
        tracker.update(totalDistanceMeters: 1609.344, elapsedSeconds: 480, elevationGainMeters: 0, currentSpeedMph: 6.0, butterBurnedTsp: 2.0)
        let finalSplit = tracker.finalSplit(
            totalDistanceMeters: 2500,
            elapsedSeconds: 900,
            elevationGainMeters: 0,
            currentSpeedMph: 6.0,
            butterBurnedTsp: 3.5
        )
        XCTAssertNotNil(finalSplit)
        XCTAssertEqual(finalSplit!.butterBurnedTsp, 1.5, accuracy: 0.01)
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
