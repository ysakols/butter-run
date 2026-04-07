import XCTest

final class StartStopRunUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    func test_startRun_showsActiveRunScreen() {
        let churnButton = app.buttons["Start run"]
        XCTAssertTrue(churnButton.waitForExistence(timeout: 5))
        churnButton.tap()

        // Verify active run UI elements appear
        let heroText = app.staticTexts["pats burned"]
        XCTAssertTrue(heroText.waitForExistence(timeout: 5))
    }

    func test_pauseResume_togglesButton() {
        let churnButton = app.buttons["Start run"]
        XCTAssertTrue(churnButton.waitForExistence(timeout: 5))
        churnButton.tap()

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
        let churnButton = app.buttons["Start run"]
        XCTAssertTrue(churnButton.waitForExistence(timeout: 5))
        churnButton.tap()

        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
    }

    func test_activeRun_showsControls() {
        let churnButton = app.buttons["Start run"]
        XCTAssertTrue(churnButton.waitForExistence(timeout: 5))
        churnButton.tap()

        // Verify active run screen loads with key controls
        let stopButton = app.buttons["Stop run"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))

        let pauseButton = app.buttons["Pause run"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3))

        let heroText = app.staticTexts["pats burned"]
        XCTAssertTrue(heroText.waitForExistence(timeout: 3))
    }
}
