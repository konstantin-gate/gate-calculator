import SwiftUI
import AppKit

// MARK: - Цветовая система, эталон: Calculator.app macOS Tahoe 26

struct CalculatorColors {

    // MARK: Фон окна/приложения
    static let background = Color(nsColor: .windowBackgroundColor)

    // MARK: Фон дисплея
    static let displayBackground = Color.clear

    // MARK: Кнопки — цифры и нейтральные (0-9, +/−, запятая)
    static let buttonDigit = Color(nsColor: NSColor(name: "controlBackgroundColor") { appearance in
        return .controlColor
    })

    // MARK: Кнопки — функциональные (AC/C, ⌫, %, скобки, память, константы)
    static let buttonFunction = Color(nsColor: NSColor(name: "controlBackgroundColor") { appearance in
        return .textBackgroundColor
    })

    // MARK: Кнопки — арифметические операторы (÷, ×, −, +, =)
    static let buttonOperator = Color(nsColor: .systemOrange)

    // MARK: Текст на цифровых и функциональных кнопках
    static let buttonTextPrimary = Color(nsColor: .labelColor)

    // MARK: Текст на кнопках операторов
    static let buttonTextOperator = Color.white

    // MARK: Основной текст дисплея (число/результат)
    static let displayTextPrimary = Color(nsColor: .labelColor)

    // MARK: Вторичный текст дисплея (выражение/история)
    static let displayTextSecondary = Color(nsColor: .secondaryLabelColor)

    // MARK: Цвет ошибки на дисплее
    static let errorText = Color(nsColor: .systemRed)

    // MARK: Нажатое состояние кнопки (highlight)
    static func pressedColor(for base: Color) -> Color {
        return base.opacity(0.7)
    }
}
