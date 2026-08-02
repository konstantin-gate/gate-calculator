import Foundation
import Observation
import CalculatorEngine

@MainActor
@Observable
final class CalculatorViewModel {

    var expression: String = ""
    var result: String? = nil
    internal var resultDecimal: Decimal? = nil
    var errorMessage: String? = nil

    private let engine: CalculatorEngine
    private let historyService: HistoryService
    private let formatter: NumberFormatterService
    private let clipboardManager: ClipboardManager
    private let signToggler: SignToggler

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

    private var memoryState = MemoryState()

    private var displayCache = DisplayCache()

    /// Текущее значение на дисплее для операций памяти.
    /// Если есть resultDecimal — возвращает его.
    /// Если есть выражение — пытается вычислить, используя кэш.
    private var currentDisplayValue: Decimal? {
        if let result = resultDecimal {
            return result
        }
        let trimmed = trimmedExpression
        guard !trimmed.isEmpty else { return nil }
        if trimmed == displayCache.cachedExpression {
            return displayCache.cachedDisplayValue
        }
        do {
            let val = try engine.evaluate(trimmed)
            displayCache.update(expression: trimmed, value: val)
            return val
        } catch {
            displayCache.update(expression: trimmed, value: nil)
            return nil
        }
    }

    /// Есть ли непустое значение в памяти (используется UI для визуальной индикации)
    var hasMemory: Bool { memoryState.hasMemory }

    // MARK: - Кэш значения дисплея

    /// Сбрасывает кэш вычисленного значения дисплея.
    /// Вызывается при любом изменении `expression`,
    /// чтобы не возвращать устаревшее кэшированное значение.
    private func invalidateDisplayCache() {
        displayCache.invalidate()
    }

    /// Отформатированное значение памяти для отображения в UI (tooltip, индикация)
    var memoryDisplayValue: String? {
        memoryState.displayValue(formatter: formatter)
    }

    /// Инициализация ViewModel с инъекцией зависимостей.
    init(
        engine: CalculatorEngine = CalculatorEngine(),
        historyService: HistoryService = HistoryService.shared,
        formatter: NumberFormatterService = NumberFormatterService.shared,
        clipboardManager: ClipboardManager = ClipboardManager.shared
    ) {
        self.engine = engine
        self.historyService = historyService
        self.formatter = formatter
        self.clipboardManager = clipboardManager
        self.signToggler = SignToggler(engine: engine)
    }

    /// Загружает записи истории из HistoryService.
    /// Вызывается из CalculatorView через модификатор .task — SwiftUI отменяет
    /// задачу автоматически при исчезновении View.
    func loadInitialHistory() async {
        historyEntries = await historyService.getEntries()
    }

    func appendCharacter(_ char: String) {
        clearError()

        // Сохраняем предыдущий результат ПЕРЕД сбросом состояния,
        // чтобы он мог быть использован при обработке оператора.
        let savedResultDecimal = resultDecimal

        if hasResult && !isOperator(char) {
            expression = ""
            clearResultState()
        } else if hasResult && isOperator(char) {
            if let dec = savedResultDecimal {
                expression = formatter.format(dec)
            }
            clearResultState()
        }

        expression += char
        invalidateDisplayCache()
        if !isDigitOrDecimal(char) && char != ")" {
            tryAutoEvaluate()
        }
    }

    func evaluate() {
        clearError()

        let trimmed = trimmedExpression
        guard !trimmed.isEmpty else { return }

        do {
            let value = try engine.evaluate(expression)
            setResultState(value: value, historyExpression: expression)
            expression = ""
        } catch {
            handleError(error)
        }
    }

    func clear() {
        expression = ""
        invalidateDisplayCache()
        clearResultState()
        errorMessage = nil
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
        invalidateDisplayCache()

        // Сбросить result/resultDecimal,
        // чтобы DisplayView показал урезанное expression
        clearResultState()
    }

    /// Удаляет последний операнд (последовательность [0-9.]) или один последний символ-оператор/скобку.
    private func removeLastOperandOrOperator() {
        let trimmed = trimmedExpression
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
            clear()
            return
        }

        if !expression.isEmpty {
            // Сбросить result/resultDecimal, чтобы DisplayView показал expression
            clearResultState()
            expression.removeLast()
            invalidateDisplayCache()
            // tryAutoEvaluate() НЕ вызывается — автовычисление при backspace не нужно
        } else if hasResult {
            clear()
        }
    }

    /// Инвертирует знак текущего числа/выражения
    func toggleSign() {
        if expression.isEmpty {
            toggleSignOfResult()
        } else {
            expression = signToggler.toggledExpressionSign(expression)
        }
        invalidateDisplayCache()
        errorMessage = nil
    }

    /// Инвертирует знак результата вычисления.
    /// Вызывается, когда expression пуст, но есть resultDecimal.
    /// После инверсии записывает новое значение в expression,
    /// сбрасывает result/resultDecimal.
    private func toggleSignOfResult() {
        guard let val = resultDecimal else { return }
        let negated = -val
        expression = negated.description
        self.resultDecimal = nil
        self.result = nil
    }

    // MARK: - Функциональные вычисления (√, x²)

    /// Обобщённая унарная функция над значением дисплея (√, x²).
    /// Берёт currentDisplayValue, применяет compute, пишет результат в историю
    /// и состояние, очищает expression. Если compute возвращает nil — состояние
    /// не меняется (compute сам устанавливает errorMessage).
    private func applyUnaryFunction(
        historyExpression: (String) -> String,
        compute: (Decimal) -> Decimal?
    ) {
        clearError()

        guard let value = currentDisplayValue else {
            errorMessage = localizedString("errors.emptyExpression", comment: "")
            return
        }

        guard let newValue = compute(value) else { return }

        let baseExpression = expression.isEmpty ? formatter.format(value) : expression
        setResultState(value: newValue, historyExpression: historyExpression(baseExpression))
        expression = ""
    }

    /// Вычисляет квадратный корень из текущего значения на дисплее.
    /// Использует метод Ньютона (Герона) для итеративного вычисления
    /// квадратного корня напрямую через тип Decimal.
    func calculateSquareRoot() {
        applyUnaryFunction(
            historyExpression: { "√(" + $0 + ")" },
            compute: { value in
                guard value >= 0 else {
                    self.errorMessage = localizedString("errors.negativeSquareRoot", comment: "")
                    return nil
                }
                return CalculatorEngine.newtonSquareRoot(value)
            }
        )
    }

    /// Возводит текущее значение на дисплее в квадрат.
    /// Использует простую операцию Decimal * Decimal — точная арифметика без преобразования в Double.
    func calculateSquare() {
        applyUnaryFunction(
            historyExpression: { "(" + $0 + ")²" },
            compute: { $0 * $0 }
        )
    }

    // MARK: - Memory operations (SRS §39-43)

    func memoryClear() {
        memoryState.clear()
    }

    func memoryAdd() {
        guard let val = currentDisplayValue else { return }
        memoryState.add(val)
    }

    func memorySubtract() {
        guard let val = currentDisplayValue else { return }
        memoryState.subtract(val)
    }

    func memoryRecall() {
        clearError()
        let memStr = memoryState.valueDescription

        if !expression.isEmpty && CalculatorEngine.isTrailingOperator(expression) {
            expression += memStr
        } else {
            expression = memStr
        }
        invalidateDisplayCache()

        clearResultState()
    }

    // MARK: - Clipboard

    func insertFromClipboard(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        clearCurrentInput()

        do {
            let value = try engine.evaluate(trimmed)
            expression = trimmed
            setResultState(value: value, historyExpression: trimmed)
        } catch {
            handleError(error)
        }
    }

    func copyResult() {
        clipboardManager.setString(displayValue)
    }

    func handleClipboardAction() {
        if isClipboardPasteMode, let text = clipboardManager.getString() {
            insertFromClipboard(text)
        } else {
            copyResult()
        }
    }

    // MARK: - History

    func useHistoryEntry(_ entry: HistoryEntry) {
        expression = entry.expression
        invalidateDisplayCache()
        clearResultState()
        errorMessage = nil
        tryAutoEvaluate()
    }

    /// Очищает историю вычислений
    func clearHistory() {
        Task {
            await historyService.clear()
            self.historyEntries = []
        }
    }

    private func tryAutoEvaluate() {
        guard isReadyForEvaluation else { return }

        do {
            let value = try engine.evaluate(expression)
            result = formatter.format(value)
            resultDecimal = value
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

    // MARK: - Вспомогательные методы

    private func handleError(_ error: Error) {
        if let calcError = error as? CalculatorError {
            errorMessage = calcError.localizedMessage
        } else {
            errorMessage = error.localizedDescription
        }
    }

    private func clearResultState() {
        result = nil
        resultDecimal = nil
    }

    private var trimmedExpression: String {
        expression.trimmingCharacters(in: .whitespaces)
    }

    private var isReadyForEvaluation: Bool {
        let trimmed = trimmedExpression
        return !trimmed.isEmpty &&
               !CalculatorEngine.isTrailingOperator(expression) &&
               !CalculatorEngine.hasUnclosedParentheses(trimmed)
    }

    private func setResultState(value: Decimal, historyExpression: String) {
        let formatted = formatter.format(value)
        Task {
            await historyService.add(expression: historyExpression, result: value, formattedResult: formatted)
            self.historyEntries = await historyService.getEntries()
        }
        result = formatted
        resultDecimal = value
        invalidateDisplayCache()
    }
}
