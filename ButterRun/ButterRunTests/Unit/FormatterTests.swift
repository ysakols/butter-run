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

    // MARK: - Butter

    func test_butter_small() {
        let result = ButterFormatters.butter(tsp: 0.05)
        XCTAssertEqual(result, "0.0 tsp")
    }

    func test_butter_normal() {
        let result = ButterFormatters.butter(tsp: 3.7)
        XCTAssertEqual(result, "3.7 tsp")
    }
}
