import Foundation
import CalculatorEngine

// MARK: - Инверсия знака выражений

/// Сервис инверсии знака текущего выражения.
/// Вынесен из CalculatorViewModel для разгрузки ViewModel (AGENTS.md §7).
@MainActor
struct SignToggler {

    private let engine: CalculatorEngine

    init(engine: CalculatorEngine) {
        self.engine = engine
    }

    /// Инвертирует знак непустого выражения.
    /// - Parameter expression: Текущее выражение (гарантированно не пустое).
    /// - Returns: Выражение с инвертированным знаком.
    func toggledExpressionSign(_ expression: String) -> String {
        do {
            if try CalculatorEngine.isSimpleTerm(expression) {
                return toggledSimpleTermSign(expression)
            }
        } catch {
            // Ошибка токенизации: выражение невалидно как простой термин —
            // обрабатываем его как сложное (сохраняет прежнюю семантику try? в ViewModel).
        }
        return toggledComplexExpressionSign(expression)
    }

    /// Инвертирует знак простого термина (число, унарный минус+число, процент).
    private func toggledSimpleTermSign(_ expression: String) -> String {
        if expression.hasPrefix("-") {
            return String(expression.dropFirst())
        } else {
            return "-" + expression
        }
    }

    /// Инвертирует знак сложного выражения.
    private func toggledComplexExpressionSign(_ expression: String) -> String {
        if let inner = CalculatorEngine.isWrappedNegativeExpression(expression) {
            return inner
        }

        if expression.hasPrefix("-") {
            return negatedExpressionWithLeadingMinus(expression)
        } else {
            return "-(\(expression))"
        }
    }

    /// Обрабатывает выражения с ведущим минусом:
    /// вычислимое выражение → вычислить и инвертировать результат,
    /// невычислимое → обернуть в -(выражение). "+" и "-" дают пустую строку.
    private func negatedExpressionWithLeadingMinus(_ expression: String) -> String {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)

        let isReadyForEvaluation = !trimmed.isEmpty
            && !CalculatorEngine.isTrailingOperator(expression)
            && !CalculatorEngine.hasUnclosedParentheses(trimmed)

        guard isReadyForEvaluation else {
            if trimmed == "-" || trimmed == "+" { return "" }
            return "-(\(expression))"
        }

        return evaluateAndNegate(expression)
    }

    /// Вычисляет выражение и возвращает строку инвертированного результата.
    /// При ошибке вычисления — оборачивает выражение в -(выражение).
    private func evaluateAndNegate(_ expression: String) -> String {
        do {
            let value = try engine.evaluate(expression)
            return (-value).description
        } catch {
            return "-(\(expression))"
        }
    }
}
