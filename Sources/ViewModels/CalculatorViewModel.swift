import Foundation
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
    var historyEntries: [HistoryEntry] = []

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
        do {
            return try engine.evaluate(trimmed)
        } catch {
            return nil
        }
    }

    /// Есть ли непустое значение в памяти (используется UI для визуальной индикации)
    var hasMemory: Bool { memoryValue != 0 }

    /// Отформатированное значение памяти для отображения в UI (tooltip, индикация)
    var memoryDisplayValue: String? {
        guard memoryValue != 0 else { return nil }
        return formatter.format(memoryValue)
    }

    /// Инициализация ViewModel. Заполняет историю из сервиса.
    init() {
        historyEntries = historyService.getEntries()
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
            toggleSignOfResult()
        } else if let isSimple = try? engine.isSimpleTerm(expression), isSimple {
            expression = toggleSimpleTermSign(expression)
        } else {
            expression = toggleComplexExpressionSign(expression)
        }
        errorMessage = nil
    }

    /// Инвертирует знак результата вычисления.
    /// Вызывается, когда expression пуст, но есть resultDecimal.
    /// После инверсии записывает новое значение в expression,
    /// сбрасывает result/resultDecimal/hasPreviousResult.
    private func toggleSignOfResult() {
        guard let val = resultDecimal else { return }
        let negated = -val
        expression = negated.description
        self.resultDecimal = nil
        self.result = nil
        hasPreviousResult = false
    }

    /// Инвертирует знак простого термина (число, унарный минус+число, процент).
    /// - Parameter expression: Текущее выражение (не пустое, является простым термином).
    /// - Returns: Выражение с инвертированным знаком.
    private func toggleSimpleTermSign(_ expression: String) -> String {
        if expression.hasPrefix("-") {
            return String(expression.dropFirst())
        } else {
            return "-" + expression
        }
    }

    /// Инвертирует знак сложного выражения.
    ///
    /// Логика:
    /// 1. Если выражение обёрнуто в -(выражение) — снимает обёртку.
    /// 2. Если выражение начинается с "-" и является вычислимым
    ///    (не заканчивается оператором, нет незакрытых скобок) —
    ///    вычисляет результат и инвертирует его.
    /// 3. Если выражение начинается с "-" но не вычислимое —
    ///    оборачивает в -(выражение).
    /// 4. Если выражение не начинается с "-" — оборачивает в -(выражение).
    ///
    /// - Parameter expression: Текущее выражение (не пустое, не простой термин).
    /// - Returns: Выражение с инвертированным знаком.
    private func toggleComplexExpressionSign(_ expression: String) -> String {
        // Обёрнутое отрицание: -(выражение) → выражение
        if let inner = CalculatorEngine.isWrappedNegativeExpression(expression) {
            return inner
        }

        if expression.hasPrefix("-") {
            let trimmed = expression.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  !CalculatorEngine.isTrailingOperator(expression),
                  !CalculatorEngine.hasUnclosedParentheses(trimmed) else {
                // Краевой случай: выражение состоит только из "-" или "+"
                if trimmed == "-" || trimmed == "+" {
                    return ""
                }
                return "-(\(expression))"
            }

            do {
                let value = try engine.evaluate(expression)
                let negated = -value
                return negated.description
            } catch {
                return "-(\(expression))"
            }
        } else {
            // Не начинается с -, оборачиваем в -(выражение)
            return "-(\(expression))"
        }
    }

    // MARK: - Функциональные вычисления (√, x²)

    /// Вычисляет квадратный корень из текущего значения на дисплее.
    /// Использует метод Ньютона (Герона) для итеративного вычисления
    /// квадратного корня напрямую через тип Decimal.
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

        let sqrtDecimal = CalculatorEngine.newtonSquareRoot(value)

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

        if !expression.isEmpty && CalculatorEngine.isTrailingOperator(expression) {
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

        do {
            let value = try engine.evaluate(trimmed)
            expression = trimmed      // Показать выражение пользователю
            result = formatter.format(value)  // Показать результат
            resultDecimal = value
            hasPreviousResult = true
            saveToHistory(expression: trimmed, result: value)
        } catch {
            if let calcError = error as? CalculatorError {
                errorMessage = calcError.localizedMessage
            } else {
                errorMessage = error.localizedDescription
            }
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

    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !CalculatorEngine.isTrailingOperator(expression), !CalculatorEngine.hasUnclosedParentheses(trimmed) else { return }

        do {
            let value = try engine.evaluate(expression)
            result = formatter.format(value)
            resultDecimal = value
            hasPreviousResult = true
        } catch {
            // ОСОЗНАННЫЙ ПРОПУСК ОШИБОК:
            // Автовычисление вызывается при вводе каждого оператора (метод appendCharacter)
            // и при восстановлении записи истории (метод useHistoryEntry).
            // В процессе набора выражение часто бывает неполным (например, "5+"),
            // и вызов evaluate() на таком выражении выбросит CalculatorError.
            //
            // Эти ошибки НЕ должны показываться пользователю, потому что:
            // 1. Пользователь ещё не завершил ввод выражения.
            // 2. Отображение ошибок при наборе создаёт UX-шум и сбивает.
            // 3. Истинная ошибка будет показана при явном нажатии "=" (метод evaluate()).
            //
            // Альтернативы рассмотрены и отклонены:
            // - Показывать ошибки → создаёт UX-шум при наборе.
            // - Пробрасывать ошибки → нарушает UX (автовычисление прозрачно для пользователя).
            // - Использовать флаг → избыточная сложность без benefit.
        }
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
}
