import XCTest
@testable import ButterRun

final class RunModelTests: XCTestCase {

    func test_newRun_paceDefaults_areZero_notInfinity() {
        // A freshly-created Run must default pace fields to 0 so downstream
        // formatters and "show best pace" gates can use the > 0 sentinel
        // instead of .isFinite (which is true for both 0 and a real value).
        let run = Run()
        XCTAssertEqual(run.averagePaceSecondsPerKm, 0)
        XCTAssertEqual(run.bestPaceSecondsPerKm, 0)
        XCTAssertTrue(run.averagePaceSecondsPerKm.isFinite)
        XCTAssertTrue(run.bestPaceSecondsPerKm.isFinite)
    }

    func test_newRun_paceFormats_toPlaceholder() {
        // ButterFormatters.pace treats 0 as "no data" and renders "--:--",
        // matching the prior .infinity behavior at the display layer.
        let run = Run()
        let formatted = ButterFormatters.pace(secondsPerKm: run.averagePaceSecondsPerKm, usesMiles: true)
        XCTAssertTrue(formatted.contains("--:--"), "Expected placeholder pace, got \(formatted)")
    }
}
