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
    case pi                               // "π"
    case eulerConst                       // "e"

    var displayTitle: String {
        switch self {
        case .digit(let s):        return s
        case .decimalSeparator:    return ","
        case .clear:               return "AC"
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
        case .pi:                  return "π"
        case .eulerConst:          return "e"
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
        case .eulerConst:          return "e"
        case .pi:                  return "π"
        default:                   return displayTitle
        }
    }

    /// Описание для VoiceOver / Accessibility
    var accessibilityDescription: String {
        switch self {
        case .divide:              return "Разделить"
        case .multiply:            return "Умножить"
        case .subtract:            return "Минус"
        case .add:                 return "Плюс"
        case .equals:              return "Равно"
        case .clear:               return "Очистить"
        case .backspace:           return "Удалить последний символ"
        case .plusMinus:           return "Изменить знак"
        case .percent:             return "Процент"
        case .decimalSeparator:    return "Десятичная запятая"
        case .mc:                  return "Очистить память"
        case .mPlus:               return "Добавить в память"
        case .mMinus:              return "Вычесть из памяти"
        case .mR:                  return "Вспомнить из памяти"
        case .pi:                  return "Число Пи"
        case .eulerConst:          return "Число Эйлера"
        default:                   return displayTitle
        }
    }
}

// MARK: - Спецификация кнопки

struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
    var hasMemoryIndicator: Bool = false
    var memoryTooltip: String? = nil
}

// MARK: - Кнопка калькулятора (скруглённые квадраты, macOS Tahoe style)

struct CalculatorButton: View {

    let spec: ButtonSpec
    let diameter: CGFloat
    let fontSize: CGFloat
    let isAC: Bool              // true → "AC", false → "C" (только для .clear)
    let spacing: CGFloat        // расстояние между кнопками, для wide-кнопки "0"
    let onTap: (ButtonLabel) -> Void

    @State private var isPressed = false
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
        if case .clear = spec.label {
            return isAC ? "AC" : "C"
        }
        return spec.label.displayTitle
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

    // MARK: Body

    var body: some View {
        // Широкая кнопка "0": диаметр × 2 + spacing
        let targetWidth: CGFloat = spec.isWide ? diameter * 2 + spacing : diameter

        Button {
            guard spec.isEnabled else { return }
            onTap(spec.label)
        } label: {
            Text(displayText)
                .font(.system(size: fontSize, weight: .regular))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(foregroundColor)
                .frame(width: targetWidth, height: diameter)
                .background(
                    isPressed
                        ? CalculatorColors.pressedColor(for: backgroundColor)
                        : backgroundColor
                )
                .clipShape(
                    spec.isWide
                        ? AnyShape(Capsule())
                        : AnyShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
                )
                .overlay {
                    if hasBorder && !spec.isWide {
                        RoundedRectangle(cornerRadius: buttonCornerRadius)
                            .stroke(borderColor, lineWidth: 1.0)
                    }
                }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if spec.hasMemoryIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: targetWidth, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.08),
            value: isPressed
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .accessibilityLabel(spec.label.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(spec.label.accessibilityDescription)
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        .onHover { hovering in isHovered = hovering }
        .overlay(alignment: .topTrailing) {
            if isHovered, let tip = spec.memoryTooltip {
                Text(tip)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: 5, y: -14)
            }
        }
    }
}

// MARK: - AnyShape (для совместимости типов Shape)

struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) { _path = { rect in shape.path(in: rect) } }
    func path(in rect: CGRect) -> Path { _path(rect) }
}

extension AnyShape: @unchecked Sendable {}
