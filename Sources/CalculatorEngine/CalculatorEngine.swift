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
        guard value >= 0 else { return .nan }
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

    // MARK: - Анализ выражений

    /// Проверяет, является ли выражение простым термином.
    ///
    /// Простой термин — это выражение, содержащее только числа, унарный минус
    /// и оператор процента без бинарных операторов и скобок.
    ///
    /// Допустимые паттерны:
    /// - `[.number]` — например, `5`, `3.14`
    /// - `[.unaryMinus, .number]` — например, `-5`
    /// - `[.number, .percent]` — например, `5%`
    /// - `[.unaryMinus, .number, .percent]` — например, `-5%`
    ///
    /// - Parameter expression: Строка с математическим выражением.
    /// - Returns: `true` если выражение является простым термином.
    /// - Throws: `CalculatorError` если токенизация не удалась.
    public static func isSimpleTerm(_ expression: String) throws -> Bool {
        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize(expression)

        // Проверка на наличие недопустимых токенов (бинарные операторы, скобки)
        for token in tokens {
            switch token {
            case .number, .unaryMinus, .percent:
                break
            default:
                return false
            }
        }

        if tokens.isEmpty { return false }

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
    }

    /// Проверяет, обёрнуто ли выражение в `-(выражение)`.
    ///
    /// Возвращает внутреннее выражение, если обёртка найдена и корректна.
    /// Корректная обёртка: начинается с `-(`, содержит сбалансированные скобки,
    /// закрывается ровно на последнем символе.
    ///
    /// - Parameter expression: Строка для проверки.
    /// - Returns: Внутреннее выражение без обёртки, или `nil` если обёртки нет.
    public static func isWrappedNegativeExpression(_ expression: String) -> String? {
        guard expression.hasPrefix("-(") else { return nil }

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
                    let endIndex = expression.index(after: currentIndex)
                    guard endIndex == expression.endIndex else { return nil }
                    let innerStart = expression.index(expression.startIndex, offsetBy: 2)
                    let innerEnd = currentIndex
                    return String(expression[innerStart..<innerEnd])
                }
            }
            currentIndex = expression.index(after: currentIndex)
        }

        return nil
    }

    /// Проверяет, заканчивается ли выражение оператором.
    ///
    /// - Parameter expression: Строка для проверки.
    /// - Returns: `true` если последний символ — `+`, `-`, `*`, `/` или `%`.
    public static func isTrailingOperator(_ expression: String) -> Bool {
        guard let last = expression.last else { return false }
        return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
    }

    /// Проверяет, есть ли в выражении незакрытые открывающие скобки.
    ///
    /// - Parameter expression: Строка для проверки.
    /// - Returns: `true` если количество `(` превышает количество `)`.
    public static func hasUnclosedParentheses(_ expression: String) -> Bool {
        var count = 0
        for char in expression where char == "(" || char == ")" {
            if char == "(" {
                count += 1
            } else {
                count -= 1
            }
        }
        return count > 0
    }
}
