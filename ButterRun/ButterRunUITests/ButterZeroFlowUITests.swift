import XCTest

final class ButterZeroFlowUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true // Continue through the workflow
        app.launchArguments = ["--skip-onboarding", "--reset-state", "--skip-tos", "--skip-countdown"]
        app.launch()
    }

    /// Single workflow: enable BZ → start run → open eat sheet → eat butter → undo → cancel sheet
    func test_butterZeroFullWorkflow() {
        // Step 1: Enable Butter Zero
        let bzToggle = app.switches["Butter Zero mode"]
        XCTAssertTrue(bzToggle.waitForExistence(timeout: 10), "BZ toggle should exist")
        bzToggle.tap()

        // Step 2: Start run
        let startButton = app.buttons["Start run"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3), "Start button should exist after toggle")
        startButton.tap()

        // Handle location permission on fresh simulator
        let allowLocation = app.buttons["Allow Location"]
        if allowLocation.waitForExistence(timeout: 3) {
            allowLocation.tap()
            // System dialog may take a moment to appear after custom sheet dismisses
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let systemAllow = springboard.buttons["Allow While Using App"]
            if systemAllow.waitForExistence(timeout: 5) {
                systemAllow.tap()
            }
        }

        // Step 3: Verify Eat butter button appears (proves BZ mode is active)
        // Allow extra time: after permission grant, app delays 1s before showing active run
        let eatButton = app.buttons["Eat butter"]
        XCTAssertTrue(eatButton.waitForExistence(timeout: 15), "Eat butter button should appear in BZ mode")

        // Step 4: Open eat butter sheet and verify presets
        eatButton.tap()
        let sheetTitle = app.staticTexts["How much butter?"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 3), "Eat butter sheet should show title")
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist in sheet")

        // Step 5: Select 1 pat
        let patButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '1 pat'")).firstMatch
        XCTAssertTrue(patButton.waitForExistence(timeout: 3), "1 pat button should exist")
        patButton.tap()

        // Step 6: Verify undo toast and tap undo
        let undoButton = app.buttons["Undo"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 3), "Undo toast should appear after eating")
        undoButton.tap()
        XCTAssertFalse(undoButton.waitForExistence(timeout: 2), "Undo toast should disappear after tapping")

        // Step 7: Open sheet again and cancel (verifies dismiss works)
        XCTAssertTrue(eatButton.waitForExistence(timeout: 3), "Eat button should still be visible")
        eatButton.tap()
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 3), "Sheet should reappear")
        cancelButton.tap()
        XCTAssertTrue(eatButton.waitForExistence(timeout: 3), "Controls should remain after sheet cancel")
    }
}
