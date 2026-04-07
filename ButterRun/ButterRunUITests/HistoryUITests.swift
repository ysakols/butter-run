import XCTest

final class HistoryUITests: XCTestCase {
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
        if allowLocation.waitForExistence(timeout: 1) {
            allowLocation.tap()
        }
    }

    func test_emptyState_showsMessage() {
        // Navigate to History tab
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        // Verify empty state
        let emptyText = app.staticTexts["No runs yet"]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 3))

        let ctaText = app.staticTexts["Tap the Run tab to start!"]
        XCTAssertTrue(ctaText.exists)
    }

    func test_runAppearsInHistory() {
        // Start a run
        tapStartRun()

        // Wait for active run to load (replaces sleep(2))
        let pauseButton = app.buttons["Pause run"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5))

        // Stop via long press (LongPressStopButton requires 3-second hold)
        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.press(forDuration: 3.5)

        // Confirm stop in the dialog
        let endRunButton = app.buttons["End Run"]
        XCTAssertTrue(endRunButton.waitForExistence(timeout: 3))
        endRunButton.tap()

        // Dismiss summary
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        // Navigate to History
        let historyTab = app.tabBars.buttons["History"]
        historyTab.tap()

        // Verify a run row exists
        let allRunsHeader = app.staticTexts["All Runs"]
        XCTAssertTrue(allRunsHeader.waitForExistence(timeout: 5))
    }

    func test_manualRunEntry() {
        // First create a run so the list renders (empty state doesn't show "Log Manual Run")
        tapStartRun()

        // Wait for active run
        let pauseButton = app.buttons["Pause run"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5))

        // Stop via long press
        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.press(forDuration: 3.5)

        // Confirm stop
        let endRunButton = app.buttons["End Run"]
        XCTAssertTrue(endRunButton.waitForExistence(timeout: 3))
        endRunButton.tap()

        // Dismiss summary
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        // Navigate to History tab
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        // Tap manual entry button (now visible because run list is non-empty)
        let manualButton = app.buttons["Log Manual Run"]
        XCTAssertTrue(manualButton.waitForExistence(timeout: 5))
        manualButton.tap()

        // Verify the form appears
        let logTitle = app.staticTexts["Log a Run"]
        XCTAssertTrue(logTitle.waitForExistence(timeout: 3))
    }
}
