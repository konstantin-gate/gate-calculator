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
}
