import Foundation

public struct NumberFormatterService: Sendable {

    public static let shared = NumberFormatterService()

    private let formatter: NumberFormatter
    private let exponentialFormatter: NumberFormatter

    public init() {
        let usLocale = Locale(identifier: "en_US")

        formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = usLocale
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.allowsFloats = true
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = ","

        exponentialFormatter = NumberFormatter()
        exponentialFormatter.numberStyle = .scientific
        exponentialFormatter.locale = usLocale
        exponentialFormatter.maximumFractionDigits = 10
        exponentialFormatter.minimumFractionDigits = 0
    }

    public func format(_ value: Decimal) -> String {
        let absValue = value < 0 ? -value : value

        if absValue >= Decimal(string: "1e12") ?? .zero ||
            (absValue < Decimal(string: "0.000001") ?? .zero && absValue != 0) {
            if let formatted = exponentialFormatter.string(from: value as NSDecimalNumber) {
                // ИСПРАВЛЕНИЕ S-13: case-insensitive замена "E+" → "" и "E-" → "e-"
                return formatted.replacingOccurrences(of: "E+", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "E-", with: "e-", options: .caseInsensitive)
            }
        }

        if let formatted = formatter.string(from: value as NSDecimalNumber) {
            return formatted
        }

        return "\(value)"
    }
}
