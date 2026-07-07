import Foundation

public enum Token: Equatable, Sendable {
    case number(Decimal)
    case binaryOperator(BinaryOperator)
    case unaryMinus
    case leftParenthesis
    case rightParenthesis
    case percent
}

public enum BinaryOperator: String, Sendable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"

    var symbol: String { rawValue }
}
