import XCTest

final class SettingsUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--skip-onboarding", "--reset-state"]
        app.launch()
    }

    private func navigateToSettings() {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
    }

    func test_settingsTab_showsTitle() {
        navigateToSettings()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 3))
    }

    func test_voiceFeedbackToggle_exists() {
        navigateToSettings()

        let toggle = app.switches["Voice Feedback"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
    }

    func test_autoPauseToggle_exists() {
        navigateToSettings()

        let toggle = app.switches["Auto-Pause"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
    }

    func test_deleteAllData_showsConfirmation() {
        navigateToSettings()

        // Scroll to and tap the delete button
        let deleteButton = app.buttons["Delete All My Data"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        app.swipeUp() // Ensure visible on smaller screens (iPhone SE)
        deleteButton.tap()

        // Verify confirmation dialog appears
        let confirmButton = app.buttons["Delete Everything"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))

        // Dismiss without deleting
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()
    }

    func test_butterMathSection_displaysInfo() {
        navigateToSettings()

        // Verify butter math section content
        let patRow = app.staticTexts["1 pat butter"]
        XCTAssertTrue(patRow.waitForExistence(timeout: 3))

        let calText = app.staticTexts["34 calories"]
        XCTAssertTrue(calText.exists)
    }
}
