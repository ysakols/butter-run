import XCTest

final class StartStopRunUITests: XCTestCase {
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

    /// Taps "Start run" and handles location permission sheet on fresh simulators.
    private func tapStartRun() {
        let startButton = app.buttons["Start run"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // Handle custom location permission sheet if it appears
        let allowLocation = app.buttons["Allow Location"]
        if allowLocation.waitForExistence(timeout: 2) {
            allowLocation.tap()
            // Trigger interruption monitor for the system location dialog
            app.tap()
        }
    }

    func test_startRun_showsActiveRunScreen() {
        tapStartRun()

        // Verify active run UI elements appear (combined accessibility element)
        let heroText = app.otherElements.matching(NSPredicate(format: "label CONTAINS 'pats of butter burned'")).firstMatch
        XCTAssertTrue(heroText.waitForExistence(timeout: 5))
    }

    func test_pauseResume_togglesButton() {
        tapStartRun()

        // Wait for active run to load
        let pauseButton = app.buttons["Pause run"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5))
        pauseButton.tap()

        // Should now show "Resume run"
        let resumeButton = app.buttons["Resume run"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 3))
        resumeButton.tap()

        // Should now show "Pause run" again
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3))
    }

    func test_stopButton_exists() {
        tapStartRun()

        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
    }

    func test_activeRun_showsControls() {
        tapStartRun()

        // Verify active run screen loads with key controls
        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))

        let pauseButton = app.buttons["Pause run"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3))

        let heroText = app.otherElements.matching(NSPredicate(format: "label CONTAINS 'pats of butter burned'")).firstMatch
        XCTAssertTrue(heroText.waitForExistence(timeout: 3))
    }

    func test_stopRun_showsConfirmation() {
        tapStartRun()

        // Long-press stop to trigger confirmation dialog
        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.press(forDuration: 3.5)

        // Confirmation dialog should appear with "End Run" button
        let endRunButton = app.buttons["End Run"]
        XCTAssertTrue(endRunButton.waitForExistence(timeout: 3))
    }

    func test_stopRun_cancelKeepsRunning() {
        tapStartRun()

        // Long-press stop to trigger confirmation dialog
        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.press(forDuration: 3.5)

        // Wait for and tap Cancel in the dialog
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        cancelButton.tap()

        // Run should still be active — Pause button should still exist
        let pauseButton = app.buttons["Pause run"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3))
    }
}
