import SwiftUI

// MARK: - Téma vzhledu kalkulačky (světlé/tmavé)

/// Hodnoty tématu pro světlý a tmavý režim.
/// Zdrojem pravdy o režimu je vlastnost `isDark`; barvy se odvozují z tohoto příznaku.
struct CalculatorTheme: Sendable {

    /// `true` — tmavé téma, `false` — světlé téma.
    let isDark: Bool

    // MARK: - Pozadí

    /// Pozadí obsahu okna. V tmavém tématu je průhledné —
    /// podklad tvoří `VisualEffectBackground` (matné sklo).
    var background: Color {
        isDark ? Color.clear : Color(nsColor: .windowBackgroundColor)
    }

    // MARK: - Tlačítka

    /// Pozadí číselných tlačítek (0–9, čárka).
    var buttonDigit: Color {
        isDark ? Color(red: 0.345, green: 0.333, blue: 0.349) : Color.white
    }

    /// Pozadí funkčních tlačítek (AC/C, ⌫, %, závorky, paměť, √, x²).
    var buttonFunction: Color {
        isDark ? Color(red: 0.541, green: 0.541, blue: 0.553) : Color.white
    }

    /// Pozadí tlačítek operátorů (÷, ×, −, +, =) — oranžová zůstává v obou tématech.
    var buttonOperator: Color {
        Color(nsColor: .systemOrange)
    }

    /// Barva textu a ikon na číselných a funkčních tlačítkách.
    var buttonTextPrimary: Color {
        Color(nsColor: .labelColor)
    }

    /// Barva textu na tlačítkách operátorů.
    var buttonTextOperator: Color {
        Color.white
    }

    /// Barva obrysu číselných a funkčních tlačítek.
    var buttonBorder: Color {
        isDark ? Color.white.opacity(0.12) : Color.secondary
    }

    // MARK: - Displej

    /// Hlavní text displeje (výsledek/hodnota).
    var displayTextPrimary: Color {
        Color(nsColor: .labelColor)
    }

    /// Vedlejší text displeje (výraz).
    var displayTextSecondary: Color {
        Color(nsColor: .secondaryLabelColor)
    }

    /// Text chybové zprávy.
    var errorText: Color {
        Color(nsColor: .systemRed)
    }

    // MARK: - Stav stisknutí

    /// Barva stisknutého tlačítka.
    static func pressedColor(for base: Color) -> Color {
        base.opacity(0.7)
    }
}

// MARK: - Prostředí SwiftUI

private struct CalculatorThemeKey: EnvironmentKey {
    static let defaultValue = CalculatorTheme(isDark: false)
}

extension EnvironmentValues {
    /// Aktivní téma kalkulačky.
    var calculatorTheme: CalculatorTheme {
        get { self[CalculatorThemeKey.self] }
        set { self[CalculatorThemeKey.self] = newValue }
    }
}

// MARK: - Uložené uživatelské nastavení

extension CalculatorTheme {
    /// Klíč uživatelského nastavení pro uložený režim vzhledu (tmavý/světlý).
    static let userDefaultsKey = "isDarkTheme"
}
