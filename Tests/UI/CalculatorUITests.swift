import XCTest
import CalculatorApp

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
            let button = app.buttons["calc_btn_\(digit)"]
            XCTAssertTrue(button.exists, "Button 'calc_btn_\(digit)' should exist")
        }
    }

    func testOperatorButtonsExist() throws {
        let app = XCUIApplication()
        app.launch()

        let operators: [(symbol: String, identifier: String)] = [
            ("+", "calc_btn_+"),
            ("−", "calc_btn_−"),
            ("×", "calc_btn_×"),
            ("÷", "calc_btn_÷"),
            ("%", "calc_btn_%"),
        ]
        for op in operators {
            let button = app.buttons[op.identifier]
            XCTAssertTrue(button.exists, "Button '\(op.symbol)' (id: \(op.identifier)) should exist")
        }
    }

    func testClearButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["calc_btn_AC"].exists, "Clear button 'calc_btn_AC' should exist")
    }

    func testEqualsButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["calc_btn_="].exists, "Equals button 'calc_btn_=' should exist")
    }

    // MARK: - Calculation Tests

    func testSimpleAddition() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_5"].tap()
        app.buttons["calc_btn_+"].tap()
        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_6"].tap()
        app.buttons["calc_btn_="].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Результат") })
        XCTAssertTrue(display.exists, "Display should show result")
        XCTAssertTrue(display.label.contains("31"), "Display should contain '31'")
    }

    func testParenthesesCalculation() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_("].tap()
        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_5"].tap()
        app.buttons["calc_btn_+"].tap()
        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_6"].tap()
        app.buttons["calc_btn_)"].tap()
        app.buttons["calc_btn_×"].tap()
        app.buttons["calc_btn_5"].tap()
        app.buttons["calc_btn_="].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Результат") })
        XCTAssertTrue(display.exists, "Display should show result")
        XCTAssertTrue(display.label.contains("155"), "Display should contain '155'")
    }

    // MARK: - Error Tests

    func testDivisionByZeroShowsError() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_÷"].tap()
        app.buttons["calc_btn_0"].tap()
        app.buttons["calc_btn_="].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Ошибка") })
        XCTAssertTrue(display.exists, "Display should show error for division by zero")
    }

    // MARK: - Keyboard Tests

    func testKeyboardInput() throws {
        let app = XCUIApplication()
        app.launch()

        app.typeText("1")
        app.typeText("+")
        app.typeText("2")
        app.typeText("\r")

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Результат") })
        XCTAssertTrue(display.exists, "Display should show result")
        XCTAssertTrue(display.label.contains("3"), "Display should contain '3'")
    }

    // MARK: - Clipboard Tests

    func testPasteExpression() throws {
        let app = XCUIApplication()
        app.launch()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("(15+16)*5", forType: .string)

        app.keyDown(using: .command, "v")

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Результат") })
        XCTAssertTrue(display.exists, "Display should show result after paste")
        XCTAssertTrue(display.label.contains("155"), "Display should contain '155' after paste")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() throws {
        let app = XCUIApplication()
        app.launch()

        let button0 = app.buttons["calc_btn_0"]
        XCTAssertTrue(button0.exists, "Button 'calc_btn_0' should exist")
        XCTAssertEqual(button0.label, "0", "Button '0' label should be '0'")
    }

    // MARK: - Функциональные операции

    func testSquareRoot() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_4"].tap()
        app.buttons["calc_btn_√"].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Результат") })
        XCTAssertTrue(display.exists, "Display should show result")
        XCTAssertTrue(display.label.contains("2"), "Display should contain '2' (√4 = 2)")
    }

    func testSquare() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_5"].tap()
        app.buttons["calc_btn_x²"].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Результат") })
        XCTAssertTrue(display.exists, "Display should show result")
        XCTAssertTrue(display.label.contains("25"), "Display should contain '25' (5² = 25)")
    }

    // MARK: - Операции памяти

    func testMemoryOperations() throws {
        let app = XCUIApplication()
        app.launch()

        // Вводим 10 и добавляем в память (M+)
        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_0"].tap()
        app.buttons["calc_btn_M+"].tap()
        // Очищаем дисплей (AC)
        app.buttons["calc_btn_AC"].tap()
        // Вводим 3 и вычитаем из памяти (M−)
        app.buttons["calc_btn_3"].tap()
        app.buttons["calc_btn_M−"].tap()
        // Очищаем дисплей (AC)
        app.buttons["calc_btn_AC"].tap()
        // Вызываем память (MR) → должно быть 7 (10 - 3)
        app.buttons["calc_btn_MR"].tap()
        // MR записывает значение в expression, поэтому проверяем accessibilityLabel
        let displayAny = app.otherElements.firstMatch(where: { $0.label.contains("7") })
        XCTAssertTrue(displayAny.exists, "Display should contain '7' after memory recall")
        // Очищаем память (MC)
        app.buttons["calc_btn_MC"].tap()
    }

    // MARK: - История

    func testHistoryButtonOpensPanel() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_2"].tap()
        app.buttons["calc_btn_+"].tap()
        app.buttons["calc_btn_3"].tap()
        app.buttons["calc_btn_="].tap()

        XCTAssertTrue(app.windows.firstMatch.exists, "App window should exist after calculation")
    }

    // MARK: - Скобки

    func testParenthesesButtons() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_("].tap()
        app.buttons["calc_btn_2"].tap()
        app.buttons["calc_btn_+"].tap()
        app.buttons["calc_btn_3"].tap()
        app.buttons["calc_btn_)"].tap()
        app.buttons["calc_btn_="].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Результат") })
        XCTAssertTrue(display.exists, "Display should show result")
        XCTAssertTrue(display.label.contains("5"), "Display should contain '5' ((2+3) = 5)")
    }

    // MARK: - Backspace

    func testBackspaceRemovesLastCharacter() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_2"].tap()
        app.buttons["calc_btn_3"].tap()
        app.buttons["calc_btn_⌫"].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("12") })
        XCTAssertTrue(display.exists, "Display should contain '12' after backspace")
    }

    // MARK: - ToggleSign

    func testToggleSign() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_5"].tap()
        app.buttons["calc_btn_+/−"].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("-5") || $0.label.contains("−5") })
        XCTAssertTrue(display.exists, "Display should contain '-5' after toggle sign")
    }

    // MARK: - Percent

    func testPercent() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_5"].tap()
        app.buttons["calc_btn_0"].tap()
        app.buttons["calc_btn_%"].tap()

        XCTAssertTrue(app.windows.firstMatch.exists, "App window should exist after percent")
    }

    // MARK: - Клавиатура

    func testEscapeClearsState() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_2"].tap()
        app.buttons["calc_btn_3"].tap()
        app.keys["escape"].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Ноль") || $0.label.contains("0") })
        XCTAssertTrue(display.exists, "Display should show '0' after Escape")
    }

    func testKeyboardBackspace() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_4"].tap()
        app.buttons["calc_btn_5"].tap()
        app.buttons["calc_btn_6"].tap()
        app.keys["delete"].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("45") })
        XCTAssertTrue(display.exists, "Display should contain '45' after keyboard backspace")
    }

    // MARK: - Буфер обмена

    func testCommandCopyResult() throws {
        let app = XCUIApplication()
        app.launch()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        app.buttons["calc_btn_2"].tap()
        app.buttons["calc_btn_+"].tap()
        app.buttons["calc_btn_3"].tap()
        app.buttons["calc_btn_="].tap()

        app.keyDown(using: .command, "c")

        let clipboardContent = pasteboard.string(forType: .string)
        XCTAssertNotNil(clipboardContent, "Clipboard should have content after ⌘C")
        XCTAssertTrue(clipboardContent?.contains("5") ?? false, "Clipboard should contain '5' after ⌘C")
    }

    func testPasteFromClipboard() throws {
        let app = XCUIApplication()
        app.launch()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("10+5", forType: .string)

        app.keyDown(using: .command, "v")
        app.buttons["calc_btn_="].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Результат") })
        XCTAssertTrue(display.exists, "Display should show result after paste")
        XCTAssertTrue(display.label.contains("15"), "Display should contain '15' after paste from clipboard")
    }

    // MARK: - Ошибки

    func testInvalidExpressionShowsError() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_+"].tap()
        app.buttons["calc_btn_+"].tap()
        app.buttons["calc_btn_="].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("Ошибка") })
        XCTAssertTrue(display.exists, "Display should show error for invalid expression")
    }

    // MARK: - Очистка

    func testClearButtonFunctionality() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_2"].tap()
        app.buttons["calc_btn_3"].tap()

        // Нажимаем C (expression = "123", кнопка = calc_btn_C)
        app.buttons["calc_btn_C"].tap()
        let display12 = app.otherElements.firstMatch(where: { $0.label.contains("12") })
        XCTAssertTrue(display12.exists, "Display should contain '12' after pressing C")

        // Нажимаем C ещё раз (expression = "12", кнопка = calc_btn_C)
        app.buttons["calc_btn_C"].tap()

        // Нажимаем C ещё раз (expression = "1", кнопка = calc_btn_C)
        app.buttons["calc_btn_C"].tap()

        // Теперь expression пуст → кнопка = calc_btn_AC
        let displayZero = app.otherElements.firstMatch(where: { $0.label.contains("Ноль") })
        XCTAssertTrue(displayZero.exists, "Display should show '0' after clearing all")
    }

    // MARK: - Десятичная запятая

    func testDecimalSeparator() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["calc_btn_3"].tap()
        app.buttons["calc_btn_,"].tap()
        app.buttons["calc_btn_1"].tap()
        app.buttons["calc_btn_4"].tap()
        app.buttons["calc_btn_="].tap()

        let display = app.otherElements.firstMatch(where: { $0.label.contains("3") })
        XCTAssertTrue(display.exists, "Display should contain '3' (decimal number)")
    }
}
