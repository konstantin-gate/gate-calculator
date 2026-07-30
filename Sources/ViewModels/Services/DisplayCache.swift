import Foundation

@MainActor
struct DisplayCache {
    private(set) var cachedDisplayValue: Decimal?
    private(set) var cachedExpression: String = ""

    mutating func invalidate() {
        cachedExpression = ""
        cachedDisplayValue = nil
    }

    mutating func update(expression: String, value: Decimal?) {
        cachedExpression = expression
        cachedDisplayValue = value
    }
}
