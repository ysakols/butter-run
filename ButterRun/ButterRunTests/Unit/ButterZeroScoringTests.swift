import XCTest
@testable import ButterRun

final class ButterZeroScoringTests: XCTestCase {

    func test_score_clampsToZero() {
        let score = ButterCalculator.butterZeroScore(netTsp: 100.0)
        XCTAssertEqual(score, 0)
    }

    func test_score_neverNegative() {
        let score = ButterCalculator.butterZeroScore(netTsp: -100.0)
        XCTAssertGreaterThanOrEqual(score, 0)
    }

    func test_score_clampsTo100() {
        let score = ButterCalculator.butterZeroScore(netTsp: 0.0)
        XCTAssertEqual(score, 100)
    }

    func test_score_neverAbove100() {
        // Even with a very tiny net
        let score = ButterCalculator.butterZeroScore(netTsp: 0.001)
        XCTAssertLessThanOrEqual(score, 100)
    }

    func test_score_symmetric_positive_and_negative() {
        let pos = ButterCalculator.butterZeroScore(netTsp: 2.0)
        let neg = ButterCalculator.butterZeroScore(netTsp: -2.0)
        XCTAssertEqual(pos, neg)
    }

    func test_score_gradual_decline() {
        let s0 = ButterCalculator.butterZeroScore(netTsp: 0.0)
        let s1 = ButterCalculator.butterZeroScore(netTsp: 1.0)
        let s2 = ButterCalculator.butterZeroScore(netTsp: 2.0)
        let s3 = ButterCalculator.butterZeroScore(netTsp: 3.0)
        XCTAssertGreaterThan(s0, s1)
        XCTAssertGreaterThan(s1, s2)
        XCTAssertGreaterThan(s2, s3)
    }
}
