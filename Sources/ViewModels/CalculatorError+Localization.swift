import Foundation
import CalculatorEngine

extension CalculatorError {
    /// Локализованное описание ошибки с использованием бандла ресурсов приложения.
    public var localizedMessage: String {
        switch self {
        case .divisionByZero:
            return localizedString("errors.divisionByZero", comment: "")
        case .invalidExpression(let msg):
            // Пытаемся локализовать внутреннее сообщение, если для него есть ключ
            let localizedMsg = localizedString(msg, comment: "")
            if localizedMsg != msg {
                return localizedMsg
            }
            // Иначе возвращаем общую ошибку с подробностями
            return localizedString("errors.invalidExpression", comment: "") + ": \(msg)"
        case .missingClosingParenthesis:
            return localizedString("errors.missingParenthesis", comment: "")
        case .extraClosingParenthesis:
            return localizedString("errors.extraParenthesis", comment: "")
        case .invalidCharacter(let char):
            return localizedString("errors.invalidCharacter", comment: "") + ": \(char)"
        case .emptyExpression:
            return localizedString("errors.emptyExpression", comment: "")
        case .numberOverflow:
            return localizedString("errors.numberOverflow", comment: "")
        case .invalidNumber(let num):
            return localizedString("errors.invalidNumber", comment: "") + ": \(num)"
        case .doubleOperator:
            return localizedString("errors.doubleOperator", comment: "")
        }
    }
}
