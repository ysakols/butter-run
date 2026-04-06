import XCTest
@testable import ButterRun

final class ButterCalculatorTests: XCTestCase {

    // MARK: - MET Values

    func test_metValue_atTableBoundaries() {
        XCTAssertEqual(ButterCalculator.metValue(forSpeedMph: 5.0), 8.3, accuracy: 0.01)
        XCTAssertEqual(ButterCalculator.metValue(forSpeedMph: 6.0), 9.8, accuracy: 0.01)
    }

    func test_metValue_interpolation() {
        let met = ButterCalculator.metValue(forSpeedMph: 5.5)
        XCTAssertEqual(met, 9.0, accuracy: 0.1)
    }

    func test_metValue_belowMinimum() {
        XCTAssertEqual(ButterCalculator.metValue(forSpeedMph: 0), 1.0, accuracy: 0.01)
        XCTAssertEqual(ButterCalculator.metValue(forSpeedMph: 1.0), 2.0, accuracy: 0.01)
    }

    func test_metValue_aboveMaximum() {
        XCTAssertEqual(ButterCalculator.metValue(forSpeedMph: 15.0), 23.0, accuracy: 0.01)
    }

    // MARK: - Calories

    func test_caloriesBurned_70kg_jogging() {
        // 70kg, MET 8.3, 30min = (8.3 * 3.5 * 70 / 200) * 30
        let cal = ButterCalculator.caloriesBurned(weightKg: 70, met: 8.3, durationMinutes: 30)
        XCTAssertEqual(cal, 304.85, accuracy: 0.1)
    }

    func test_caloriesToButterTsp() {
        XCTAssertEqual(ButterCalculator.caloriesToButterTsp(34), 1.0, accuracy: 0.001)
        XCTAssertEqual(ButterCalculator.caloriesToButterTsp(102), 3.0, accuracy: 0.001)
    }

    func test_butterBurned_endToEnd() {
        let tsp = ButterCalculator.butterBurned(weightKg: 70, speedMph: 6.0, durationMinutes: 30)
        // MET 9.8 -> (9.8 * 3.5 * 70 / 200) * 30 = 360.15 cal -> 10.59 tsp
        XCTAssertEqual(tsp, 10.59, accuracy: 0.1)
    }


    // MARK: - Butter Description

    func test_butterDescription_subTeaspoon() {
        let desc = ButterCalculator.butterDescription(tsp: 0.5)
        XCTAssertTrue(desc.contains("0.5"))
        XCTAssertTrue(desc.contains("pats"))
    }

    func test_butterDescription_tablespoons() {
        let desc = ButterCalculator.butterDescription(tsp: 6.0)
        XCTAssertTrue(desc.contains("tbsp"))
    }

    func test_butterDescription_sticks() {
        let desc = ButterCalculator.butterDescription(tsp: 48.0)
        XCTAssertTrue(desc.contains("stick"))
    }

    // MARK: - Edge Cases

    func test_weightZero_returnsZeroCalories() {
        let cal = ButterCalculator.caloriesBurned(weightKg: 0, met: 8.3, durationMinutes: 30)
        XCTAssertEqual(cal, 0, accuracy: 0.001)
    }
}
