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
        default:
            return 1   // На уровне + и −
        }
    }

    var isLeftAssoc: Bool {
        switch self {
        case .binaryOperator, .percent:
            return true
        case .unaryMinus:
            return false  // unary minus — right-associative (важно для "5*-3" = 5*(-3))
        default:
            return false
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
