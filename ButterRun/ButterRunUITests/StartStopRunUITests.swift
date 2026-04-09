import XCTest

final class StartStopRunUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["--skip-onboarding", "--reset-state", "--skip-tos", "--skip-countdown"]
        app.launch()
    }

    /// Taps "Start run" and handles location permission sheet on fresh simulators.
    private func tapStartRun() {
        let startButton = app.buttons["Start run"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        // Handle custom location permission sheet if it appears
        let allowLocation = app.buttons["Allow Location"]
        if allowLocation.waitForExistence(timeout: 2) {
            allowLocation.tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let systemAllow = springboard.buttons["Allow While Using App"]
            if systemAllow.waitForExistence(timeout: 3) {
                systemAllow.tap()
            }
        }
    }

    /// Workflow: start run → verify controls → verify hero text → pause → resume
    func test_startRunAndControls() {
        tapStartRun()

        // Verify active run screen loads with key controls
        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Stop button should appear")

        let pauseButton = app.buttons["Pause run"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3), "Pause button should appear")

        // Verify hero text (combined accessibility element)
        let heroText = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'pats of butter burned'")).firstMatch
        XCTAssertTrue(heroText.waitForExistence(timeout: 5), "Hero text should show pats burned")

        // Pause and verify
        pauseButton.tap()
        let resumeButton = app.buttons["Resume run"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 3), "Resume button should appear after pause")

        // Resume and verify
        resumeButton.tap()
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3), "Pause button should reappear after resume")
    }

    /// Workflow: start run → long-press stop → verify confirmation → end run
    func test_stopRunConfirmation() {
        tapStartRun()

        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10))
        stopButton.press(forDuration: 3.5)

        // Confirmation dialog should appear
        let endRunButton = app.buttons["End Run"]
        XCTAssertTrue(endRunButton.waitForExistence(timeout: 5), "End Run button should appear in confirmation")
    }

    /// Workflow: start run → long-press stop → cancel → verify still running
    func test_stopRunCancel() {
        tapStartRun()

        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10))
        stopButton.press(forDuration: 3.5)

        // Wait for confirmation dialog
        let endRunButton = app.buttons["End Run"]
        XCTAssertTrue(endRunButton.waitForExistence(timeout: 5), "Confirmation dialog should appear")

        // Tap Cancel — in confirmationDialog, this may be the implicit cancel action
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 5) {
            cancelButton.tap()
        } else {
            // On some iOS versions, swipe down dismisses the action sheet
            app.swipeDown()
        }

        // Run should still be active
        let pauseButton = app.buttons["Pause run"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5), "Run should still be active after cancel")
    }
}
