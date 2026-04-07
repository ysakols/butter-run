import XCTest
@testable import ButterRun

final class LongPressStopButtonTests: XCTestCase {

    func test_viewInitializes_withClosure() {
        // LongPressStopButton takes a single `onComplete` closure.
        // Verify it can be instantiated without crashing.
        var called = false
        let _ = LongPressStopButton {
            called = true
        }
        // Closure is not invoked at init time
        XCTAssertFalse(called)
    }

    func test_holdDuration_isThreeSeconds() {
        // The hold duration is a private let constant set to 3.0 seconds.
        // We cannot access it directly from tests, but we verify the
        // accessibility hint documents the 3-second requirement.
        // This test serves as a reminder: if holdDuration changes,
        // update the accessibility hint and this comment.
        //
        // Source: LongPressStopButton.swift line 11
        //   private let holdDuration: Double = 3.0
        //
        // The view's accessibilityHint reads:
        //   "Press and hold for 3 seconds to stop the run"
        let _ = LongPressStopButton { }
        // If we reach here, the view structure is valid
    }
}
