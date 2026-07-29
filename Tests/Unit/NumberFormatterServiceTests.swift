import XCTest
@testable import CalculatorApp

// MARK: - Тесты NumberFormatterService

@MainActor
final class NumberFormatterServiceTests: XCTestCase {

    // MARK: - Базовое форматирование целых чисел

    func testFormat_WholeNumber() {
        let result = NumberFormatterService.shared.format(Decimal(42))
        XCTAssertTrue(result.contains("42"))
    }

    func testFormat_Zero() {
        let result = NumberFormatterService.shared.format(Decimal(0))
        XCTAssertEqual(result, "0")
    }

    func testFormat_SmallWholeNumber() {
        let value = Decimal(string: "15")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.contains("15"))
    }

    // MARK: - Форматирование дробных чисел

    func testFormat_DecimalNumber() {
        let value = Decimal(string: "3.14")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.contains("3,14"))
    }

    func testFormat_LargeFraction() {
        let value = Decimal(string: "1234.5678901234")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.contains("1 234,5678901234"))
    }

    func testFormat_ShortFraction() {
        let value = Decimal(string: "0.5")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.contains("0,5"))
    }

    // MARK: - Отрицательные числа

    func testFormat_NegativeWholeNumber() {
        let result = NumberFormatterService.shared.format(-Decimal(42))
        XCTAssertTrue(result.hasPrefix("-"))
        XCTAssertTrue(result.contains("42"))
    }

    func testFormat_NegativeDecimal() {
        let value = Decimal(string: "3.14")!
        let result = NumberFormatterService.shared.format(-value)
        XCTAssertTrue(result.hasPrefix("-"))
        XCTAssertTrue(result.contains("3,14"))
    }

    // MARK: - Экспоненциальный формат (большие числа)

    func testFormat_Exponential_ThresholdAt1e12() {
        let value = Decimal(string: "1e12")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.contains("e"))
        XCTAssertFalse(result.contains(" "))
    }

    func testFormat_Exponential_LargeNumber() {
        let value = Decimal(string: "1234567890123")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.contains("e"))
    }

    func testFormat_Exponential_VeryLargeNumber() {
        let value = Decimal(string: "1e20")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.contains("e"))
    }

    // MARK: - Экспоненциальный формат (малые числа)

    func testFormat_Exponential_SmallNumber() {
        let value = Decimal(string: "0.0000001")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.contains("e-"))
    }

    func testFormat_Exponential_NegativeSmallNumber() {
        let value = Decimal(string: "-0.0000001")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.hasPrefix("-"))
        XCTAssertTrue(result.contains("e-"))
    }

    // MARK: - Граничные значения

    func testFormat_Boundary_Exactly1e12() {
        let value = Decimal(string: "1000000000000")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertTrue(result.contains("e"))
    }

    func testFormat_Boundary_JustBelow1e12() {
        let value = Decimal(string: "999999999999")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertFalse(result.contains("E"))
        XCTAssertTrue(result.contains(" "))
    }

    func testFormat_Boundary_Zero_NotExponential() {
        let result = NumberFormatterService.shared.format(Decimal(0))
        XCTAssertEqual(result, "0")
    }

    func testFormat_Boundary_Exactly0_000001() {
        let value = Decimal(string: "0.000001")!
        let result = NumberFormatterService.shared.format(value)
        XCTAssertFalse(result.contains("E"))
        XCTAssertFalse(result.contains("e-"))
    }

    // MARK: - Граничные значения Decimal

    /// Проверяет форматирование максимально возможного числа Decimal (экспоненциальный формат).
    func testFormat_MaxDecimal() {
        let maxDecimal = Decimal(sign: .plus, exponent: 127, significand: 1)
        let result = NumberFormatterService.shared.format(maxDecimal)
        XCTAssertTrue(result.contains("e"), "Экспоненциальный формат для большого числа")
    }

    /// Проверяет форматирование отрицательного нуля (должен возвращать "0" без знака минус).
    func testFormat_NegativeZero() {
        let negativeZero = -Decimal(0)
        let result = NumberFormatterService.shared.format(negativeZero)
        XCTAssertEqual(result, "0")
    }
}
