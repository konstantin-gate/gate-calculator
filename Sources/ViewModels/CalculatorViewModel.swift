import Foundation
import SwiftUI
import Observation
import CalculatorEngine

@MainActor
@Observable
final class CalculatorViewModel {

    var expression: String = ""
    var result: String? = nil
    internal var resultDecimal: Decimal? = nil
    var errorMessage: String? = nil

    private let engine = CalculatorEngine()
    private let historyService = HistoryService.shared
    private let formatter = NumberFormatterService.shared

    var hasResult: Bool { resultDecimal != nil }

    /// Текущее значение, отображаемое в главном поле дисплея.
    /// Используется для копирования в буфер обмена (⌘C).
    var displayValue: String {
        if let error = errorMessage { return error }
        if let res = result { return res }
        guard !expression.isEmpty else { return "0" }
        return expression
    }

    var historyCount: Int { historyService.count() }

    /// Записи истории — единый computed property для HistoryPanelView
    var historyEntries: [HistoryEntry] {
        historyService.getEntries()
    }

    private var memoryValue: Decimal = 0

    /// Текущее значение на дисплее для операций памяти.
    /// Если есть resultDecimal — возвращает его.
    /// Если есть выражение — пытается вычислить.
    private var currentDisplayValue: Decimal? {
        if let result = resultDecimal {
            return result
        }
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return try? engine.evaluate(trimmed)
    }

    /// Есть ли непустое значение в памяти (используется UI для визуальной индикации)
    var hasMemory: Bool { memoryValue != 0 }

    /// Отформатированное значение памяти для отображения в UI (tooltip, индикация)
    var memoryDisplayValue: String? {
        guard memoryValue != 0 else { return nil }
        return formatter.format(memoryValue)
    }

    func appendCharacter(_ char: String) {
        clearError()

        if hasResult && !isOperator(char) {
            expression = ""
            result = nil
            resultDecimal = nil
        } else if hasResult && isOperator(char) {
            if let dec = resultDecimal {
                expression = dec.description
            }
            result = nil
            resultDecimal = nil
        }

        expression += char
        if !isDigitOrDecimal(char) {
            tryAutoEvaluate()
        }
    }

    /// Этот метод больше не вызывается из UI, оставлен для совместимости
    func appendOperator(_ op: String) {
        clearError()

        if hasResult {
            if let dec = resultDecimal {
                expression = dec.description + op
            }
            result = nil
            resultDecimal = nil
        } else {
            expression += op
        }
        result = nil
    }

    func evaluate() {
        clearError()

        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        do {
            let value = try engine.evaluate(expression)
            let formatted = formatter.format(value)

            // Всегда добавляем в историю успешные вычисления
            historyService.add(expression: expression, result: value)

            result = formatted
            resultDecimal = value
            expression = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        expression = ""
        result = nil
        resultDecimal = nil
        errorMessage = nil
    }

    func backspace() {
        clearError()

        if expression.isEmpty, resultDecimal != nil {
            clear()
            return
        }

        if !expression.isEmpty {
            expression.removeLast()
            tryAutoEvaluate()
        } else if hasResult {
            clear()
        }
    }

    /// Инвертирует знак текущего числа/выражения
    func toggleSign() {
        if expression.isEmpty {
            if let val = resultDecimal {
                let negated = -val
                expression = negated.description
                self.resultDecimal = nil
                self.result = nil
            }
        } else {
            if expression.hasPrefix("-") {
                expression = String(expression.dropFirst())
            } else {
                expression = "-(\(expression))"
            }
        }
        errorMessage = nil
    }

    // MARK: - Memory operations (SRS §39-43)

    func memoryClear() {
        memoryValue = 0
    }

    func memoryAdd() {
        guard let val = currentDisplayValue else { return }
        memoryValue += val
    }

    func memorySubtract() {
        guard let val = currentDisplayValue else { return }
        memoryValue -= val
    }

    func memoryRecall() {
        clearError()
        let memStr = memoryValue.description

        if !expression.isEmpty && isTrailingOperator(expression) {
            expression += memStr
        } else {
            expression = memStr
        }

        result = nil
        resultDecimal = nil
    }

    func handleKeyCommand(_ key: String) {
        switch key {
        case "C", "\u{1B}":
            clear()
        case "\u{7F}", "\u{8}":
            backspace()
        case "\r", "\n", "=":
            evaluate()
        default:
            if key.count == 1, let firstChar = key.first, firstChar.isNumber || "+-*/().%".contains(firstChar) {
                appendCharacter(key)
            }
        }
    }

    // MARK: - Clipboard

    func insertFromClipboard(_ text: String) {
        // ИСПРАВЛЕНИЕ C-06: показать выражение пользователю вместо expression = ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        clear()

        if let value = try? engine.evaluate(trimmed) {
            expression = trimmed      // Показать выражение пользователю
            result = formatter.format(value)  // Показать результат
            resultDecimal = value
            historyService.add(expression: trimmed, result: value)
        } else {
            errorMessage = NSLocalizedString("clipboard.cannotEvaluate", comment: "")
        }
    }

    func copyResult() {
        ClipboardManager.shared.setString(displayValue)
    }

    // MARK: - History

    func useHistoryEntry(_ entry: HistoryEntry) {
        expression = entry.expression
        result = nil
        errorMessage = nil
        tryAutoEvaluate()
    }

    /// Очищает историю вычислений
    func clearHistory() {
        historyService.clear()
    }

    // MARK: - Private helpers

    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(trimmed) else { return }

        do {
            let value = try engine.evaluate(expression)
            result = formatter.format(value)
            resultDecimal = value
        } catch {
            // Ошибки автовычисления не показываются пользователю —
            // выражение в процессе набора может быть неполным.
            // Ошибки отображаются только при явном нажатии "=" (метод evaluate()).
        }
    }

    private func isTrailingOperator(_ expr: String) -> Bool {
        guard let last = expr.last else { return false }
        return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
    }

    private func isOperator(_ char: String) -> Bool {
        char == "+" || char == "-" || char == "*" || char == "/" || char == "%"
    }

    private func clearError() {
        errorMessage = nil
    }

    private func isDigitOrDecimal(_ char: String) -> Bool {
        return char == "." || (char.count == 1 && char.first?.isNumber == true)
    }

    /// Проверяет, есть ли в выражении незакрытые открывающие скобки.
    /// Возвращает true, если количество '(' превышает количество ')'.
    private func hasUnclosedParentheses(_ expr: String) -> Bool {
        var count = 0
        for char in expr where char == "(" || char == ")" {
            if char == "(" {
                count += 1
            } else {
                count -= 1
            }
        }
        return count > 0
    }
}
