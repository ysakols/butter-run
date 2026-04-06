import XCTest

final class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--reset-state"]
        app.launch()
    }

    func test_onboarding_emptyName_buttonDisabled() {
        // Navigate to page 4 (profile) by tapping Next 3 times
        for _ in 0..<3 {
            let nextButton = app.buttons["Next"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
            nextButton.tap()
        }

        // Clear name field if pre-filled
        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.clearAndType("")

        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS \"Let's Churn\"")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        XCTAssertFalse(button.isEnabled)
    }

    func test_onboarding_validInput_createsProfile() {
        // Navigate to page 4 (profile) by tapping Next 3 times
        for _ in 0..<3 {
            let nextButton = app.buttons["Next"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
            nextButton.tap()
        }

        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Sarah")

        // Weight field label is dynamic based on locale (lbs or kg)
        let weightFieldLbs = app.textFields["Weight in lbs"]
        let weightFieldKg = app.textFields["Weight in kg"]
        let weightField = weightFieldLbs.exists ? weightFieldLbs : weightFieldKg
        weightField.tap()
        weightField.clearAndType("65")

        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS \"Let's Churn\"")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        XCTAssertTrue(button.isEnabled)
        button.tap()

        // Should navigate to home screen with greeting
        let greeting = app.staticTexts["Hey, Sarah"]
        XCTAssertTrue(greeting.waitForExistence(timeout: 5))
    }

    func test_onboarding_zeroWeight_buttonDisabled() {
        // Navigate to page 4 (profile) by tapping Next 3 times
        for _ in 0..<3 {
            let nextButton = app.buttons["Next"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
            nextButton.tap()
        }

        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Test")

        // Weight field label is dynamic based on locale (lbs or kg)
        let weightFieldLbs = app.textFields["Weight in lbs"]
        let weightFieldKg = app.textFields["Weight in kg"]
        let weightField = weightFieldLbs.exists ? weightFieldLbs : weightFieldKg
        weightField.tap()
        weightField.clearAndType("0")

        // Trigger validation by tapping elsewhere
        nameField.tap()

        // Button should be disabled when weight is zero
        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS \"Let's Churn\"")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        XCTAssertFalse(button.isEnabled)
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
