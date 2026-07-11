import XCTest
@testable import CalculatorEngine

final class ParserTests: XCTestCase {

    func testParse_SimpleAddition() throws {
        let parser = Parser()
        let tokens: [Token] = [
            .number(15),
            .binaryOperator(.add),
            .number(16)
        ]
        let ast = try parser.parse(tokens)
        if case .binary(.add, .number(15), .number(16)) = ast {
            // OK
        } else {
            XCTFail("Expected binary add node")
        }
    }

    func testParse_MultiplicationPrecedence() throws {
        let parser = Parser()
        let tokens: [Token] = [
            .number(15),
            .binaryOperator(.add),
            .number(16),
            .binaryOperator(.multiply),
            .number(5)
        ]
        let ast = try parser.parse(tokens)
        if case .binary(.add, .number(15), let right) = ast {
            if case .binary(.multiply, .number(16), .number(5)) = right {
                // OK - 15 + (16 * 5)
            } else {
                XCTFail("Expected 16 * 5 on right side")
            }
        } else {
            XCTFail("Expected binary add node at root")
        }
    }

    func testParse_Parentheses() throws {
        let parser = Parser()
        let tokens: [Token] = [
            .leftParenthesis,
            .number(15),
            .binaryOperator(.add),
            .number(16),
            .rightParenthesis,
            .binaryOperator(.multiply),
            .number(5)
        ]
        let ast = try parser.parse(tokens)
        if case .binary(.multiply, let left, .number(5)) = ast {
            if case .binary(.add, .number(15), .number(16)) = left {
                // OK - (15 + 16) * 5
            } else {
                XCTFail("Expected (15 + 16) on left side")
            }
        } else {
            XCTFail("Expected binary multiply node at root")
        }
    }

    func testParse_UnaryMinus() throws {
        let parser = Parser()
        let tokens: [Token] = [
            .unaryMinus,
            .number(5),
            .binaryOperator(.add),
            .number(12)
        ]
        let ast = try parser.parse(tokens)
        if case .binary(.add, let left, .number(12)) = ast {
            if case .unaryMinus(.number(5)) = left {
                // OK - (-5) + 12
            } else {
                XCTFail("Expected unary minus on left")
            }
        } else {
            XCTFail("Expected binary add node at root")
        }
    }

    func testParse_Percent() throws {
        let parser = Parser()
        let tokens: [Token] = [
            .number(50),
            .percent
        ]
        let ast = try parser.parse(tokens)
        if case .binary(.divide, .number(50), let right) = ast {
            if case .number(let v) = right, v == 100 {
                // OK - 50 / 100
            } else {
                XCTFail("Expected divide by 100")
            }
        } else {
            XCTFail("Expected binary divide node")
        }
    }

    func testParse_EmptyExpression() {
        let parser = Parser()
        XCTAssertThrowsError(try parser.parse([]))
    }

    func testParse_MissingClosingParenthesis() {
        let parser = Parser()
        let tokens: [Token] = [
            .leftParenthesis,
            .number(15),
            .binaryOperator(.add),
            .number(16)
        ]
        XCTAssertThrowsError(try parser.parse(tokens))
    }

    func testParse_ExtraClosingParenthesis() {
        let parser = Parser()
        let tokens: [Token] = [
            .number(15),
            .binaryOperator(.add),
            .number(16),
            .rightParenthesis
        ]
        XCTAssertThrowsError(try parser.parse(tokens))
    }

    func testParse_DoubleOperator() {
        let parser = Parser()
        let tokens: [Token] = [
            .number(15),
            .binaryOperator(.add),
            .binaryOperator(.add),
            .number(16)
        ]
        XCTAssertThrowsError(try parser.parse(tokens))
    }

    func testParse_NestedParentheses() throws {
        let parser = Parser()
        let tokens: [Token] = [
            .leftParenthesis,
            .leftParenthesis,
            .number(15),
            .binaryOperator(.add),
            .number(16),
            .rightParenthesis,
            .binaryOperator(.multiply),
            .number(5),
            .rightParenthesis,
            .binaryOperator(.divide),
            .number(3)
        ]
        let ast = try parser.parse(tokens)
        if case .binary(.divide, let left, .number(3)) = ast {
            if case .binary(.multiply, let innerLeft, .number(5)) = left {
                if case .binary(.add, .number(15), .number(16)) = innerLeft {
                    // OK - ((15 + 16) * 5) / 3
                } else {
                    XCTFail("Expected nested structure")
                }
            } else {
                XCTFail("Expected multiply node")
            }
        } else {
            XCTFail("Expected divide at root")
        }
    }

    func testParse_PercentWithMultiplication() throws {
        let parser = Parser()
        let tokens: [Token] = [
            .number(100),
            .binaryOperator(.multiply),
            .number(5),
            .percent
        ]
        let ast = try parser.parse(tokens)
        if case .binary(.multiply, .number(100), let right) = ast {
            if case .binary(.divide, .number(5), _) = right {
                // OK - 100 * (5 / 100)
            } else {
                XCTFail("Expected percent as divide")
            }
        } else {
            XCTFail("Expected multiply at root")
        }
    }

    func testParse_PercentWithAddition() throws {
        let parser = Parser()
        let tokens: [Token] = [
            .number(100),
            .binaryOperator(.add),
            .number(5),
            .percent
        ]
        let ast = try parser.parse(tokens)
        if case .binary(.add, .number(100), let right) = ast {
            if case .percentOf(.add, .number(100), _) = right {
                // OK - percentOf(.add, 100, 5) → 100 + (100 × 5/100) = 105
            } else {
                XCTFail("Expected percentOf node")
            }
        } else {
            XCTFail("Expected add at root")
        }
    }

    func testParse_PercentWithSubtraction() throws {
        let parser = Parser()
        let tokens: [Token] = [
            .number(100),
            .binaryOperator(.subtract),
            .number(5),
            .percent
        ]
        let ast = try parser.parse(tokens)
        if case .binary(.subtract, .number(100), let right) = ast {
            if case .percentOf(.subtract, .number(100), let v) = right {
                XCTAssertEqual(v, 5)
            } else {
                XCTFail("Expected percentOf node")
            }
        } else {
            XCTFail("Expected subtract at root")
        }
    }

    func testParse_RelativePercent_Standalone() throws {
        let parser = Parser()
        let tokens: [Token] = [.number(50), .percent]
        let ast = try parser.parse(tokens)
        if case .binary(.divide, .number(50), let right) = ast {
            if case .number(let v) = right, v == 100 {
                // OK - 50 / 100 (absolute, unchanged)
            } else { XCTFail("Expected divide by 100") }
        } else { XCTFail("Expected binary divide node") }
    }
}
