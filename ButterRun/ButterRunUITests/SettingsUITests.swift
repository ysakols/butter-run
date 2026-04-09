import XCTest

final class SettingsUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["--skip-onboarding", "--reset-state", "--skip-tos"]
        app.launch()
    }

    private func navigateToSettings() {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()
    }

    /// Workflow: navigate to settings → verify title → check toggles → scroll to bottom → check butter math → delete flow
    func test_settingsFullWorkflow() {
        navigateToSettings()

        // Verify title
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 3), "Settings nav bar should appear")

        // Check toggles exist
        let voiceToggle = app.switches["Voice Feedback"]
        XCTAssertTrue(voiceToggle.waitForExistence(timeout: 3), "Voice Feedback toggle should exist")

        let autoPauseToggle = app.switches["Auto-Pause"]
        XCTAssertTrue(autoPauseToggle.waitForExistence(timeout: 3), "Auto-Pause toggle should exist")

        // Scroll to butter math section
        app.swipeUp()
        let patRow = app.staticTexts["1 pat butter"]
        XCTAssertTrue(patRow.waitForExistence(timeout: 3), "Butter math section should be visible")
        let calText = app.staticTexts["34 calories"]
        XCTAssertTrue(calText.exists, "Calorie text should exist")

        // Scroll to delete button — may be far below fold
        let deleteButton = app.buttons["Delete All My Data"]
        for _ in 0..<5 {
            if deleteButton.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should be reachable by scrolling")
        deleteButton.tap()

        // Verify confirmation dialog
        let confirmButton = app.buttons["Delete Everything"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3), "Delete confirmation should appear")

        // Dismiss without deleting
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel should exist in confirmation")
        cancelButton.tap()
    }
}
