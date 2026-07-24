import Foundation

/// Математические константы вычислительного движка.
///
/// Все константы инициализируются безопасными initializer'ами Decimal
/// и гарантированно не вызывают runtime-ошибок.
enum EngineConstants {

    /// Константа 100 — используется при вычислении процентов.
    static let hundred: Decimal = Decimal(100)

    /// Константа 1e-28 — точность сходимости метода Ньютона-Герона для √.
    static let epsilon: Decimal = Decimal(sign: .plus, exponent: -28, significand: 1)

    /// Максимальное количество итераций метода Ньютона-Герона.
    static let maxNewtonIterations: Int = 100
}
