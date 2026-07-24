import Foundation

/// Вычислитель абстрактного синтаксического дерева.
///
/// Рекурсивно обходит AST и вычисляет результат математического выражения.
public struct Evaluator: Sendable {

    /// Вычисляет значение AST.
    ///
    /// - Parameter node: Корневой узел абстрактного синтаксического дерева.
    /// - Returns: Результат вычисления в виде `Decimal`.
    /// - Throws: `CalculatorError.divisionByZero` при делении на ноль.
    public func evaluate(_ node: ExpressionNode) throws -> Decimal {
        switch node {
        case .number(let value):
            return value

        case .unaryMinus(let inner):
            let val = try evaluate(inner)
            return -val

        case .binary(let op, let left, let right):
            let l = try evaluate(left)
            let r = try evaluate(right)

            switch op {
            case .add:
                return l + r
            case .subtract:
                return l - r
            case .multiply:
                return l * r
            case .divide:
                guard r != 0 else {
                    throw CalculatorError.divisionByZero
                }
                return l / r
            }

        case .percentOf(let op, let left, let percentValue):
            // Относительный %: left + (left × p/100) для .add
            //                 left - (left × p/100) для .subtract
            let l = try evaluate(left)
            let hundred = EngineConstants.hundred
            let percent = percentValue / hundred

            switch op {
            case .add:
                return l + l * percent
            case .subtract:
                return l - l * percent
            default:
                throw CalculatorError.invalidExpression("Invalid percent operator")
            }
        }
    }
}
