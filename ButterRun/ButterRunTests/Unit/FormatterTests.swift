import XCTest
@testable import ButterRun

final class FormatterTests: XCTestCase {

    // MARK: - Duration

    func test_duration_subHour() {
        XCTAssertEqual(ButterFormatters.duration(754), "12:34")
    }

    func test_duration_overHour() {
        XCTAssertEqual(ButterFormatters.duration(3754), "1:02:34")
    }

    func test_duration_zero() {
        XCTAssertEqual(ButterFormatters.duration(0), "0:00")
    }

    // MARK: - Pace

    func test_pace_miles() {
        // 300 s/km in miles = 300 * 1.60934 = 482.8s = 8:02/mi
        let result = ButterFormatters.pace(secondsPerKm: 300, usesMiles: true)
        XCTAssertEqual(result, "8:02/mi")
    }

    func test_pace_km() {
        let result = ButterFormatters.pace(secondsPerKm: 300, usesMiles: false)
        XCTAssertEqual(result, "5:00/km")
    }

    func test_pace_zeroDistance() {
        let result = ButterFormatters.pace(secondsPerKm: 0, usesMiles: true)
        XCTAssertEqual(result, "--:--")
    }

    func test_pace_infinite() {
        let result = ButterFormatters.pace(secondsPerKm: .infinity, usesMiles: true)
        XCTAssertEqual(result, "--:--")
    }

    // MARK: - Distance

    func test_distance_miles() {
        let result = ButterFormatters.distance(meters: 5000, usesMiles: true)
        XCTAssertEqual(result, "3.11 mi")
    }

    func test_distance_km() {
        let result = ButterFormatters.distance(meters: 5000, usesMiles: false)
        XCTAssertEqual(result, "5.00 km")
    }

    // MARK: - Pats Formatter

    func test_pats_zero() {
        XCTAssertEqual(ButterFormatters.pats(0.0), "0.0 pats")
    }

    func test_pats_belowThreshold() {
        XCTAssertEqual(ButterFormatters.pats(0.05), "0.0 pats")
    }

    func test_pats_normalValue() {
        XCTAssertEqual(ButterFormatters.pats(8.4), "8.4 pats")
    }

    func test_pats_largeValue() {
        XCTAssertEqual(ButterFormatters.pats(24.0), "24.0 pats")
    }

    // MARK: - Pats With Detail

    func test_patsWithDetail_zero() {
        let result = ButterFormatters.patsWithDetail(0.0)
        XCTAssertTrue(result.contains("0 cals"))
    }

    func test_patsWithDetail_oneUnit() {
        let result = ButterFormatters.patsWithDetail(1.0)
        XCTAssertTrue(result.contains("34 cals"))
    }

    func test_patsWithDetail_multipleUnits() {
        let result = ButterFormatters.patsWithDetail(10.0)
        XCTAssertTrue(result.contains("340 cals"))
    }

    // MARK: - Net Pats

    func test_netPats_zero() {
        XCTAssertEqual(ButterFormatters.netPats(0.0), "0.0 pats")
    }

    func test_netPats_positive() {
        XCTAssertEqual(ButterFormatters.netPats(2.5), "+2.5 pats")
    }

    func test_netPats_negative() {
        XCTAssertEqual(ButterFormatters.netPats(-1.3), "-1.3 pats")
    }

    func test_netPats_nearZero() {
        XCTAssertEqual(ButterFormatters.netPats(0.03), "0.0 pats")
    }
}
