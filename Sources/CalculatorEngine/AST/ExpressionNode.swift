import Foundation

/// Узел абстрактного синтаксического дерева (AST).
///
/// Представляет структуру математического выражения после парсинга.
/// Используется для рекурсивного вычисления результата.
public indirect enum ExpressionNode: Sendable {
    /// Числовое значение (листовой узел).
    case number(Decimal)

    /// Унарный минус (отрицательное число или операция отрицания).
    case unaryMinus(ExpressionNode)

    /// Бинарная операция (сложение, вычитание, умножение, деление).
    case binary(BinaryOperator, ExpressionNode, ExpressionNode)
}
