import Foundation

/// Сервис форматирования чисел, изолированный на главном акторе.
///
/// Хранит экземпляры `NumberFormatter` как stored properties.
/// `NumberFormatter` — mutable reference type из Foundation (не thread-safe),
/// поэтому сервис помечен `@MainActor`: все вызовы `format()` происходят
/// на главном потоке.
@MainActor
public final class NumberFormatterService {

    /// Общий экземпляр сервиса.
    public static let shared = NumberFormatterService()

    private let formatter: NumberFormatter
    private let exponentialFormatter: NumberFormatter

    /// Инициализация форматтеров с локалью en_US.
    ///
    /// ОСОЗНАННОЕ РЕШЕНИЕ: Локаль захардкожена как "en_US" для единообразного отображения чисел
    /// независимо от системных настроек пользователя (десятичный разделитель — запятая ",",
    /// разделитель разрядов — пробел " "). Соответствует design-спецификации и поведению macOS Calculator.
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
        exponentialFormatter.exponentSymbol = "e"
    }

    /// Форматирует `Decimal` в строку с группировкой разрядов.
    /// Для значений >= 1e12 или < 0.000001 использует экспоненциальный формат.
    public func format(_ value: Decimal) -> String {
        let absValue = value < 0 ? -value : value

        if absValue >= Decimal(string: "1e12") ?? .zero ||
            (absValue < Decimal(string: "0.000001") ?? .zero && absValue != 0) {
            if let formatted = exponentialFormatter.string(from: value as NSDecimalNumber) {
                return formatted
            }
        }

        if let formatted = formatter.string(from: value as NSDecimalNumber) {
            return formatted
        }

        return "\(value)"
    }
}
