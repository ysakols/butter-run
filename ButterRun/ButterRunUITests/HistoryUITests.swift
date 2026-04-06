import XCTest

final class HistoryUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
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
        let churnButton = app.buttons["Start run"]
        XCTAssertTrue(churnButton.waitForExistence(timeout: 5))
        churnButton.tap()

        sleep(2) // Let it run briefly

        // Stop via long press (LongPressStopButton requires 3-second hold)
        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.press(forDuration: 3.5)

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
        // Navigate to History tab
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        // Tap manual entry button
        let manualButton = app.buttons["Log Manual Run"]
        XCTAssertTrue(manualButton.waitForExistence(timeout: 5))
        manualButton.tap()

        // Fill in the form
        let logTitle = app.staticTexts["Log a Run"]
        XCTAssertTrue(logTitle.waitForExistence(timeout: 3))
    }
}
