import Foundation

/// Ошибки вычислительного движка калькулятора.
///
/// Перечисление описывает все возможные ошибки, которые могут возникнуть
/// при разборе и вычислении математического выражения.
public enum CalculatorError: Error, Sendable {
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
}
