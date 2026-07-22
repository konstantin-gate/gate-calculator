import SwiftUI

struct DisplayView: View {
    let expression: String
    let result: String?
    let errorMessage: String?

    @State private var shakeOffset: CGFloat = 0
    @State private var resultOpacity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {

            // --- Строка выражения (показывается только при активном вводе) ---
            if !expression.isEmpty && result == nil && errorMessage == nil {
                Text(formattedExpression)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(CalculatorColors.displayTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 4)

            // --- Главное число / результат / ошибка ---
            Group {
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(CalculatorColors.errorText)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.7)
                        .offset(x: shakeOffset)
                        .onChange(of: errorMessage) { _, newError in
                            guard newError != nil else { return }
                            // Анимация shake при ошибке
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
                                shakeOffset = 6
                            }
                            Task {
                                do {
                                    try await Task.sleep(nanoseconds: 350_000_000)
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
                        .minimumScaleFactor(0.5)
                        .truncationMode(.middle)
                        .opacity(resultOpacity)
                        .onChange(of: result) { _, newResult in
                            guard newResult != nil else { return }
                            // Анимация flash при результате: плавное изменение opacity 1.0 -> 0.6 -> 1.0
                            resultOpacity = 0.6
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.085)) {
                                resultOpacity = 1.0
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
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
        case 0...9:   return .system(size: 42, weight: .regular)
        case 10...12: return .system(size: 36, weight: .regular)
        case 13...15: return .system(size: 30, weight: .regular)
        default:      return .system(size: 24, weight: .regular)
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
