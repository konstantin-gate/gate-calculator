import Foundation

/// Токенизатор математических выражений.
///
/// Преобразует строку выражения в последовательность токенов (`[Token]`).
/// Выполняет предварительную обработку: удаление "=", обработка переносов строк,
/// удаление пробелов-разделителей тысяч, нормализация десятичной запятой в точку, проверка на NaN/Infinity.
public struct Tokenizer: Sendable {

    /// Создаёт новый экземпляр токенизатора.
    public init() {}

    /// Односимвольные токены без контекстной логики.
    /// Минус обрабатывается отдельно (унарный/бинарный символ зависит от контекста).
    private let singleCharTokens: [Character: Token] = [
        "(": .leftParenthesis,
        ")": .rightParenthesis,
        "+": .binaryOperator(.add),
        "%": .percent,
        "*": .binaryOperator(.multiply),
        "/": .binaryOperator(.divide),
    ]

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

            if let token = singleCharTokens[char] {
                tokens.append(token)
                advance(&i, in: cleaned)
                continue
            }

            if char == "-" {
                let isUnary = tokens.isEmpty || isOperatorOrLeftParen(tokens.last!)

                if isUnary {
                    tokens.append(.unaryMinus)
                } else {
                    tokens.append(.binaryOperator(.subtract))
                }
                advance(&i, in: cleaned)
                continue
            }

            if char.isNumber || char == "." {
                let result: ReadNumberResult = try readNumber(cleaned, from: i)
                guard let number = result.number else {
                    throw CalculatorError.invalidCharacter(String(char))
                }
                tokens.append(.number(number))
                i = result.newIndex
                continue
            }

            throw CalculatorError.invalidCharacter(String(char))
        }

        try validateTokenSequence(tokens)
        return tokens
    }

    // Удаляет пробелы-разделители тысяч (пробелы между двумя цифрами)
    private func removeThousandsSeparatorSpaces(_ str: String) -> String {
        var result = ""

        let chars = Array(str)
        for i in chars.indices {
            if chars[i].isWhitespace && i > 0 && i + 1 < chars.count {
                if chars[i - 1].isNumber && chars[i + 1].isNumber {
                    continue
                }
            }
            result.append(chars[i])
        }

        return result
    }

    // Нормализует каждую запятую во внутренний десятичный разделитель ".".
    private func convertDecimalCommas(_ str: String) -> String {
        return str.replacingOccurrences(of: ",", with: ".")
    }

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

        // Удалить пробелы между цифрами (разделители тысяч в формате "37 878")
        result = removeThousandsSeparatorSpaces(result)

        // Нормализовать каждую запятую во внутренний десятичный разделитель "."
        result = convertDecimalCommas(result)

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Результат чтения числа.
    private struct ReadNumberResult {
        let number: Decimal?
        let newIndex: String.Index
    }

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
