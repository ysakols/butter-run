import XCTest
@testable import ButterRun

final class WeightConversionTests: XCTestCase {

    func test_patTeaspoonEquivalent_isOne() {
        // Verify 1 pat = 1 tsp (the Phase 3 change)
        XCTAssertEqual(ButterServing.pat.teaspoonEquivalent, 1.0)
    }
}
