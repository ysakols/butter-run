import XCTest
@testable import ButterRun

final class ShareImageRendererTests: XCTestCase {

    @MainActor
    func test_render_returnsNonNilImage() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.distanceMeters = 5000
        run.durationSeconds = 1800
        run.totalButterBurnedTsp = 3.0
        run.totalButterEatenTsp = 1.0
        run.netButterTsp = -2.0
        run.averagePaceSecondsPerKm = 360

        let image = ShareImageRenderer.render(run: run, usesMiles: true, mode: .story)
        XCTAssertNotNil(image, "ShareImageRenderer should produce a non-nil UIImage for story mode")
    }

    @MainActor
    func test_render_squareMode() {
        let run = Run(startDate: .now, isButterZeroChallenge: false)
        run.distanceMeters = 3000
        run.durationSeconds = 900
        run.totalButterBurnedTsp = 1.5

        let image = ShareImageRenderer.render(run: run, usesMiles: false, mode: .square)
        XCTAssertNotNil(image, "ShareImageRenderer should produce a non-nil UIImage for square mode")
    }

    @MainActor
    func test_render_butterZeroRun() {
        let run = Run(startDate: .now, isButterZeroChallenge: true)
        run.distanceMeters = 5000
        run.durationSeconds = 1500
        run.totalButterBurnedTsp = 2.0
        run.totalButterEatenTsp = 2.1
        run.netButterTsp = 0.1

        let image = ShareImageRenderer.render(run: run, usesMiles: true)
        XCTAssertNotNil(image)
    }
}
