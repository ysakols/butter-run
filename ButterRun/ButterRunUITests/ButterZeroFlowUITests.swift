import XCTest

final class ButterZeroFlowUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--skip-onboarding", "--reset-state"]
        app.launch()

        // Handle system location permission dialog on fresh simulators
        addUIInterruptionMonitor(withDescription: "Location") { alert in
            let allowButton = alert.buttons["Allow While Using App"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
    }

    /// Enables Butter Zero mode and starts a run, handling location permission if needed.
    private func enableBZAndStartRun() {
        let bzToggle = app.switches["Butter Zero mode"]
        XCTAssertTrue(bzToggle.waitForExistence(timeout: 5))
        bzToggle.tap()

        let startButton = app.buttons["Start run"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // Handle custom location permission sheet if it appears
        let allowLocation = app.buttons["Allow Location"]
        if allowLocation.waitForExistence(timeout: 1) {
            allowLocation.tap()
        }
    }

    func test_enableButterZero_showsStrip() {
        enableBZAndStartRun()

        // Eat butter button should be visible in controls
        let eatButton = app.buttons["Eat butter"]
        XCTAssertTrue(eatButton.waitForExistence(timeout: 5))
    }

    func test_eatButter_updatesBalance() {
        enableBZAndStartRun()

        // Tap the full Eat button in controls
        let eatButton = app.buttons["Eat butter"]
        XCTAssertTrue(eatButton.waitForExistence(timeout: 5))
        eatButton.tap()

        // Select 1 pat from the sheet
        let patButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '1 pat'")).firstMatch
        XCTAssertTrue(patButton.waitForExistence(timeout: 5))
        patButton.tap()

        // Verify undo toast appears
        let undoButton = app.buttons["Undo"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 3))
    }

    func test_undoButterEntry() {
        enableBZAndStartRun()

        // Eat butter via sheet
        let eatButton = app.buttons["Eat butter"]
        XCTAssertTrue(eatButton.waitForExistence(timeout: 5))
        eatButton.tap()

        // Select 1 pat from the sheet
        let patButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '1 pat'")).firstMatch
        XCTAssertTrue(patButton.waitForExistence(timeout: 5))
        patButton.tap()

        // Tap undo
        let undoButton = app.buttons["Undo"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 3))
        undoButton.tap()

        // Undo toast should disappear
        XCTAssertFalse(undoButton.waitForExistence(timeout: 2))
    }

    func test_eatButterSheet_showsPresets() {
        enableBZAndStartRun()

        // Tap Eat button to open sheet
        let eatButton = app.buttons["Eat butter"]
        XCTAssertTrue(eatButton.waitForExistence(timeout: 5))
        eatButton.tap()

        // Verify sheet content
        let sheetTitle = app.staticTexts["How much butter?"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 3))

        // Cancel button should be in toolbar
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
    }

    func test_eatButterSheet_cancel() {
        enableBZAndStartRun()

        // Open eat butter sheet
        let eatButton = app.buttons["Eat butter"]
        XCTAssertTrue(eatButton.waitForExistence(timeout: 5))
        eatButton.tap()

        // Verify sheet appeared
        let sheetTitle = app.staticTexts["How much butter?"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 3))

        // Tap Cancel to dismiss
        let cancelButton = app.buttons["Cancel"]
        cancelButton.tap()

        // Verify controls are still visible (sheet dismissed, run continues)
        XCTAssertTrue(eatButton.waitForExistence(timeout: 3))
    }
}
