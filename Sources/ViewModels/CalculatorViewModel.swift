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
    private var hasPreviousResult = false
    var errorMessage: String? = nil

    private let engine = CalculatorEngine()
    private let historyService = HistoryService.shared
    private let formatter = NumberFormatterService.shared

    var hasResult: Bool { resultDecimal != nil }

    /// Режим кнопки буфера обмена: true — показать «Вставить» (нет результата),
    /// false — показать «Копировать» (есть результат).
    var isClipboardPasteMode: Bool {
        !hasResult
    }

    /// Текущее значение, отображаемое в главном поле дисплея.
    /// Используется для копирования в буфер обмена (⌘C).
    var displayValue: String {
        if let error = errorMessage { return error }
        if let res = result { return res }
        guard !expression.isEmpty else { return "0" }
        return expression
    }

    /// Записи истории для HistoryPanelView
    var historyEntries: [HistoryEntry] = HistoryService.shared.getEntries()

    var historyCount: Int { historyEntries.count }

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

        // Сохраняем предыдущий результат ПЕРЕД сбросом состояния,
        // чтобы он мог быть использован при обработке оператора.
        let savedResultDecimal = resultDecimal

        if hasResult && !isOperator(char) {
            expression = ""
            result = nil
            resultDecimal = nil
            hasPreviousResult = false
        } else if hasResult && isOperator(char) {
            if let dec = savedResultDecimal {
                expression = dec.description
            }
            result = nil
            resultDecimal = nil
        }

        expression += char
        if !isDigitOrDecimal(char) && char != ")" {
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
            saveToHistory(expression: expression, result: value)

            result = formatted
            resultDecimal = value
            expression = ""
            hasPreviousResult = true
        } catch {
            if let calcError = error as? CalculatorError {
                errorMessage = calcError.localizedMessage
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clear() {
        expression = ""
        result = nil
        resultDecimal = nil
        errorMessage = nil
        hasPreviousResult = false
    }

    // MARK: - Очистка текущего ввода

    /// Определяет поведение кнопки «C» в двух режимах калькулятора.
    ///
    /// Режим «Просмотр результата» (hasResult == true):
    ///   полная очистка через clear() — как AC. Экран «0», кнопка AC.
    ///   Срабатывает при: результате после «=», вставке из буфера,
    ///   useHistoryEntry с вычислимым выражением, после √/x².
    ///
    /// Режим «Активный набор» (hasResult == false и expression не пустая):
    ///   удаляет последний операнд (если в конце есть последовательность [0-9.]),
    ///   либо один последний символ-оператор/скобку (если операнд не найден).
    ///   Кнопка остаётся C, пока expression не станет пустой — тогда AC.
    ///
    /// Если expression пустая и hasResult == false — нет операции (кнопка AC).
    func clearCurrentInput() {
        clearError()

        if hasResult {
            // Режим «Просмотр результата» — полная очистка как AC
            clear()
            return
        }

        if expression.isEmpty {
            // Калькулятор уже в начальном состоянии — нет операции
            return
        }

        // Режим «Активный набор» — удаляем последний операнд или оператор
        removeLastOperandOrOperator()

        // Сбросить result/resultDecimal/hasPreviousResult,
        // чтобы DisplayView показал урезанное expression
        result = nil
        resultDecimal = nil
        hasPreviousResult = false
    }

    /// Удаляет последний операнд (последовательность [0-9.]) или один последний символ-оператор/скобку.
    private func removeLastOperandOrOperator() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let chars = Array(trimmed)
        let operandEndIndex = chars.count
        var operandStartIndex = chars.count

        // Сканируем с конца, пока символ — цифра или десятичная точка
        for i in (0..<chars.count).reversed() {
            let char = chars[i]
            if char.isNumber || char == "." {
                operandStartIndex = i
            } else {
                break
            }
        }

        // Если диапазон не пустой (в конце expression есть последовательность цифр/точек)
        if operandStartIndex < operandEndIndex {
            // Удаляем операнд: оставляем всё до operandStartIndex
            let prefixLength = operandStartIndex
            if prefixLength > 0 {
                expression = String(trimmed.prefix(prefixLength))
            } else {
                expression = ""
            }
        } else {
            // Диапазон пустой (последний символ — не цифра и не точка, т.е. оператор или скобка)
            // Удаляем один последний символ
            expression.removeLast()
        }
    }

    func backspace() {
        clearError()

        if expression.isEmpty, resultDecimal != nil {
            hasPreviousResult = false
            clear()
            return
        }

        if !expression.isEmpty {
            // Сбросить result/resultDecimal, чтобы DisplayView показал expression
            result = nil
            resultDecimal = nil
            hasPreviousResult = false
            expression.removeLast()
            // tryAutoEvaluate() НЕ вызывается — автовычисление при backspace не нужно
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
                hasPreviousResult = false
            }
        } else {
            // 1. Проверка на обёрнутое отрицательное выражение: -(выражение)
            if let inner = isWrappedNegativeExpression(expression) {
                expression = inner
            } else if isSimpleTerm(expression) {
                // 2. Простой термин (число, константа, процент, унарный минус + число)
                if expression.hasPrefix("-") {
                    expression = String(expression.dropFirst())
                } else {
                    expression = "-" + expression
                }
            } else {
                // 3. Сложное выражение
                if expression.hasPrefix("-") {
                    // Выражение начинается с -, но не является простым термином и не обёрнуто в -(...)
                    let trimmed = expression.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(trimmed) else {
                        // Краевой случай: выражение состоит только из "-" или "+"
                        if trimmed == "-" || trimmed == "+" {
                            expression = ""
                            errorMessage = nil
                            return
                        }
                        expression = "-(\(expression))"
                        errorMessage = nil
                        return
                    }
                    
                    do {
                        let value = try engine.evaluate(expression)
                        let negated = -value
                        expression = negated.description
                        self.resultDecimal = nil
                        self.result = nil
                        hasPreviousResult = false
                    } catch {
                        expression = "-(\(expression))"
                    }
                } else {
                    // Не начинается с -, оборачиваем в -(выражение)
                    expression = "-(\(expression))"
                }
            }
        }
        errorMessage = nil
    }

    // MARK: - Функциональные вычисления (√, x²)

    /// Вычисляет квадратный корень из текущего значения на дисплее.
    /// Использует цепочку: Decimal → Double → Foundation.sqrt() → Decimal(floatLiteral:).
    /// Это единственный корректный способ вычислить √ для Decimal в Swift Foundation,
    /// т.к. ни Decimal, ни NSDecimalNumber не имеют встроенного метода squareRoot().
    func calculateSquareRoot() {
        clearError()

        guard let value = currentDisplayValue else {
            errorMessage = localizedString("errors.emptyExpression", comment: "")
            return
        }

        guard value >= 0 else {
            errorMessage = localizedString("errors.negativeSquareRoot", comment: "")
            return
        }

        // Цепочка преобразования: Decimal → Double → sqrt → Decimal
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        let sqrtDouble = Foundation.sqrt(doubleValue)
        let sqrtDecimal = Decimal(floatLiteral: sqrtDouble)

        saveToHistory(expression: "√(\(expression.isEmpty ? formatter.format(value) : expression))", result: sqrtDecimal)

        result = formatter.format(sqrtDecimal)
        resultDecimal = sqrtDecimal
        expression = ""
        hasPreviousResult = true
    }

    /// Возводит текущее значение на дисплее в квадрат.
    /// Использует простую операцию Decimal * Decimal — точная арифметика без преобразования в Double.
    func calculateSquare() {
        clearError()

        guard let value = currentDisplayValue else {
            errorMessage = localizedString("errors.emptyExpression", comment: "")
            return
        }

        let squared = value * value

        saveToHistory(expression: "(\(expression.isEmpty ? formatter.format(value) : expression))²", result: squared)

        result = formatter.format(squared)
        resultDecimal = squared
        expression = ""
        hasPreviousResult = true
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
        hasPreviousResult = false
    }

    // MARK: - Clipboard

    func insertFromClipboard(_ text: String) {
        // ИСПРАВЛЕНИЕ C-06: показать выражение пользователю вместо expression = ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        clearCurrentInput()

        if let value = try? engine.evaluate(trimmed) {
            expression = trimmed      // Показать выражение пользователю
            result = formatter.format(value)  // Показать результат
            resultDecimal = value
            hasPreviousResult = true
            saveToHistory(expression: trimmed, result: value)
        } else {
            errorMessage = localizedString("clipboard.cannotEvaluate", comment: "")
        }
    }

    func copyResult() {
        ClipboardManager.shared.setString(displayValue)
    }

    // MARK: - History

    func useHistoryEntry(_ entry: HistoryEntry) {
        hasPreviousResult = false
        expression = entry.expression
        result = nil
        errorMessage = nil
        tryAutoEvaluate()
    }

    private func saveToHistory(expression: String, result: Decimal) {
        historyService.add(expression: expression, result: result)
        historyEntries = historyService.getEntries()
    }

    /// Очищает историю вычислений
    func clearHistory() {
        historyService.clear()
        historyEntries = []
    }

    // MARK: - Private helpers

    private func isSimpleTerm(_ expression: String) -> Bool {
        let tokenizer = Tokenizer()
        do {
            let tokens = try tokenizer.tokenize(expression)
            
            // Проверка на наличие недопустимых токенов (бинарные операторы, скобки)
            for token in tokens {
                switch token {
                case .number, .unaryMinus, .percent:
                    break
                default:
                    return false // binaryOperator, leftParenthesis, rightParenthesis не допускаются в простом термине
                }
            }
            
            if tokens.isEmpty { return false }
            
            // Допустимые паттерны простого термина:
            // 1. [.number]
            // 2. [.unaryMinus, .number]
            // 3. [.number, .percent]
            // 4. [.unaryMinus, .number, .percent]
            
            switch tokens.count {
            case 1:
                guard case .number = tokens[0] else { return false }
                return true
            case 2:
                switch (tokens[0], tokens[1]) {
                case (.unaryMinus, .number): return true
                case (.number, .percent): return true
                default: return false
                }
            case 3:
                switch (tokens[0], tokens[1], tokens[2]) {
                case (.unaryMinus, .number, .percent): return true
                default: return false
                }
            default:
                return false
            }
        } catch {
            return false
        }
    }

    private func isWrappedNegativeExpression(_ expression: String) -> String? {
        guard expression.hasPrefix("-(") else { return nil }
        
        // Открывающая скобка '(' находится на индексе 1 (после '-')
        let openParenIndex = expression.index(expression.startIndex, offsetBy: 1)
        var balance = 1
        var currentIndex = expression.index(after: openParenIndex)
        
        while currentIndex < expression.endIndex {
            let char = expression[currentIndex]
            if char == "(" {
                balance += 1
            } else if char == ")" {
                balance -= 1
                if balance == 0 {
                    // Найдена закрывающая скобка, соответствующая открывающей после "-("
                    let endIndex = expression.index(after: currentIndex)
                    guard endIndex == expression.endIndex else { return nil } // Выражение должно заканчиваться здесь
                    let innerStart = expression.index(expression.startIndex, offsetBy: 2) // после "-("
                    let innerEnd = currentIndex
                    return String(expression[innerStart..<innerEnd])
                }
            }
            currentIndex = expression.index(after: currentIndex)
        }
        
        return nil // Не найдена закрывающая скобка с балансом 0
    }

    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(trimmed) else { return }

        do {
            let value = try engine.evaluate(expression)
            result = formatter.format(value)
            resultDecimal = value
            hasPreviousResult = true
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
