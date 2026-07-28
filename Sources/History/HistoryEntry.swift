import Foundation

/// Запись истории вычислений.
///
/// Содержит исходное выражение, результат вычисления и метку времени.
public struct HistoryEntry: Identifiable, Sendable {
    /// Уникальный идентификатор записи.
    public let id = UUID()

    /// Исходное математическое выражение.
    public let expression: String

    /// Результат вычисления.
    public let result: Decimal

    /// Отформатированная строка результата для отображения в UI.
    public let formattedResult: String

    /// Время добавления записи в историю.
    public let timestamp: Date

    /// Создаёт новую запись истории.
    ///
    /// - Parameters:
    ///   - expression: Исходное выражение.
    ///   - result: Результат вычисления.
    ///   - formattedResult: Отформатированная строка результата для отображения в UI.
    public init(expression: String, result: Decimal, formattedResult: String) {
        self.expression = expression
        self.result = result
        self.formattedResult = formattedResult
        self.timestamp = Date()
    }
}
