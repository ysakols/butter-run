import XCTest

final class TabNavigationUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        // --reset-state: wipe UserDefaults + in-memory DB
        // --skip-onboarding: auto-create test profile
        // --skip-tos: bypass Terms of Service gate
        app.launchArguments = ["--skip-onboarding", "--reset-state", "--skip-tos"]
        app.launch()
    }

    func test_allFourTabsExist() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        XCTAssertTrue(tabBar.buttons["Run"].exists)
        XCTAssertTrue(tabBar.buttons["History"].exists)
        XCTAssertTrue(tabBar.buttons["Guide"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)
    }

    func test_switchToHistoryTab() {
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 10))
        historyTab.tap()

        let historyNav = app.navigationBars["History"]
        XCTAssertTrue(historyNav.waitForExistence(timeout: 3))
    }

    func test_switchToGuideTab() {
        let guideTab = app.tabBars.buttons["Guide"]
        XCTAssertTrue(guideTab.waitForExistence(timeout: 10))
        guideTab.tap()

        // ChurnGuideView uses .navigationTitle("") and .navigationBarHidden(true)
        // so verify the display text instead of a navigation bar
        let guideHeader = app.staticTexts["Churn Guide"]
        XCTAssertTrue(guideHeader.waitForExistence(timeout: 3))
    }

    func test_switchToSettingsTab() {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 3))
    }
}
