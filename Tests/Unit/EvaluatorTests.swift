import XCTest
@testable import CalculatorEngine

final class EvaluatorTests: XCTestCase {

    func testEvaluate_SimpleAddition() throws {
        let evaluator = Evaluator()
        let ast: ExpressionNode = .binary(.add, .number(15), .number(16))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, 31)
    }

    func testEvaluate_SimpleSubtraction() throws {
        let evaluator = Evaluator()
        let ast: ExpressionNode = .binary(.subtract, .number(20), .number(8))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, 12)
    }

    func testEvaluate_SimpleMultiplication() throws {
        let evaluator = Evaluator()
        let ast: ExpressionNode = .binary(.multiply, .number(6), .number(7))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, 42)
    }

    func testEvaluate_SimpleDivision() throws {
        let evaluator = Evaluator()
        let ast: ExpressionNode = .binary(.divide, .number(15), .number(4))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, Decimal(string: "3.75")!)
    }

    func testEvaluate_DivisionByZero() {
        let evaluator = Evaluator()
        let ast: ExpressionNode = .binary(.divide, .number(15), .number(0))
        XCTAssertThrowsError(try evaluator.evaluate(ast))
    }

    func testEvaluate_UnaryMinus() throws {
        let evaluator = Evaluator()
        let ast: ExpressionNode = .unaryMinus(.number(5))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, -5)
    }

    func testEvaluate_Percent() throws {
        let evaluator = Evaluator()
        let ast: ExpressionNode = .binary(.divide, .number(50), .number(100))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, Decimal(string: "0.5")!)
    }

    func testEvaluate_PercentFive() throws {
        let evaluator = Evaluator()
        let ast: ExpressionNode = .binary(.divide, .number(5), .number(100))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, Decimal(string: "0.05")!)
    }

    func testEvaluate_NestedExpression() throws {
        let evaluator = Evaluator()
        // (15 + 16) * 5 / 3
        let ast: ExpressionNode = .binary(.divide,
            .binary(.multiply,
                .binary(.add, .number(15), .number(16)),
                .number(5)),
            .number(3))
        let result = try evaluator.evaluate(ast)
        // (31 * 5) / 3 = 155 / 3 = 51.666...
        let expected = Decimal(string: "51.6666666667")!
        XCTAssertEqual(result, expected)
    }

    func testEvaluate_Precedence() throws {
        let evaluator = Evaluator()
        // 15 + 16 * 5 = 15 + 80 = 95
        let ast: ExpressionNode = .binary(.add, .number(15),
            .binary(.multiply, .number(16), .number(5)))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, 95)
    }

    func testEvaluate_ParenthesesOverride() throws {
        let evaluator = Evaluator()
        // (15 + 16) * 5 = 31 * 5 = 155
        let ast: ExpressionNode = .binary(.multiply,
            .binary(.add, .number(15), .number(16)),
            .number(5))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, 155)
    }

    func testEvaluate_Decimals() throws {
        let evaluator = Evaluator()
        // 0.1 + 0.2 should be exactly 0.3 with Decimal
        let ast: ExpressionNode = .binary(.add,
            .number(Decimal(string: "0.1")!),
            .number(Decimal(string: "0.2")!))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, Decimal(string: "0.3")!)
    }

    func testEvaluate_NegativeNumbers() throws {
        let evaluator = Evaluator()
        // -5 + 12 = 7
        let ast: ExpressionNode = .binary(.add,
            .unaryMinus(.number(5)),
            .number(12))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, 7)
    }

    func testEvaluate_NegativeResult() throws {
        let evaluator = Evaluator()
        // 5 - 12 = -7
        let ast: ExpressionNode = .binary(.subtract, .number(5), .number(12))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, -7)
    }

    func testEvaluate_PercentInExpression() throws {
        let evaluator = Evaluator()
        // 100 * (5 / 100) = 100 * 0.05 = 5
        let ast: ExpressionNode = .binary(.multiply, .number(100),
            .binary(.divide, .number(5), .number(100)))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, 5)
    }

    func testEvaluate_PercentDivision() throws {
        let evaluator = Evaluator()
        // 100 / (5 / 100) = 100 / 0.05 = 2000
        let ast: ExpressionNode = .binary(.divide, .number(100),
            .binary(.divide, .number(5), .number(100)))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, 2000)
    }

    func testEvaluate_DeeplyNested() throws {
        let evaluator = Evaluator()
        // (((2 + 3) * 4) - 5) / 3 = (5 * 4 - 5) / 3 = 15 / 3 = 5
        let ast: ExpressionNode = .binary(.divide,
            .binary(.subtract,
                .binary(.multiply,
                    .binary(.add, .number(2), .number(3)),
                    .number(4)),
                .number(5)),
            .number(3))
        let result = try evaluator.evaluate(ast)
        XCTAssertEqual(result, 5)
    }
}
