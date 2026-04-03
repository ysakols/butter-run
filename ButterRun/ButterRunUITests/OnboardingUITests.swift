import XCTest

final class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--reset-state"]
        app.launch()
    }

    func test_onboarding_emptyName_buttonDisabled() {
        // Clear name field if pre-filled
        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.clearAndType("")

        let button = app.buttons["Start run"]
        XCTAssertFalse(button.isEnabled)
    }

    func test_onboarding_validInput_createsProfile() {
        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Sarah")

        let weightField = app.textFields["Weight in kilograms"]
        weightField.tap()
        weightField.clearAndType("65")

        let button = app.buttons["Start run"]
        XCTAssertTrue(button.isEnabled)
        button.tap()

        // Should navigate to home screen with greeting
        let greeting = app.staticTexts["Hey, Sarah"]
        XCTAssertTrue(greeting.waitForExistence(timeout: 5))
    }

    func test_onboarding_zeroWeight_showsError() {
        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Test")

        let weightField = app.textFields["Weight in kilograms"]
        weightField.tap()
        weightField.clearAndType("0")

        // Trigger validation by tapping elsewhere
        nameField.tap()

        let error = app.staticTexts["Weight must be greater than zero"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
    }
}

extension XCUIElement {
    func clearAndType(_ text: String) {
        guard let value = self.value as? String, !value.isEmpty else {
            typeText(text)
            return
        }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
        typeText(deleteString)
        typeText(text)
    }
}
