import XCTest
@testable import CalculatorEngine

final class TokenizerTests: XCTestCase {

    func testTokenize_EmptyString() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("")
        XCTAssertTrue(tokens.isEmpty)
    }

    func testTokenize_SimpleAddition() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("15+16")
        XCTAssertEqual(tokens.count, 3)
        if case .number(let v) = tokens[0] { XCTAssertEqual(v, 15) }
        if case .binaryOperator(let op) = tokens[1] { XCTAssertEqual(op, .add) }
        if case .number(let v) = tokens[2] { XCTAssertEqual(v, 16) }
    }

    func testTokenize_WithWhitespace() throws {
        let tokenizer = Tokenizer()
        let tokens1 = try tokenizer.tokenize("15+16")
        let tokens2 = try tokenizer.tokenize("15 + 16")
        let tokens3 = try tokenizer.tokenize(" 15 + 16 ")
        XCTAssertEqual(tokens1.count, tokens2.count)
        XCTAssertEqual(tokens2.count, tokens3.count)
    }

    func testTokenize_Parentheses() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("(15+16)")
        XCTAssertEqual(tokens.count, 5)
    }

    func testTokenize_EqualsSign() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("15+16=")
        XCTAssertEqual(tokens.count, 3)
    }

    func testTokenize_MultipleLines() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("15+16\n20+30")
        XCTAssertEqual(tokens.count, 3)
    }

    func testTokenize_ExponentialNotation() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("1.5e3")
        XCTAssertEqual(tokens.count, 1)
        if case .number(let v) = tokens[0] {
            XCTAssertEqual(v, 1500)
        } else {
            XCTFail("Expected number token")
        }
    }

    func testTokenize_ExponentialNotationNegative() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("1.5e-3")
        XCTAssertEqual(tokens.count, 1)
        if case .number(let v) = tokens[0] {
            XCTAssertEqual(v, 0.0015)
        } else {
            XCTFail("Expected number token")
        }
    }

    func testTokenize_HexNumber() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("0xFF")
        XCTAssertEqual(tokens.count, 1)
        if case .number(let v) = tokens[0] {
            XCTAssertEqual(v, 255)
        } else {
            XCTFail("Expected number token")
        }
    }

    func testTokenize_HexNumberUpper() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("0XAB")
        XCTAssertEqual(tokens.count, 1)
        if case .number(let v) = tokens[0] {
            XCTAssertEqual(v, 171)
        } else {
            XCTFail("Expected number token")
        }
    }

    func testTokenize_BinaryNumber() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("0b1010")
        XCTAssertEqual(tokens.count, 1)
        if case .number(let v) = tokens[0] {
            XCTAssertEqual(v, 10)
        } else {
            XCTFail("Expected number token")
        }
    }

    func testTokenize_OctalNumber() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("0o77")
        XCTAssertEqual(tokens.count, 1)
        if case .number(let v) = tokens[0] {
            XCTAssertEqual(v, 63)
        } else {
            XCTFail("Expected number token")
        }
    }

    func testTokenize_EulerNumberFollowedByDigit() {
        let tokenizer = Tokenizer()
        XCTAssertThrowsError(try tokenizer.tokenize("e3"))
    }

    func testTokenize_UnaryMinus() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("-5+12")
        XCTAssertEqual(tokens.count, 4)
    }

    func testTokenize_UnaryMinusAfterOperator() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("5*-3")
        XCTAssertEqual(tokens.count, 4) // 5, *, unaryMinus, 3
    }

    func testTokenize_Percent() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("50%")
        XCTAssertEqual(tokens.count, 2)
    }

    func testTokenize_InvalidCharacter() {
        let tokenizer = Tokenizer()
        XCTAssertThrowsError(try tokenizer.tokenize("15+a"))
    }

    func testTokenize_CommaAsDecimalSeparator() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("12,105")
        XCTAssertEqual(tokens.count, 1)
        if case .number(let v) = tokens[0] {
            XCTAssertEqual(v, Decimal(string: "12.105")!)
        } else {
            XCTFail("Expected number token")
        }
    }

    func testTokenize_DotAsDecimalSeparator() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("12.105")
        XCTAssertEqual(tokens.count, 1)
        if case .number(let v) = tokens[0] {
            XCTAssertEqual(v, Decimal(string: "12.105")!)
        } else {
            XCTFail("Expected number token")
        }
    }

    func testTokenize_NaN() {
        let tokenizer = Tokenizer()
        XCTAssertThrowsError(try tokenizer.tokenize("NaN"))
    }

    func testTokenize_Infinity() {
        let tokenizer = Tokenizer()
        XCTAssertThrowsError(try tokenizer.tokenize("Infinity"))
    }

    func testTokenize_DoubleOperator() {
        let tokenizer = Tokenizer()
        XCTAssertThrowsError(try tokenizer.tokenize("5++3"))
    }

    func testTokenize_Decimals() throws {
        let tokenizer = Tokenizer()
        let tokens1 = try tokenizer.tokenize("3.14")
        XCTAssertEqual(tokens1.count, 1)

        let tokens2 = try tokenizer.tokenize("0.5")
        XCTAssertEqual(tokens2.count, 1)

        let tokens3 = try tokenizer.tokenize("-0.25")
        XCTAssertEqual(tokens3.count, 2) // unaryMinus, 0.25
    }

    func testTokenize_ComplexExpression() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("((15+16)*5)/3")
        XCTAssertEqual(tokens.count, 10)
    }

    func testTokenize_PercentAfterParenthesis() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("(50+10)%")
        XCTAssertEqual(tokens.count, 6) // (, 50, +, 10, ), %
    }

    func testTokenize_PercentAfterOperator() throws {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize("100+10%")
        XCTAssertEqual(tokens.count, 5) // 100, +, 10, %
    }

    func testTokenize_DoublePercent() {
        let tokenizer = Tokenizer()
        XCTAssertThrowsError(try tokenizer.tokenize("100%%"))
    }
}
