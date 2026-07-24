import Foundation

/// Вычислительный движок калькулятора.
///
/// Фасадный тип, объединяющий Tokenizer, Parser и Evaluator.
/// Отвечает за полный цикл: строка → токены → AST → результат.
///
/// - Note: Движок является полностью независимым модулем и не содержит
///         зависимостей от SwiftUI или AppKit.
public struct CalculatorEngine: Sendable {

    /// Создаёт новый экземпляр вычислительного движка.
    public init() {}

    /// Вычисляет математическое выражение.
    ///
    /// Выполняет полную цепочку: предварительная обработка → токенизация →
    /// парсинг → построение AST → вычисление.
    ///
    /// - Parameter expression: Строка с математическим выражением.
    /// - Returns: Результат вычисления в виде `Decimal`.
    /// - Throws: `CalculatorError` если выражение некорректно.
    public func evaluate(_ expression: String) throws -> Decimal {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CalculatorError.emptyExpression
        }

        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize(trimmed)

        guard !tokens.isEmpty else {
            throw CalculatorError.emptyExpression
        }

        let parser = Parser()
        let ast = try parser.parse(tokens)

        let evaluator = Evaluator()
        return try evaluator.evaluate(ast)
    }

    // MARK: - Математические функции

    /// Вычисляет квадратный корень методом Ньютона (Герона) для Decimal.
    /// Квадратичная сходимость: не более 5–7 итераций для 28 значащих цифр.
    ///
    /// - Parameter value: Неотрицательное значение Decimal.
    /// - Returns: Квадратный корень из value с точностью до 1e-28.
    public static func newtonSquareRoot(_ value: Decimal) -> Decimal {
        guard value != 0 else { return Decimal(0) }

        var x = value >= 1 ? value : Decimal(1)
        let epsilon = EngineConstants.epsilon
        let maxIterations = EngineConstants.maxNewtonIterations

        for _ in 0..<maxIterations {
            let nextX = (x + value / x) / 2
            let diff = nextX > x ? nextX - x : x - nextX
            x = nextX
            if diff < epsilon { break }
        }

        return x
    }
}
