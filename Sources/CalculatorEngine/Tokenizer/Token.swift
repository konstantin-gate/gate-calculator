import Foundation

public enum Token: Equatable, Sendable {
    case number(Decimal)
    case binaryOperator(BinaryOperator)
    case unaryMinus
    case leftParenthesis
    case rightParenthesis
    case percent
    /// Относительный процент: вычисляется как left × (percentValue / 100).
    /// Создаётся в Parser.toRPN когда % стоит после + или -.
    case percentRelative(BinaryOperator, Decimal)
}

public enum BinaryOperator: String, Sendable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"

    var symbol: String { rawValue }
}
