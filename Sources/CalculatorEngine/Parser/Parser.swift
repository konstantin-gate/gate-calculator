import Foundation

/// Парсер математических выражений.
///
/// Использует алгоритм сортировочной станции (Shunting Yard) для преобразования
/// инфиксной записи в обратную польскую нотацию (RPN), а затем строит
/// абстрактное синтаксическое дерево (AST).
public struct Parser: Sendable {

    /// Парсит последовательность токенов в AST.
    public func parse(_ tokens: [Token]) throws -> ExpressionNode {
        guard !tokens.isEmpty else {
            throw CalculatorError.emptyExpression
        }

        let rpn = try toRPN(tokens)
        return try buildAST(from: rpn)
    }

    private func toRPN(_ tokens: [Token]) throws -> [Token] {
        var output: [Token] = []
        var operatorStack: [Token] = []

        for token in tokens {
            switch token {
            case .number:
                output.append(token)

            case .leftParenthesis:
                operatorStack.append(token)

            case .rightParenthesis:
                while let top = operatorStack.last, !top.isLeftParen {
                    output.append(operatorStack.removeLast())
                }
                // ИСПРАВЛЕНИЕ C-05a: правая скобка без левой → extraClosingParenthesis
                guard operatorStack.last?.isLeftParen == true else {
                    throw CalculatorError.extraClosingParenthesis
                }
                operatorStack.removeLast()

            case .binaryOperator:
                while let top = operatorStack.last,
                      top.isOperator,
                      !top.isLeftParen {
                    if top.precedenceValue > token.precedenceValue ||
                        (top.precedenceValue == token.precedenceValue && top.isLeftAssoc) {
                        output.append(operatorStack.removeLast())
                    } else {
                        break
                    }
                }
                operatorStack.append(token)

            case .unaryMinus:
                while let top = operatorStack.last,
                      top.isOperator,
                      !top.isLeftParen {
                    if top.precedenceValue > token.precedenceValue ||
                        (top.precedenceValue == token.precedenceValue && top.isLeftAssoc) {
                        output.append(operatorStack.removeLast())
                    } else {
                        break
                    }
                }
                operatorStack.append(token)

            case .percent:
                while let top = operatorStack.last, !top.isLeftParen {
                    if top.precedenceValue > token.precedenceValue {
                        output.append(operatorStack.removeLast())
                    } else {
                        break
                    }
                }
                output.append(token)
            }
        }

        // ИСПРАВЛЕНИЕ C-05b: различаем left и right paren в остатке стека
        while let top = operatorStack.popLast() {
            if top.isLeftParen {
                throw CalculatorError.missingClosingParenthesis
            }
            if top.isRightParen {
                throw CalculatorError.extraClosingParenthesis
            }
            output.append(top)
        }

        return output
    }

    private func buildAST(from rpn: [Token]) throws -> ExpressionNode {
        var stack: [ExpressionNode] = []

        for token in rpn {
            switch token {
            case .number(let value):
                stack.append(.number(value))

            case .binaryOperator(let op):
                guard stack.count >= 2 else {
                    throw CalculatorError.invalidExpression("Invalid expression")
                }
                let right = stack.removeLast()
                let left = stack.removeLast()
                stack.append(.binary(op, left, right))

            case .unaryMinus:
                guard let value = stack.popLast() else {
                    throw CalculatorError.invalidExpression("Invalid expression")
                }
                stack.append(.unaryMinus(value))

            case .percent:
                guard let value = stack.popLast() else {
                    throw CalculatorError.invalidExpression("Invalid expression")
                }
                let hundred = Decimal(string: "100")!
                stack.append(.binary(.divide, value, .number(hundred)))

            case .leftParenthesis, .rightParenthesis:
                throw CalculatorError.invalidExpression("Unexpected parenthesis")
            }
        }

        guard stack.count == 1 else {
            throw CalculatorError.invalidExpression("Invalid expression")
        }

        return stack.removeLast()
    }
}
