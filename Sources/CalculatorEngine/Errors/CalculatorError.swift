import Foundation

/// Ошибки вычислительного движка калькулятора.
///
/// Перечисление описывает все возможные ошибки, которые могут возникнуть
/// при разборе и вычислении математического выражения.
public enum CalculatorError: Error, LocalizedError, Sendable {
    /// Деление на ноль.
    case divisionByZero

    /// Некорректное выражение с кастомным сообщением.
    case invalidExpression(String)

    /// Пропущена закрывающая скобка (например, "(15+16").
    case missingClosingParenthesis

    /// Лишняя закрывающая скобка (например, "15+16)").
    case extraClosingParenthesis

    /// Неверный символ в выражении (например, "15+a").
    case invalidCharacter(String)

    /// Пустое выражение.
    case emptyExpression

    /// Число слишком большое для точного представления.
    case numberOverflow

    /// Некорректное число с кастомным сообщением.
    case invalidNumber(String)

    /// Двойной оператор (например, "5++3").
    case doubleOperator

    /// Несколько десятичных разделителей (например, "1.5.3").
    case multipleDecimalSeparators

    /// Человекочитаемое описание ошибки.
    public var errorDescription: String? {
        switch self {
        case .divisionByZero:
            return NSLocalizedString("errors.divisionByZero", comment: "")
        case .invalidExpression(let msg):
            return NSLocalizedString(msg, comment: "")
        case .missingClosingParenthesis:
            return NSLocalizedString("errors.missingParenthesis", comment: "")
        case .extraClosingParenthesis:
            return NSLocalizedString("errors.extraParenthesis", comment: "")
        case .invalidCharacter(let char):
            return NSLocalizedString("errors.invalidCharacter", comment: "") + ": \(char)"
        case .emptyExpression:
            return NSLocalizedString("errors.emptyExpression", comment: "")
        case .numberOverflow:
            return NSLocalizedString("errors.numberOverflow", comment: "")
        case .invalidNumber(let num):
            return NSLocalizedString("errors.invalidNumber", comment: "") + ": \(num)"
        case .doubleOperator:
            return NSLocalizedString("errors.doubleOperator", comment: "")
        case .multipleDecimalSeparators:
            return NSLocalizedString("errors.multipleDecimalSeparators", comment: "")
        }
    }
}
