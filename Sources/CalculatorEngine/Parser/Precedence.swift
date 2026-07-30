import Foundation

enum Precedence: Sendable {
    /// Приоритет + и − (самый низкий)
    case addition
    /// Приоритет ×, ÷ и % (средний)
    case multiplication
    /// Приоритет унарного минуса (выше × и ÷)
    case unaryMinus

    var value: Int {
        switch self {
        case .addition: return 1
        case .multiplication: return 2
        case .unaryMinus: return 3
        }
    }
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
}

extension Token {
    /// Возвращает значение приоритета для сравнения в алгоритме сортировочной станции.
    /// unaryMinus имеет приоритет 3 (выше × и ÷), percent — приоритет 2 (на уровне × и ÷).
    var precedenceValue: Int {
        switch self {
        case .binaryOperator(let op):
            return op.precedence.value
        case .percent:
            return Precedence.multiplication.value
        case .unaryMinus:
            return Precedence.unaryMinus.value
        case .number, .leftParenthesis, .rightParenthesis, .percentRelative:
            return Precedence.addition.value
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
