import SwiftUI

// MARK: - Типы кнопок калькулятора

enum CalcButtonType {
    /// Цифры (0–9), запятая, +/−
    case digit
    /// Арифметические операторы (÷, ×, −, +, =)
    case `operator`
    /// Функциональные кнопки (AC/C, ⌫, %, скобки, память, константы)
    case function
}

// MARK: - Метка кнопки

enum ButtonLabel: Hashable {
    // Стандартный режим
    case digit(String)                    // "0"–"9"
    case decimalSeparator                 // ","
    case clear                            // "AC" или "C" — динамически
    case backspace                        // "⌫"
    case plusMinus                        // "+/−"
    case percent                          // "%"
    case divide                           // "÷"
    case multiply                         // "×"
    case subtract                         // "−"
    case add                              // "+"
    case equals                           // "="
    case openParen                        // "("
    case closeParen                       // ")"
    // Память и константы (SRS §39-43, SRS §12)
    case mc                               // "MC" — очистить память
    case mPlus                            // "M+" — добавить в память
    case mMinus                           // "M−" — вычесть из памяти
    case mR                               // "MR" — вспомнить из памяти
    case clearAll                         // "AC" — полная очистка (expression, result, errorMessage)
    case sqrt                             // "√" — квадратный корень
    case square                           // "x²" — возведение в квадрат
    case clipboard                        // иконка буфера обмена (копировать / вставить)

    var displayTitle: String {
        switch self {
        case .digit(let s):        return s
        case .decimalSeparator:    return ","
        case .clear:               return "C"
        case .backspace:           return "⌫"
        case .plusMinus:           return "+/−"
        case .percent:             return "%"
        case .divide:              return "÷"
        case .multiply:            return "×"
        case .subtract:            return "−"
        case .add:                 return "+"
        case .equals:              return "="
        case .openParen:           return "("
        case .closeParen:          return ")"
        case .mc:                  return "MC"
        case .mPlus:               return "M+"
        case .mMinus:              return "M−"
        case .mR:                  return "MR"
        case .clearAll:            return "AC"
        case .sqrt:                return "√"
        case .square:              return "x²"
        case .clipboard:           return ""
        }
    }

    /// Значение, которое отправляется в ViewModel при нажатии
    var inputValue: String {
        switch self {
        case .decimalSeparator:    return "."
        case .divide:              return "/"
        case .multiply:            return "*"
        case .subtract:            return "-"
        case .add:                 return "+"
        case .openParen:           return "("
        case .closeParen:          return ")"
        case .clearAll:            return "AC"
        case .sqrt:                return "√"
        case .square:              return "x²"
        case .clipboard:           return ""
        default:                   return displayTitle
        }
    }

    /// Описание для VoiceOver / Accessibility
    var accessibilityDescription: String {
        switch self {
        case .divide:              return localizedString("accessibility.divide", comment: "")
        case .multiply:            return localizedString("accessibility.multiply", comment: "")
        case .subtract:            return localizedString("accessibility.subtract", comment: "")
        case .add:                 return localizedString("accessibility.add", comment: "")
        case .equals:              return localizedString("accessibility.equals", comment: "")
        case .clear:               return localizedString("accessibility.clear", comment: "")
        case .backspace:           return localizedString("accessibility.backspace", comment: "")
        case .plusMinus:           return localizedString("accessibility.plusMinus", comment: "")
        case .percent:             return localizedString("accessibility.percent", comment: "")
        case .decimalSeparator:    return localizedString("accessibility.decimalSeparator", comment: "")
        case .mc:                  return localizedString("accessibility.mc", comment: "")
        case .mPlus:               return localizedString("accessibility.mPlus", comment: "")
        case .mMinus:              return localizedString("accessibility.mMinus", comment: "")
        case .mR:                  return localizedString("accessibility.mR", comment: "")
        case .clearAll:            return localizedString("accessibility.clearAll", comment: "")
        case .sqrt:                return localizedString("accessibility.sqrt", comment: "")
        case .square:              return localizedString("accessibility.square", comment: "")
        case .clipboard:           return localizedString("accessibility.clipboard", comment: "")
        default:                   return displayTitle
        }
    }

    /// SF Symbol name для отображения в виде иконки вместо текста.
    /// nil для всех кнопок, у которых отображается текстовая метка.
    var iconSystemName: String? {
        switch self {
        case .clipboard:   return "doc.on.doc"
        default:           return nil
        }
    }

    /// Суффикс для accessibility identifier кнопки.
    /// Используется для формирования уникального и безопасного идентификатора вида "calc_btn_[suffix]".
    var accessibilityIdentifierSuffix: String {
        switch self {
        case .digit(let s):           return s
        case .decimalSeparator:       return "comma"
        case .clear:                  return "C"
        case .backspace:              return "backspace"
        case .plusMinus:              return "plus_minus"
        case .percent:                return "percent"
        case .divide:                 return "div"
        case .multiply:               return "mul"
        case .subtract:               return "sub"
        case .add:                    return "add"
        case .equals:                 return "eq"
        case .openParen:              return "lparen"
        case .closeParen:             return "rparen"
        case .mc:                     return "MC"
        case .mPlus:                  return "M_plus"
        case .mMinus:                 return "M_minus"
        case .mR:                     return "MR"
        case .clearAll:               return "AC"
        case .sqrt:                   return "sqrt"
        case .square:                 return "sq"
        case .clipboard:              return "clipboard"
        }
    }
}

// MARK: - Спецификация кнопки

struct ButtonSpec: Identifiable {
    var id: String { label.accessibilityIdentifierSuffix }
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true для широкой кнопки "0" (2 колонки)
    var isEnabled: Bool = true
    var hasMemoryIndicator: Bool = false
    var memoryTooltip: String? = nil
    var isAC: Bool = false      // true для динамической кнопки "AC" / "C"
    var iconOverride: String? = nil
    var accessibilityLabelOverride: String? = nil
    var hasClipboardIndicator: Bool = false
    var clipboardIndicatorColor: Color? = nil
    var clipboardTooltip: String? = nil
    var clipboardIndicatorBorderColor: Color? = nil
    var accessibilityValueOverride: String? = nil
}

// MARK: - Кнопка калькулятора (скруглённые квадраты, macOS Tahoe style)

struct CalculatorButton: View {

    let spec: ButtonSpec
    let diameter: CGFloat
    let fontSize: CGFloat
    let spacing: CGFloat        // расстояние между кнопками, для wide-кнопки "0"
    let onTap: (ButtonLabel) -> Void
    let expression: String      // текущее выражение из ViewModel (для onChange сброса isClearHolding)

    @State private var isPressed = false
    @State private var isClearHolding = false   // true = long-press переключил C → AC
    @State private var longPressConsumed = false // true = long-press обработан, тап пропускается
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calculatorTheme) private var theme

    // MARK: Цвета

    private var backgroundColor: Color {
        switch spec.type {
        case .digit:     return theme.buttonDigit
        case .operator:  return theme.buttonOperator
        case .function:  return theme.buttonFunction
        }
    }

    private var foregroundColor: Color {
        switch spec.type {
        case .operator:  return theme.buttonTextOperator
        default:         return theme.buttonTextPrimary
        }
    }

    private var displayText: String {
        // Приоритет отображения: isClearHolding (long-press) > spec.isAC (expression пуст) > default label.displayTitle
        if case .clear = spec.label, isClearHolding || spec.isAC {
            return "AC"
        }
        return spec.label.displayTitle
    }

    private var accessibilityLabelText: String {
        // Динамическая метка для VoiceOver: при long-press на .clear — «Очистить всё»
        if case .clear = spec.label, isClearHolding {
            return localizedString("accessibility.clearAll", comment: "")
        }
        return spec.accessibilityLabelOverride ?? spec.label.accessibilityDescription
    }

    /// Hint только для кнопок с контекстным действием:
    /// буфер обмена и кнопки памяти с подсказкой. Для остальных — nil
    /// (label уже исчерпывающе описывает кнопку, дублирование недопустимо).
    private var accessibilityHintText: String? {
        if case .clipboard = spec.label {
            return spec.clipboardTooltip
        }
        if spec.hasMemoryIndicator {
            return spec.memoryTooltip
        }
        return nil
    }

    // MARK: - Визуальные свойства кнопок

    // MARK: - Метрики отображения

    private enum Metrics {
        /// Закругление углов: операторы / цифры и функции
        static let cornerRadiusOperator: CGFloat = 16
        static let cornerRadiusDefault: CGFloat = 12
        /// Размер и отступ зелёного индикатора памяти
        static let memoryIndicatorSize: CGFloat = 8
        static let memoryIndicatorPadding: CGFloat = 6
        /// Размер, отступ и смещение индикатора буфера обмена
        static let clipboardIndicatorSize: CGFloat = 6
        static let clipboardIndicatorPadding: CGFloat = 6
        static let clipboardIndicatorOffsetX: CGFloat = -2
        static let clipboardIndicatorOffsetY: CGFloat = -2
        /// Длительность long-press (секунды)
        static let longPressDuration: Double = 0.5
        /// Тултип: шрифт, отступы, скругление, обводка, смещение
        static let tooltipFontSize: CGFloat = 12
        static let tooltipPaddingHorizontal: CGFloat = 10
        static let tooltipPaddingVertical: CGFloat = 6
        static let tooltipCornerRadius: CGFloat = 6
        static let tooltipBorderLineWidth: CGFloat = 1
        static let tooltipOffsetX: CGFloat = 5
        static let tooltipOffsetY: CGFloat = -14
        /// Обводка кнопки
        static let borderLineWidth: CGFloat = 1.0
        /// Анимация нажатия
        static let pressScale: CGFloat = 0.93
        static let pressAnimationDuration: Double = 0.08
        /// Прозрачность отключённой кнопки
        static let disabledOpacity: Double = 0.4
    }

    /// Закругление уголков: для операторов — 16, для цифр и функций — 12
    private var buttonCornerRadius: CGFloat {
        switch spec.type {
        case .operator:  return Metrics.cornerRadiusOperator
        case .digit, .function: return Metrics.cornerRadiusDefault
        }
    }

    /// Обводка нужна только для белых кнопок (digit и function)
    private var hasBorder: Bool {
        switch spec.type {
        case .digit, .function: return true
        case .operator: return false
        }
    }

    /// Barva obrysu: v tmavém tématu jemný bílý obrys, ve světlém systémová šedá.
    private var borderColor: Color {
        return theme.buttonBorder
    }

    // MARK: - Вынесенные компоненты body

    /// Содержимое кнопки: иконка (SF Symbol) или текстовая метка
    @ViewBuilder
    private var buttonContent: some View {
        if let icon = spec.iconOverride ?? spec.label.iconSystemName {
            Image(systemName: icon)
                .font(.system(size: fontSize, weight: .regular))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(foregroundColor)
        } else {
            Text(displayText)
                .font(.system(size: fontSize, weight: .regular))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(foregroundColor)
        }
    }

    /// Индикаторы памяти (зелёный кружок) и буфера обмена (цветной кружок)
    /// Оба positioned в bottomTrailing corner, clipboard со смещением (-2, -2)
    @ViewBuilder
    private var indicatorsOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            if spec.hasMemoryIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: Metrics.memoryIndicatorSize, height: Metrics.memoryIndicatorSize)
                    .padding(Metrics.memoryIndicatorPadding)
                    .accessibilityHidden(true)
            }
            if spec.hasClipboardIndicator, let color = spec.clipboardIndicatorColor {
                Circle()
                    .fill(color)
                    .frame(width: Metrics.clipboardIndicatorSize, height: Metrics.clipboardIndicatorSize)
                    .padding(Metrics.clipboardIndicatorPadding)
                    .offset(x: Metrics.clipboardIndicatorOffsetX, y: Metrics.clipboardIndicatorOffsetY)
                    .accessibilityHidden(true)
            }
        }
    }

// MARK: - Модификатор accessibilityHint для опциональной подсказки

private struct AccessibilityHintModifier: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

    /// Long-press жест: визуально переключает C → AC (без вызова clear())
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: Metrics.longPressDuration)
            .onEnded { _ in
                if case .clear = spec.label {
                    isClearHolding = true
                    longPressConsumed = true
                }
            }
    }

    /// Tap жест (DragGesture с minimumDistance:0) для обработки нажатий
    private var tapGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                isPressed = true
                longPressConsumed = false
            }
            .onEnded { _ in
                isPressed = false

                guard spec.isEnabled else { return }

                if longPressConsumed {
                    longPressConsumed = false
                    return
                }

                if case .clear = spec.label, isClearHolding {
                    isClearHolding = false
                    onTap(.clearAll)
                } else {
                    onTap(spec.label)
                }
            }
    }

    /// Hover-тултип для кнопок памяти и буфера обмена
    @ViewBuilder
    private var tooltipOverlay: some View {
        if isHovered, let tip = spec.memoryTooltip ?? spec.clipboardTooltip {
            Text(tip)
                .font(.system(size: Metrics.tooltipFontSize, weight: .regular))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, Metrics.tooltipPaddingHorizontal)
                .padding(.vertical, Metrics.tooltipPaddingVertical)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.tooltipCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.tooltipCornerRadius)
                        .stroke(Color.gray.opacity(0.5), lineWidth: Metrics.tooltipBorderLineWidth)
                )
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: Metrics.tooltipOffsetX, y: Metrics.tooltipOffsetY)
        }
    }

    // MARK: Body

    var body: some View {
        let targetWidth: CGFloat = spec.isWide ? diameter * 2 + spacing : diameter

        buttonContent
            .frame(width: targetWidth, height: diameter)
            .background(
                isPressed
                    ? CalculatorTheme.pressedColor(for: backgroundColor)
                    : backgroundColor
            )
            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
            .overlay {
                if hasBorder {
                    RoundedRectangle(cornerRadius: buttonCornerRadius)
                        .stroke(borderColor, lineWidth: Metrics.borderLineWidth)
                }
            }
            .overlay(alignment: .bottomTrailing) { indicatorsOverlay }
            .frame(width: targetWidth, height: diameter)
            .scaleEffect(isPressed ? Metrics.pressScale : 1.0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: Metrics.pressAnimationDuration),
                value: isPressed
            )
            .simultaneousGesture(longPressGesture)
            .onChange(of: expression) { _, _ in
                isClearHolding = false
            }
            .simultaneousGesture(tapGesture)
            .accessibilityLabel(accessibilityLabelText)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("calc_btn_\(spec.label.accessibilityIdentifierSuffix)")
            .accessibilityValue(spec.accessibilityValueOverride ?? "")
            .modifier(AccessibilityHintModifier(hint: accessibilityHintText))
            .opacity(spec.isEnabled ? 1.0 : Metrics.disabledOpacity)
            .onHover { hovering in isHovered = hovering }
            .overlay(alignment: .topTrailing) { tooltipOverlay }
    }
}
