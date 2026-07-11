import Foundation

/// Токенизатор математических выражений.
///
/// Преобразует строку выражения в последовательность токенов (`[Token]`).
/// Выполняет предварительную обработку: удаление "=", обработка переносов строк,
/// нормализация разделителей тысяч/десятичных запятых, проверка на NaN/Infinity.
public struct Tokenizer: Sendable {

    /// Создаёт новый экземпляр токенизатора.
    public init() {}

    /// Токенизирует математическое выражение.
    public func tokenize(_ input: String) throws -> [Token] {
        let cleaned = try preprocess(input)
        guard !cleaned.isEmpty else { return [] }

        var tokens: [Token] = []
        var i = cleaned.startIndex

        while i < cleaned.endIndex {
            let char = cleaned[i]

            if char.isWhitespace {
                advance(&i, in: cleaned)
                continue
            }

            if char == "(" {
                tokens.append(.leftParenthesis)
                advance(&i, in: cleaned)
                continue
            }

            if char == ")" {
                tokens.append(.rightParenthesis)
                advance(&i, in: cleaned)
                continue
            }

            if char == "+" {
                tokens.append(.binaryOperator(.add))
                advance(&i, in: cleaned)
                continue
            }

            if char == "%" {
                tokens.append(.percent)
                advance(&i, in: cleaned)
                continue
            }

            if char == "*" {
                tokens.append(.binaryOperator(.multiply))
                advance(&i, in: cleaned)
                continue
            }

            if char == "/" {
                tokens.append(.binaryOperator(.divide))
                advance(&i, in: cleaned)
                continue
            }

            if char == "-" {
                let isUnary = tokens.isEmpty ||
                    lastTokenIsOperatorOrLeftParen(tokens)

                if isUnary {
                    tokens.append(.unaryMinus)
                } else {
                    tokens.append(.binaryOperator(.subtract))
                }
                advance(&i, in: cleaned)
                continue
            }

            if char.isNumber || char == "." {
                guard let result = try? readNumber(cleaned, from: i), let number = result.number else {
                    throw CalculatorError.invalidCharacter(String(char))
                }
                tokens.append(.number(number))
                i = result.newIndex
                continue
            }

            // ИСПРАВЛЕНИЕ C-04: удалено char.lowercased() == "pi" (невозможное условие)
            if char == "\u{03C0}" || char == "π" {
                tokens.append(.number(Decimal.pi))
                advance(&i, in: cleaned)
                continue
            }

            if char == "e" {
                let nextIndex = cleaned.index(after: i)
                if nextIndex < cleaned.endIndex {
                    let nextChar = cleaned[nextIndex]
                    // ИСПРАВЛЕНИЕ C-12: "e3", "e2.5" — невалидный ввод
                    if nextChar.isNumber || nextChar == "." {
                        throw CalculatorError.invalidCharacter("e")
                    } else {
                        tokens.append(.number(Self.eulerNumber))
                        advance(&i, in: cleaned)
                    }
                } else {
                    tokens.append(.number(Self.eulerNumber))
                    advance(&i, in: cleaned)
                }
                continue
            }

            throw CalculatorError.invalidCharacter(String(char))
        }

        try validateTokenSequence(tokens)
        return tokens
    }

    private static let eulerNumber: Decimal = {
        var result = Decimal(1)
        var factorial = Decimal(1)
        for i in 1..<30 {
            factorial *= Decimal(i)
            result += Decimal(1) / factorial
        }
        return result
    }()

    private func preprocess(_ input: String) throws -> String {
        var result = input

        if let lastEquals = result.lastIndex(of: "=") {
            result.remove(at: lastEquals)
        }

        let newlineIndex = result.firstIndex(of: "\n") ?? result.endIndex
        result.removeSubrange(newlineIndex..<result.endIndex)

        let trimmed = result.trimmingCharacters(in: .whitespaces)

        if trimmed.lowercased() == "nan" || trimmed.lowercased() == "infinity" {
            throw CalculatorError.invalidExpression("Invalid expression")
        }

        let comma = Character(",")
        if trimmed.contains(comma) {
            if !trimmed.contains(".") && isThousandsSeparatorPattern(trimmed) {
                result.removeAll(where: { $0 == comma })
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    private func isThousandsSeparatorPattern(_ str: String) -> Bool {
        for c in str {
            if !c.isNumber && c != "," { return false }
        }
        return true
    }

    /// Результат чтения числа.
    private struct ReadNumberResult {
        let number: Decimal?
        let newIndex: String.Index
    }

    // ИСПРАВЛЕНИЕ C-07: добавлена проверка продвижения индекса, throws вместо возврата (0, start)
    private func readNumber(_ str: String, from start: String.Index) throws -> ReadNumberResult {
        var i = start

        if str[i] == "0" {
            let nextIndex = str.index(after: i)
            if nextIndex < str.endIndex {
                let nextChar = String(str[nextIndex]).lowercased()
                switch nextChar {
                case "x":
                    let result = try readHex(str, from: str.index(after: nextIndex))
                    return result
                case "b":
                    let result = try readBinary(str, from: str.index(after: nextIndex))
                    return result
                case "o":
                    let result = try readOctal(str, from: str.index(after: nextIndex))
                    return result
                default:
                    break
                }
            }
        }

        var numberStr = ""
        var hasDecimal = false
        var hasExponent = false

        while i < str.endIndex {
            let c = str[i]

            if c.isNumber {
                numberStr.append(c)
                advance(&i, in: str)
            } else if c == "." && !hasDecimal && !hasExponent {
                hasDecimal = true
                numberStr.append(c)
                advance(&i, in: str)
            } else if (c == "e" || c == "E") && !hasExponent {
                hasExponent = true
                numberStr.append(c)
                advance(&i, in: str)

                if i < str.endIndex, (str[i] == "+" || str[i] == "-") {
                    numberStr.append(str[i])
                    advance(&i, in: str)
                }
            } else {
                break
            }
        }

        // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ C-07: если индекс не продвинулся — бесконечный цикл
        if i == start {
            throw CalculatorError.invalidCharacter(str[start] == "." ? "." : String(str[start]))
        }

        if numberStr == "." || numberStr.isEmpty {
            throw CalculatorError.invalidCharacter(numberStr.isEmpty ? String(str[start]) : ".")
        }

        if let decimal = Decimal(string: numberStr) {
            return ReadNumberResult(number: decimal, newIndex: i)
        }

        throw CalculatorError.invalidCharacter(String(str[start]))
    }

    // ИСПРАВЛЕНИЕ C-07: добавлена проверка пустого hexStr, бросается ошибка
    private func readHex(_ str: String, from start: String.Index) throws -> ReadNumberResult {
        var i = start
        var hexStr = ""

        while i < str.endIndex {
            let c = str[i]
            if c.isHexDigit || c == "_" {
                if c != "_" { hexStr.append(c) }
                advance(&i, in: str)
            } else {
                break
            }
        }

        if hexStr.isEmpty {
            throw CalculatorError.invalidCharacter("0x")
        }

        if let value = UInt64(hexStr, radix: 16) {
            return ReadNumberResult(number: Decimal(value), newIndex: i)
        }

        throw CalculatorError.invalidNumber(hexStr)
    }

    // ИСПРАВЛЕНИЕ C-07: добавлена проверка пустого binStr, бросается ошибка
    private func readBinary(_ str: String, from start: String.Index) throws -> ReadNumberResult {
        var i = start
        var binStr = ""

        while i < str.endIndex {
            let c = str[i]
            if c == "0" || c == "1" || c == "_" {
                if c != "_" { binStr.append(c) }
                advance(&i, in: str)
            } else {
                break
            }
        }

        if binStr.isEmpty {
            throw CalculatorError.invalidCharacter("0b")
        }

        if let value = UInt64(binStr, radix: 2) {
            return ReadNumberResult(number: Decimal(value), newIndex: i)
        }

        throw CalculatorError.invalidNumber(binStr)
    }

    // ИСПРАВЛЕНИЕ C-07: добавлена проверка пустого octStr, бросается ошибка
    private func readOctal(_ str: String, from start: String.Index) throws -> ReadNumberResult {
        var i = start
        var octStr = ""

        while i < str.endIndex {
            let c = str[i]
            if (c >= "0" && c <= "7") || c == "_" {
                if c != "_" { octStr.append(c) }
                advance(&i, in: str)
            } else {
                break
            }
        }

        if octStr.isEmpty {
            throw CalculatorError.invalidCharacter("0o")
        }

        if let value = UInt64(octStr, radix: 8) {
            return ReadNumberResult(number: Decimal(value), newIndex: i)
        }

        throw CalculatorError.invalidNumber(octStr)
    }

    private func lastTokenIsOperatorOrLeftParen(_ tokens: [Token]) -> Bool {
        guard let last = tokens.last else { return true }
        switch last {
        case .binaryOperator, .unaryMinus, .leftParenthesis:
            return true
        default:
            return false
        }
    }

    private func validateTokenSequence(_ tokens: [Token]) throws {
        for i in tokens.indices {
            let token = tokens[i]

            switch token {
            case .binaryOperator:
                let prevIsOp = i > tokens.startIndex && isOperatorOrLeftParen(tokens[i - 1])
                let nextIsOp = i + 1 < tokens.endIndex && isOperatorOnly(tokens[i + 1])
                let nextIsUnaryMinus = i + 1 < tokens.endIndex && tokens[i + 1] == .unaryMinus
                if prevIsOp || (nextIsOp && !nextIsUnaryMinus) {
                    throw CalculatorError.doubleOperator
                }

            case .percent:
                // % после левой скобки — невалидно (нельзя начать выражение с %)
                if i > tokens.startIndex && tokens[i - 1] == .leftParenthesis {
                    throw CalculatorError.doubleOperator
                }
                // % после % — невалидно (двойной процент)
                if i > tokens.startIndex && tokens[i - 1] == .percent {
                    throw CalculatorError.doubleOperator
                }
                // Двойной % подряд (проверка следующего токена)
                if i + 1 < tokens.endIndex && tokens[i + 1] == .percent {
                    throw CalculatorError.doubleOperator
                }

            case .unaryMinus:
                // Унарный минус после бинарного оператора допустим (5*-3).
                // После числа или правой скобки — тоже допустимо (5--3, (-3)).
                // Парсер корректно обрабатывает все эти случаи.
                break

            case .rightParenthesis:
                let prevIsOp = i > tokens.startIndex && isOperatorOrLeftParen(tokens[i - 1])
                if prevIsOp {
                    throw CalculatorError.doubleOperator
                }

            default:
                break
            }
        }
    }

    private func isOperatorOrLeftParen(_ token: Token) -> Bool {
        switch token {
        case .binaryOperator, .unaryMinus, .leftParenthesis:
            return true
        default:
            return false
        }
    }

    /// Проверяет, является ли токен оператором (без скобок).
    /// Используется для проверки следующего токена после binaryOperator:
    /// оператор после оператора — ошибка, но скобка после оператора — норма.
    private func isOperatorOnly(_ token: Token) -> Bool {
        switch token {
        case .binaryOperator, .unaryMinus:
            return true
        default:
            return false
        }
    }

    private func advance(_ i: inout String.Index, in str: String) {
        i = str.index(after: i)
    }
}
