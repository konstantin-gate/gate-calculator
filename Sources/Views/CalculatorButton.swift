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

enum ButtonLabel {
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
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true для широких кнопок (например, "=")
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

    // MARK: Цвета

    private var backgroundColor: Color {
        switch spec.type {
        case .digit:     return CalculatorColors.buttonDigit
        case .operator:  return CalculatorColors.buttonOperator
        case .function:  return CalculatorColors.buttonFunction
        }
    }

    private var foregroundColor: Color {
        switch spec.type {
        case .operator:  return CalculatorColors.buttonTextOperator
        default:         return CalculatorColors.buttonTextPrimary
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

    // MARK: - Визуальные свойства кнопок

    /// Закругление уголков: для операторов — 16, для цифр и функций — 12
    private var buttonCornerRadius: CGFloat {
        switch spec.type {
        case .operator:  return 16
        case .digit, .function: return 12
        }
    }

    /// Обводка нужна только для белых кнопок (digit и function)
    private var hasBorder: Bool {
        switch spec.type {
        case .digit, .function: return true
        case .operator: return false
        }
    }

    /// Цвет обводки: системный серый, адаптируется к светлой/тёмной теме
    private var borderColor: Color {
        return Color.secondary
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
                    .frame(width: 8, height: 8)
                    .padding(6)
                    .accessibilityHidden(true)
            }
            if spec.hasClipboardIndicator, let color = spec.clipboardIndicatorColor {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .padding(6)
                    .offset(x: -2, y: -2)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Long-press жест: визуально переключает C → AC (без вызова clear())
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
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
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: 5, y: -14)
        }
    }

    // MARK: Body

    var body: some View {
        let targetWidth: CGFloat = spec.isWide ? diameter * 2 + spacing : diameter

        buttonContent
            .frame(width: targetWidth, height: diameter)
            .background(
                isPressed
                    ? CalculatorColors.pressedColor(for: backgroundColor)
                    : backgroundColor
            )
            .clipShape(AnyShape(RoundedRectangle(cornerRadius: buttonCornerRadius)))
            .overlay {
                if hasBorder && !spec.isWide {
                    RoundedRectangle(cornerRadius: buttonCornerRadius)
                        .stroke(borderColor, lineWidth: 1.0)
                }
            }
            .overlay(alignment: .bottomTrailing) { indicatorsOverlay }
            .frame(width: targetWidth, height: diameter)
            .scaleEffect(isPressed ? 0.93 : 1.0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.08),
                value: isPressed
            )
            .simultaneousGesture(longPressGesture)
            .onChange(of: expression) { _, _ in
                isClearHolding = false
            }
            .simultaneousGesture(tapGesture)
            .accessibilityLabel(accessibilityLabelText)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(spec.accessibilityLabelOverride ?? spec.label.accessibilityDescription)
            .accessibilityIdentifier("calc_btn_\(spec.label.accessibilityIdentifierSuffix)")
            .opacity(spec.isEnabled ? 1.0 : 0.4)
            .onHover { hovering in isHovered = hovering }
            .overlay(alignment: .topTrailing) { tooltipOverlay }
    }
}

// MARK: - AnyShape (для совместимости типов Shape)

struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) { _path = { rect in shape.path(in: rect) } }
    func path(in rect: CGRect) -> Path { _path(rect) }
}

extension AnyShape: @unchecked Sendable {}
