import SwiftUI

struct DisplayView: View {

    // MARK: - Константы размеров и анимации

    // MARK: Размер шрифта выражения (вторичный текст)
    /// Размер шрифта для строки выражения. Совпадает с `buttonFontSize` в CalculatorView для визуальной согласованности.
    private static let fontSizeExpression: CGFloat = 18

    // MARK: Размер шрифта ошибки
    /// Размер шрифта для отображения сообщений об ошибках.
    private static let fontSizeError: CGFloat = 22

    // MARK: Адаптивные размеры шрифтов (главный текст / результат)
    /// Максимальный размер адаптивного шрифта — для коротких чисел (0–9 символов).
    private static let fontSizeMax: CGFloat = 42
    /// Средний размер адаптивного шрифта — для средних чисел (10–12 символов).
    private static let fontSizeMedium: CGFloat = 36
    /// Малый размер адаптивного шрифта — для длинных чисел (13–15 символов).
    private static let fontSizeSmall: CGFloat = 30
    /// Минимальный размер адаптивного шрифта — для очень длинных чисел (16+ символов).
    private static let fontSizeMin: CGFloat = 24

    // MARK: Параметры анимации shake (тряска при ошибке)
    /// Длительность одного цикла анимации shake в секундах.
    private static let shakeDurationPerCycle: Double = 0.06
    /// Количество повторов анимации shake (тип Int, так как Animation.repeatCount(_:) принимает Int).
    private static let shakeRepeatCount: Int = 4
    /// Расстояние тряски в пунктах (pt).
    private static let shakeAmplitude: CGFloat = 6
    /// Задержка перед сбросом тряски в наносекундах (0,35 секунды).
    private static let shakeResetDelayNanos: UInt64 = 350_000_000

    // MARK: Параметры анимации flash (вспышка при результате)
    /// Промежуточное значение opacity перед flash-анимацией.
    private static let flashOpacityIntermediate: Double = 0.6
    /// Длительность анимации вспышки opacity в секундах.
    private static let flashDuration: Double = 0.085

    // MARK: Масштабирование текста
    /// Минимальный масштаб текста ошибки при усечении (truncationMode .middle).
    private static let errorMinimumScaleFactor: Double = 0.7
    /// Минимальный масштаб основного текста (результат/выражение) при усечении.
    private static let mainMinimumScaleFactor: Double = 0.5

    // MARK: Параметры layout
    /// Вертикальный отступ между строкой выражения и главным текстом (VStack spacing).
    private static let vstackSpacing: CGFloat = 4
    /// Минимальная длина Spacer между строкой выражения и главным текстом.
    private static let spacerMinLength: CGFloat = 4
    /// Горизонтальный отступ дисплея.
    private static let paddingHorizontal: CGFloat = 20
    /// Верхний отступ дисплея.
    private static let paddingTop: CGFloat = 8
    /// Нижний отступ дисплея.
    private static let paddingBottom: CGFloat = 12

    let expression: String
    let result: String?
    let errorMessage: String?

    @State private var shakeOffset: CGFloat = 0
    @State private var resultOpacity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: Self.vstackSpacing) {

            // --- Строка выражения (показывается только при активном вводе) ---
            if !expression.isEmpty && result == nil && errorMessage == nil {
                Text(formattedExpression)
                    .font(.system(size: Self.fontSizeExpression, weight: .regular))
                    .foregroundStyle(CalculatorColors.displayTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: Self.spacerMinLength)

            // --- Главное число / результат / ошибка ---
            Group {
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: Self.fontSizeError, weight: .regular))
                        .foregroundStyle(CalculatorColors.errorText)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(Self.errorMinimumScaleFactor)
                        .offset(x: shakeOffset)
                        .onChange(of: errorMessage) { _, newError in
                            guard newError != nil else { return }
                            // Анимация shake при ошибке
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: Self.shakeDurationPerCycle).repeatCount(Self.shakeRepeatCount, autoreverses: true)) {
                                shakeOffset = Self.shakeAmplitude
                            }
                            Task {
                                do {
                                    try await Task.sleep(nanoseconds: Self.shakeResetDelayNanos)
                                    // ИСПРАВЛЕНИЕ N-05: проверка cancellation
                                    if !Task.isCancelled {
                                        shakeOffset = 0
                                    }
                                } catch {
                                    // cancelled — ignore
                                }
                            }
                        }
                } else {
                    let mainText = result ?? (expression.isEmpty ? "0" : expression)
                    Text(mainText)
                        .font(adaptiveFont(for: mainText))
                        .foregroundStyle(CalculatorColors.displayTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(Self.mainMinimumScaleFactor)
                        .truncationMode(.middle)
                        .opacity(resultOpacity)
                        .onChange(of: result) { _, newResult in
                            guard newResult != nil else { return }
                            // Анимация flash при результате: плавное изменение opacity 1.0 -> 0.6 -> 1.0
                            resultOpacity = Self.flashOpacityIntermediate
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: Self.flashDuration)) {
                                resultOpacity = 1.0
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, Self.paddingHorizontal)
        .padding(.top, Self.paddingTop)
        .padding(.bottom, Self.paddingBottom)
        // Accessibility для всего дисплея
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            if let error = errorMessage {
                return "Ошибка: \(error)"
            } else if let result = result {
                return "Результат: \(result)"
            } else {
                return expression.isEmpty ? "Ноль" : "Выражение: \(expression)"
            }
        }())
    }

    // MARK: - Адаптивный шрифт

    // ИСПРАВЛЕНИЕ S-02: размеры 42/36/30/24 вместо 70/56/44/32, удалён .design(.rounded)
    private func adaptiveFont(for text: String) -> Font {
        let count = text.count
        switch count {
        case 0...9:   return .system(size: Self.fontSizeMax, weight: .regular)
        case 10...12: return .system(size: Self.fontSizeMedium, weight: .regular)
        case 13...15: return .system(size: Self.fontSizeSmall, weight: .regular)
        default:      return .system(size: Self.fontSizeMin, weight: .regular)
        }
    }

    // MARK: - Форматирование выражения для отображения

    private var formattedExpression: String {
        var result = expression
            .replacingOccurrences(of: "/", with: " ÷ ")
            .replacingOccurrences(of: "*", with: " × ")
            .replacingOccurrences(of: ".", with: ",")

        // ИСПРАВЛЕНИЕ S-14: возвращена замена "." на "," — formatter теперь использует запятую
        // ИСПРАВЛЕНИЕ S-15: различаем унарный и бинарный минус
        var formatted = ""
        var prevChar: Character? = nil
        for char in result {
            if char == "-" {
                let isUnary = prevChar == nil || prevChar == "("
                if isUnary {
                    formatted.append(" −") // Унарный — без пробела перед
                } else {
                    formatted.append(" − ") // Бинарный — с пробелами
                }
            } else {
                formatted.append(char)
            }
            prevChar = char == " " ? prevChar : char
        }
        result = formatted

        return result
    }
}
