import Foundation
import CalculatorEngine

extension CalculatorError {
    /// Локализованное описание ошибки с использованием бандла ресурсов приложения.
    public var localizedMessage: String {
        switch self {
        case .divisionByZero:
            return localizedString("errors.divisionByZero", comment: "")
        case .invalidExpression(let msg):
            let localizedMsg = localizedString(msg, comment: "")
            if localizedMsg != msg {
                return localizedMsg
            }
            return String.localizedStringWithFormat(localizedString("errors.invalidExpressionWithDetail", comment: ""), msg)
        case .missingClosingParenthesis:
            return localizedString("errors.missingParenthesis", comment: "")
        case .extraClosingParenthesis:
            return localizedString("errors.extraParenthesis", comment: "")
        case .invalidCharacter(let char):
            return String.localizedStringWithFormat(localizedString("errors.invalidCharacterWithDetail", comment: ""), char)
        case .emptyExpression:
            return localizedString("errors.emptyExpression", comment: "")
        case .invalidNumber(let num):
            return String.localizedStringWithFormat(localizedString("errors.invalidNumberWithDetail", comment: ""), num)
        case .doubleOperator:
            return localizedString("errors.doubleOperator", comment: "")
        }
    }
}
