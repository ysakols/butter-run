import XCTest

final class ButterZeroFlowUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    func test_enableButterZero_showsStrip() {
        // Toggle Butter Zero on home screen
        let bzToggle = app.switches["Butter Zero mode"]
        XCTAssertTrue(bzToggle.waitForExistence(timeout: 5))
        bzToggle.tap()

        // Start run
        let churnButton = app.buttons["Start run"]
        churnButton.tap()

        // Eat butter button should be visible in controls
        let eatButton = app.buttons["Eat butter"]
        XCTAssertTrue(eatButton.waitForExistence(timeout: 5))
    }

    func test_eatButter_updatesBalance() {
        // Enable BZ
        let bzToggle = app.switches["Butter Zero mode"]
        XCTAssertTrue(bzToggle.waitForExistence(timeout: 5))
        bzToggle.tap()

        // Start run
        app.buttons["Start run"].tap()

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
        // Enable BZ and start run
        let bzToggle = app.switches["Butter Zero mode"]
        XCTAssertTrue(bzToggle.waitForExistence(timeout: 5))
        bzToggle.tap()

        app.buttons["Start run"].tap()

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
}
