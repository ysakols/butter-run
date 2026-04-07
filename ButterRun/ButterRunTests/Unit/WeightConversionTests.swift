import XCTest
@testable import ButterRun

final class WeightConversionTests: XCTestCase {

    func test_lbsToKg_standard() {
        let lbs = 154.0
        let kg = lbs / 2.20462
        XCTAssertEqual(kg, 69.85, accuracy: 0.1)
    }

    func test_kgToLbs_standard() {
        let kg = 70.0
        let lbs = kg * 2.20462
        XCTAssertEqual(lbs, 154.3, accuracy: 0.1)
    }

    func test_roundTrip_lbsKgLbs() {
        let original = 180.0
        let kg = original / 2.20462
        let backToLbs = kg * 2.20462
        XCTAssertEqual(backToLbs, original, accuracy: 0.01)
    }

    func test_patTeaspoonEquivalent_isOne() {
        // Verify 1 pat = 1 tsp (the Phase 3 change)
        XCTAssertEqual(ButterServing.pat.teaspoonEquivalent, 1.0)
    }
}
