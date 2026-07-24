import Foundation

enum Precedence: Int, Sendable {
    case addition = 1
    case multiplication = 2
    case unaryMinus = 3
}

extension BinaryOperator {
    var precedence: Precedence {
        switch self {
        case .add, .subtract:
            return .addition
        case .multiply, .divide:
            return .multiplication
        }
    }

    var isLeftAssociative: Bool { true }
}

extension Token {
    /// Возвращает значение приоритета для сравнения в алгоритме сортировочной станции.
    /// unaryMinus имеет приоритет 3 (выше × и ÷), percent — приоритет 2 (на уровне × и ÷).
    var precedenceValue: Int {
        switch self {
        case .binaryOperator(let op):
            return op.precedence.rawValue
        case .percent:
            return 2   // На уровне × и ÷
        case .unaryMinus:
            return 3   // Выше, чем × и ÷ — чтобы "5*-3" парсилось как "5*(-3)"
        case .number:
            return 1   // Не оператор, приоритет = 1 (на уровне + и −)
        case .leftParenthesis:
            return 1   // Скобка, приоритет = 1 (для сортировочной станции)
        case .rightParenthesis:
            return 1   // Закрывающая скобка, приоритет = 1 (для сортировочной станции)
        case .percentRelative:
            return 1   // Относительный процент — не-оператор, приоритет = 1 (как в default)
        }
    }

    var isLeftAssoc: Bool {
        switch self {
        case .binaryOperator, .percent:
            return true
        case .unaryMinus:
            return false  // unary minus — right-associative (важно для "5*-3" = 5*(-3))
        case .number:
            return false  // Не оператор, не ассоциативен
        case .leftParenthesis:
            return false  // Скобка, не ассоциативна
        case .rightParenthesis:
            return false  // Закрывающая скобка, не ассоциативна
        case .percentRelative:
            return false  // Относительный процент — не-оператор, как в default
        }
    }

    var isOperator: Bool {
        if case .binaryOperator = self { return true }
        if case .percent = self { return true }
        if case .unaryMinus = self { return true }
        return false
    }

    var isLeftParen: Bool {
        if case .leftParenthesis = self { return true }
        return false
    }

    var isRightParen: Bool {
        if case .rightParenthesis = self { return true }
        return false
    }
}
