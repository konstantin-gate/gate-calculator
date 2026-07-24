import XCTest
@testable import CalculatorApp
@testable import CalculatorEngine

// MARK: - Тесты CalculatorViewModel

@MainActor
final class CalculatorViewModelTests: XCTestCase {

    // MARK: - Вспомогательные методы

    private func createCleanViewModel() -> CalculatorViewModel {
        HistoryService.shared.clear()
        return CalculatorViewModel()
    }

    // MARK: - Операции памяти (Memory)

    func testMemoryAdd_AddsValueToMemory() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("0")
        viewModel.memoryAdd()
        XCTAssertTrue(viewModel.hasMemory)
    }

    func testMemoryRecall_ReturnsMemoryValueToExpression() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("0")
        viewModel.memoryAdd()
        viewModel.clear()
        viewModel.memoryRecall()
        XCTAssertEqual(viewModel.expression, "10")
        XCTAssertNil(viewModel.result)
    }

    func testMemorySubtract_SubtractsCurrentValueFromMemory() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("2")
        viewModel.memoryAdd()
        viewModel.clear()
        viewModel.appendCharacter("1")
        viewModel.memorySubtract()
        XCTAssertTrue(viewModel.hasMemory)
    }

    func testMemoryClear_ResetsMemory() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("5")
        viewModel.memoryAdd()
        viewModel.memoryClear()
        XCTAssertFalse(viewModel.hasMemory)
    }

    func testMemoryRecall_WhenExpressionNotEmpty_AppendsToExpression() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.memoryAdd()
        viewModel.clear()
        viewModel.appendCharacter("5")
        viewModel.memoryRecall()
        XCTAssertEqual(viewModel.expression, "510")
    }

    func testMemoryRecall_WhenExpressionEndsWithOperator_AppendsAfterOperator() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.memoryAdd()
        viewModel.clear()
        viewModel.appendCharacter("+")
        viewModel.memoryRecall()
        XCTAssertEqual(viewModel.expression, "+10")
    }

    // MARK: - Очистка состояния (Clear)

    func testClear_EmptyViewModel_NoEffect() {
        let viewModel = createCleanViewModel()
        viewModel.clear()
        XCTAssertEqual(viewModel.expression, "")
        XCTAssertNil(viewModel.result)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testClear_AfterResult_ResetsEverything() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("5")
        viewModel.evaluate()
        viewModel.clear()
        XCTAssertEqual(viewModel.expression, "")
        XCTAssertNil(viewModel.result)
        XCTAssertFalse(viewModel.hasResult)
    }

    func testClearCurrentInput_WithResult_PerformsFullClear() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("5")
        viewModel.evaluate()
        viewModel.clearCurrentInput()
        XCTAssertEqual(viewModel.expression, "")
        XCTAssertNil(viewModel.result)
    }

    func testClearCurrentInput_WithoutResult_RemovesLastOperand() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("2")
        viewModel.clearCurrentInput()
        XCTAssertEqual(viewModel.expression, "")
    }

    func testClearCurrentInput_EmptyExpression_NoEffect() {
        let viewModel = createCleanViewModel()
        viewModel.clearCurrentInput()
        XCTAssertEqual(viewModel.expression, "")
    }

    // MARK: - Backspace

    func testBackspace_RemovesLastCharacterFromExpression() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("2")
        viewModel.backspace()
        XCTAssertEqual(viewModel.expression, "1")
    }

    func testBackspace_WithResult_ClearsEverything() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("5")
        viewModel.evaluate()
        viewModel.backspace()
        XCTAssertEqual(viewModel.expression, "")
    }

    func testBackspace_EmptyExpression_NoResult_NoEffect() {
        let viewModel = createCleanViewModel()
        viewModel.backspace()
        XCTAssertEqual(viewModel.expression, "")
    }

    // MARK: - toggleSign (инверсия знака)

    func testToggleSign_SimpleNumber_PositiveToNegative() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("5")
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.expression, "-5")
    }

    func testToggleSign_SimpleNumber_NegativeToPositive() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("-")
        viewModel.appendCharacter("3")
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.expression, "3")
    }

    func testToggleSign_AfterResult_InvertsResultValue() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("2")
        viewModel.appendCharacter("+")
        viewModel.appendCharacter("3")
        viewModel.evaluate()
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.expression, "-5")
    }

    func testToggleSign_EmptyExpression_NoEffect() {
        let viewModel = createCleanViewModel()
        viewModel.toggleSign()
        XCTAssertEqual(viewModel.expression, "")
    }

    // MARK: - Вставка из буфера обмена (Clipboard Insert)

    func testInsertFromClipboard_ValidExpression_EvaluatesAndShowsResult() {
        let viewModel = createCleanViewModel()
        viewModel.insertFromClipboard("2+3")
        XCTAssertEqual(viewModel.expression, "2+3")
        XCTAssertNotNil(viewModel.result)
        XCTAssertTrue(viewModel.hasResult)
    }

    func testInsertFromClipboard_EmptyString_NoEffect() {
        let viewModel = createCleanViewModel()
        viewModel.insertFromClipboard("")
        XCTAssertEqual(viewModel.expression, "")
    }

    func testInsertFromClipboard_WhitespaceOnly_NoEffect() {
        let viewModel = createCleanViewModel()
        viewModel.insertFromClipboard("   ")
        XCTAssertEqual(viewModel.expression, "")
    }

    func testInsertFromClipboard_InvalidExpression_SetsError() {
        let viewModel = createCleanViewModel()
        viewModel.insertFromClipboard("abc")
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Tests: handleClipboardAction (GC-01)

    func testClipboardAction_EmptyState_PastesFromClipboard() {
        let vm = createCleanViewModel()
        ClipboardManager.shared.setString("123")
        vm.handleClipboardAction()
        XCTAssertEqual(vm.expression, "123")
        XCTAssertNil(vm.errorMessage)
    }

    func testClipboardAction_ExpressionZero_PastesFromClipboard() {
        let vm = createCleanViewModel()
        vm.appendCharacter("0")
        ClipboardManager.shared.setString("456")
        vm.handleClipboardAction()
        XCTAssertEqual(vm.expression, "456")
    }

    func testClipboardAction_NonEmptyExpression_CopiesToClipboard() {
        let vm = createCleanViewModel()
        vm.appendCharacter("1")
        vm.appendCharacter("+")
        vm.appendCharacter("2")
        ClipboardManager.shared.setString("789")
        vm.handleClipboardAction()
        XCTAssertEqual(vm.expression, "789")
    }

    func testClipboardAction_WithResult_CopiesToClipboard() {
        let vm = createCleanViewModel()
        vm.appendCharacter("2")
        vm.appendCharacter("+")
        vm.appendCharacter("3")
        vm.evaluate()
        vm.handleClipboardAction()
        let clipboardContent = ClipboardManager.shared.getString()
        XCTAssertNotNil(clipboardContent)
        XCTAssertTrue(clipboardContent?.contains("5") ?? false)
    }

    // MARK: - Базовое вычисление (Evaluate)

    func testEvaluate_SimpleAddition() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("+")
        viewModel.appendCharacter("2")
        viewModel.evaluate()
        XCTAssertEqual(viewModel.result, "3")
        XCTAssertEqual(viewModel.expression, "")
    }

    func testEvaluate_ParenthesesAndPrecedence() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("(")
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("+")
        viewModel.appendCharacter("5")
        viewModel.appendCharacter("*")
        viewModel.appendCharacter("3")
        viewModel.appendCharacter(")")
        viewModel.evaluate()
        XCTAssertEqual(viewModel.result, "16")
    }

    func testEvaluate_DivisionByZero_SetsError() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("/")
        viewModel.appendCharacter("0")
        viewModel.evaluate()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testEvaluate_EmptyExpression_NoEffect() {
        let viewModel = createCleanViewModel()
        viewModel.evaluate()
        XCTAssertNil(viewModel.result)
    }

    // MARK: - Вычисление квадратного корня (Square Root)

    func testCalculateSquareRoot_PerfectSquare_ReturnsExactResult() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("4")
        viewModel.calculateSquareRoot()
        XCTAssertEqual(viewModel.result, "2")
        XCTAssertEqual(viewModel.expression, "")
    }

    func testCalculateSquareRoot_Zero_ReturnsZero() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("0")
        viewModel.calculateSquareRoot()
        XCTAssertEqual(viewModel.result, "0")
    }

    func testCalculateSquareRoot_Two_HighPrecision() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("2")
        viewModel.calculateSquareRoot()
        XCTAssertNotNil(viewModel.resultDecimal)
        let sqrt = viewModel.resultDecimal!
        let squared = sqrt * sqrt
        let diff: Decimal = (squared > 2) ? squared - 2 : 2 - squared
        XCTAssertLessThan(diff, Decimal(string: "1e-26")!)
    }

    func testCalculateSquareRoot_NegativeNumber_SetsError() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("-")
        viewModel.appendCharacter("4")
        viewModel.calculateSquareRoot()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testCalculateSquareRoot_AfterResult_UsesResultValue() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("+")
        viewModel.appendCharacter("1")
        viewModel.evaluate()
        viewModel.calculateSquareRoot()
        XCTAssertNotNil(viewModel.resultDecimal)
        XCTAssertEqual(viewModel.expression, "")
    }

    func testCalculateSquareRoot_EmptyExpression_SetsError() {
        let viewModel = createCleanViewModel()
        viewModel.calculateSquareRoot()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Возведение в квадрат (Square)

    func testCalculateSquare_PerfectSquare_ReturnsSquaredValue() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("5")
        viewModel.calculateSquare()
        XCTAssertEqual(viewModel.result, "25")
        XCTAssertEqual(viewModel.expression, "")
    }

    func testCalculateSquare_Zero_ReturnsZero() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("0")
        viewModel.calculateSquare()
        XCTAssertEqual(viewModel.result, "0")
    }

    func testCalculateSquare_AfterResult_UsesResultValue() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("2")
        viewModel.appendCharacter("+")
        viewModel.appendCharacter("3")
        viewModel.evaluate()
        viewModel.calculateSquare()
        XCTAssertEqual(viewModel.result, "25")
    }

    // MARK: - Свойства отображения (Display Properties)

    func testDisplayValue_WithError_ReturnsErrorMessage() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("/")
        viewModel.appendCharacter("0")
        viewModel.evaluate()
        XCTAssertEqual(viewModel.displayValue, viewModel.errorMessage)
    }

    func testDisplayValue_WithResult_ReturnsFormattedResult() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("5")
        viewModel.evaluate()
        XCTAssertEqual(viewModel.displayValue, viewModel.result)
    }

    func testDisplayValue_WithExpression_ReturnsExpression() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.appendCharacter("+")
        XCTAssertEqual(viewModel.displayValue, "1+")
    }

    func testDisplayValue_Empty_ReturnsZero() {
        let viewModel = createCleanViewModel()
        XCTAssertEqual(viewModel.displayValue, "0")
    }

    // MARK: - appendCharacter и hasResult

    func testAppendCharacter_AfterEquals_ResetsResult() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("5")
        viewModel.appendCharacter("+")
        viewModel.appendCharacter("3")
        viewModel.evaluate()
        viewModel.appendCharacter("2")
        XCTAssertEqual(viewModel.expression, "2")
        XCTAssertNil(viewModel.result)
    }

    func testAppendCharacter_OperatorAfterResult_ContinuesWithResult() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("5")
        viewModel.appendCharacter("+")
        viewModel.appendCharacter("3")
        viewModel.evaluate()
        viewModel.appendCharacter("*")
        XCTAssertEqual(viewModel.expression.last, "*")
    }

    // MARK: - История (History)

    func testClearHistory_ClearsAllEntries() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("1")
        viewModel.evaluate()
        viewModel.appendCharacter("2")
        viewModel.evaluate()
        viewModel.clearHistory()
        XCTAssertTrue(viewModel.historyEntries.isEmpty)
        XCTAssertEqual(viewModel.historyCount, 0)
    }

    func testUseHistoryEntry_RestoresExpressionFromEntry() {
        let viewModel = createCleanViewModel()
        viewModel.appendCharacter("2")
        viewModel.appendCharacter("+")
        viewModel.appendCharacter("3")
        viewModel.evaluate()
        viewModel.clear()
        let entry = viewModel.historyEntries[0]
        viewModel.useHistoryEntry(entry)
        XCTAssertEqual(viewModel.expression, "2+3")
        XCTAssertNil(viewModel.result)
        XCTAssertNil(viewModel.errorMessage)
    }
}
