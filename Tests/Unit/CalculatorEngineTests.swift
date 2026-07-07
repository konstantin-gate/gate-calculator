import XCTest
@testable import CalculatorEngine

final class CalculatorEngineTests: XCTestCase {

    private let engine = CalculatorEngine()

    // MARK: - Basic Arithmetic

    func testEvaluate_SimpleAddition() throws {
        let result = try engine.evaluate("15+16")
        XCTAssertEqual(result, 31)
    }

    func testEvaluate_SimpleSubtraction() throws {
        let result = try engine.evaluate("20-8")
        XCTAssertEqual(result, 12)
    }

    func testEvaluate_SimpleMultiplication() throws {
        let result = try engine.evaluate("6*7")
        XCTAssertEqual(result, 42)
    }

    func testEvaluate_SimpleDivision() throws {
        let result = try engine.evaluate("15/4")
        XCTAssertEqual(result, Decimal(string: "3.75")!)
    }

    // MARK: - Operator Precedence

    func testEvaluate_MultiplicationBeforeAddition() throws {
        let result = try engine.evaluate("15+16*5")
        XCTAssertEqual(result, 95) // 15 + (16*5) = 15 + 80 = 95
    }

    func testEvaluate_ParenthesesOverridePrecedence() throws {
        let result = try engine.evaluate("(15+16)*5")
        XCTAssertEqual(result, 155) // (15+16)*5 = 31*5 = 155
    }

    func testEvaluate_NestedParentheses() throws {
        let result = try engine.evaluate("((15+16)*5)/3")
        let expected = Decimal(string: "51.6666666667")!
        XCTAssertEqual(result, expected)
    }

    // MARK: - Whitespace Handling

    func testEvaluate_WhitespaceVariations() throws {
        let r1 = try engine.evaluate("15+16")
        let r2 = try engine.evaluate("15 + 16")
        let r3 = try engine.evaluate(" 15 + 16 ")
        XCTAssertEqual(r1, r2)
        XCTAssertEqual(r2, r3)
    }

    // MARK: - Negative Numbers

    func testEvaluate_UnaryMinus() throws {
        let result = try engine.evaluate("-5+12")
        XCTAssertEqual(result, 7)
    }

    func testEvaluate_UnaryMinusInParentheses() throws {
        let result = try engine.evaluate("-(15+16)")
        XCTAssertEqual(result, -31)
    }

    func testEvaluate_NegativeInParentheses() throws {
        let result = try engine.evaluate("(-15+6)")
        XCTAssertEqual(result, -9)
    }

    func testEvaluate_UnaryMinusAfterOperator() throws {
        let result = try engine.evaluate("5*-3")
        XCTAssertEqual(result, -15)
    }

    // MARK: - Decimals

    func testEvaluate_DecimalMultiplication() throws {
        let result = try engine.evaluate("3.1415*5")
        XCTAssertEqual(result, Decimal(string: "15.7075")!)
    }

    func testEvaluate_DecimalAddition_NoRoundingError() throws {
        let result = try engine.evaluate("0.1+0.2")
        XCTAssertEqual(result, Decimal(string: "0.3")!)
    }

    // MARK: - Long Expressions

    func testEvaluate_LongAddition() throws {
        let result = try engine.evaluate("15+16+17+18")
        XCTAssertEqual(result, 66)
    }

    func testEvaluate_LongExpressionWithSpaces() throws {
        let result = try engine.evaluate("(15 +16+17 ) /4")
        XCTAssertEqual(result, Decimal(string: "12.5")!)
    }

    // MARK: - Percent

    func testEvaluate_Percent() throws {
        let result = try engine.evaluate("50%")
        XCTAssertEqual(result, Decimal(string: "0.5")!)
    }

    func testEvaluate_PercentHundred() throws {
        let result = try engine.evaluate("100%")
        XCTAssertEqual(result, Decimal(string: "1.0")!)
    }

    func testEvaluate_PercentWithMultiplication() throws {
        let result = try engine.evaluate("100*5%")
        XCTAssertEqual(result, 5) // 100 * (5/100) = 5
    }

    func testEvaluate_PercentWithDivision() throws {
        let result = try engine.evaluate("100/5%")
        XCTAssertEqual(result, 2000) // 100 / (5/100) = 2000
    }

    func testEvaluate_PercentWithAddition() throws {
        let result = try engine.evaluate("100+5%")
        XCTAssertEqual(result, Decimal(string: "100.05")!) // 100 + (5/100) = 100.05
    }

    func testEvaluate_PercentWithSubtraction() throws {
        let result = try engine.evaluate("100-5%")
        XCTAssertEqual(result, Decimal(string: "99.95")!) // 100 - (5/100) = 99.95
    }

    func testEvaluate_PercentAfterParentheses() throws {
        let result = try engine.evaluate("(50+10)%")
        XCTAssertEqual(result, Decimal(string: "0.6")!) // (50+10)/100 = 0.6
    }

    // MARK: - Special Cases from Section 39

    func testSpecialCase_HexNumber() throws {
        let result = try engine.evaluate("0xFF")
        XCTAssertEqual(result, 255)
    }

    func testSpecialCase_BinaryNumber() throws {
        let result = try engine.evaluate("0b1010")
        XCTAssertEqual(result, 10)
    }

    func testSpecialCase_OctalNumber() throws {
        let result = try engine.evaluate("0o77")
        XCTAssertEqual(result, 63)
    }

    func testSpecialCase_ExponentialNotation() throws {
        let result = try engine.evaluate("1.5e3")
        XCTAssertEqual(result, 1500)
    }

    func testSpecialCase_Pi() throws {
        let result = try engine.evaluate("π")
        XCTAssertTrue(result.description.hasPrefix("3.14159265358979"))
    }

    func testSpecialCase_PiMultiplication() throws {
        let result = try engine.evaluate("π*2")
        XCTAssertTrue(result.description.hasPrefix("6.28318530717958"))
    }

    func testSpecialCase_EulerNumber() throws {
        let result = try engine.evaluate("e")
        XCTAssertTrue(result.description.hasPrefix("2.71828182845905"))
    }

    func testSpecialCase_ThousandsSeparator() throws {
        let result = try engine.evaluate("1,000,000")
        XCTAssertEqual(result, 1000000)
    }

    func testSpecialCase_EqualsAtEnd() throws {
        let result = try engine.evaluate("(15+16)/4=")
        XCTAssertEqual(result, Decimal(string: "7.75")!)
    }

    func testSpecialCase_MultipleLines() throws {
        let result = try engine.evaluate("15+16\n20+30")
        XCTAssertEqual(result, 31) // Only first line processed
    }

    // MARK: - Error Cases

    func testError_DivisionByZero() {
        XCTAssertThrowsError(try engine.evaluate("1/0"))
    }

    func testError_InvalidCharacter() {
        XCTAssertThrowsError(try engine.evaluate("15+a"))
    }

    func testError_MissingParenthesis() {
        XCTAssertThrowsError(try engine.evaluate("(15+16"))
    }

    func testError_ExtraParenthesis() {
        XCTAssertThrowsError(try engine.evaluate("15+16)"))
    }

    func testError_NaN() {
        XCTAssertThrowsError(try engine.evaluate("NaN"))
    }

    func testError_Infinity() {
        XCTAssertThrowsError(try engine.evaluate("Infinity"))
    }

    func testError_DoubleOperator() {
        XCTAssertThrowsError(try engine.evaluate("5++3"))
    }

    func testError_EmptyExpression() {
        XCTAssertThrowsError(try engine.evaluate(""))
    }

    func testError_InvalidPercent() {
        XCTAssertThrowsError(try engine.evaluate("%*"))
    }

    // MARK: - Integration Tests

    func testEvaluate_MainScenario() throws {
        let result = try engine.evaluate("(15+16+17+18)/4")
        XCTAssertEqual(result, Decimal(string: "16.5")!)
    }

    func testEvaluate_AllSpecialCases() throws {
        let cases: [(String, Decimal?)] = [
            ("15+16", 31),
            ("(15+16)*5", 155),
            ("-5+12", 7),
            ("-(15+16)", -31),
            ("3.1415*5", Decimal(string: "15.7075")!),
            ("50%", Decimal(string: "0.5")!),
            ("100 * 5%", 5),
            ("100 / 5%", 2000),
            ("0xFF", 255),
            ("0b1010", 10),
            ("0o77", 63),
            ("1.5e3", 1500),
        ]

        for (expression, expected) in cases {
            let result = try? engine.evaluate(expression)
            XCTAssertEqual(result, expected, "Failed for: \(expression)")
        }
    }

    func testEvaluate_AllErrorCases() {
        let cases = [
            "1/0",
            "15+a",
            "(15+16",
            "15+16)",
            "NaN",
            "Infinity",
        ]

        for expression in cases {
            let result = try? engine.evaluate(expression)
            XCTAssertNil(result, "Should fail for: \(expression)")
        }
    }
}
