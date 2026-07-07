import XCTest
@testable import CalculatorApp

final class CalculatorUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    // MARK: - Launch Tests

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.exists, "Application window should exist after launch")
    }

    // MARK: - Button Existence Tests

    func testDigitButtonsExist() throws {
        let app = XCUIApplication()
        app.launch()

        for digit in "0123456789" {
            let button = app.buttons[digit.description]
            XCTAssertTrue(button.exists, "Button '\(digit)' should exist")
        }
    }

    func testOperatorButtonsExist() throws {
        let app = XCUIApplication()
        app.launch()

        let operators: [String] = ["+", "-", "*", "/", "%"]
        for op in operators {
            let button = app.buttons[op]
            XCTAssertTrue(button.exists, "Button '\(op)' should exist")
        }
    }

    func testClearButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["C"].exists, "Clear button should exist")
    }

    func testEqualsButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["="].exists, "Equals button should exist")
    }

    // MARK: - Calculation Tests

    func testSimpleAddition() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["1"].tap()
        app.buttons["5"].tap()
        app.buttons["+"].tap()
        app.buttons["1"].tap()
        app.buttons["6"].tap()
        app.buttons["="].tap()

        let result = app.staticTexts["31"]
        XCTAssertTrue(result.exists, "Result should be 31")
    }

    func testParenthesesCalculation() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["("].tap()
        app.buttons["1"].tap()
        app.buttons["5"].tap()
        app.buttons["+"].tap()
        app.buttons["1"].tap()
        app.buttons["6"].tap()
        app.buttons[")"].tap()
        app.buttons["*"].tap()
        app.buttons["5"].tap()
        app.buttons["="].tap()

        let result = app.staticTexts["155"]
        XCTAssertTrue(result.exists, "Result should be 155")
    }

    // MARK: - Error Tests

    func testDivisionByZeroShowsError() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["1"].tap()
        app.buttons["/"].tap()
        app.buttons["0"].tap()
        app.buttons["="].tap()

        let error = app.staticTexts["Division by zero"]
        XCTAssertTrue(error.exists, "Should show division by zero error")
    }

    // MARK: - Keyboard Tests

    func testKeyboardInput() throws {
        let app = XCUIApplication()
        app.launch()

        app.typeText("1")
        app.typeText("+")
        app.typeText("2")
        app.typeText("\r")

        let result = app.staticTexts["3"]
        XCTAssertTrue(result.exists, "Result should be 3")
    }

    // MARK: - Clipboard Tests

    func testPasteExpression() throws {
        let app = XCUIApplication()
        app.launch()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("(15+16)*5", forType: .string)

        app.keyDown(using: .command, "v")

        let result = app.staticTexts["155"]
        XCTAssertTrue(result.exists, "Result should be 155 after paste")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() throws {
        let app = XCUIApplication()
        app.launch()

        let button0 = app.buttons["0"]
        XCTAssertTrue(button0.exists, "Button '0' should exist")
        XCTAssertEqual(button0.label, "0", "Button '0' label should be '0'")
    }
}
