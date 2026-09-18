import SwiftUI

// MARK: - Главный вид калькулятора

struct CalculatorView: View {

    @Bindable var viewModel: CalculatorViewModel
    @Binding var showHistory: Bool

    private enum LayoutMetrics {
        static let buttonDiameter: CGFloat = 60
        static let buttonFontSize: CGFloat = 18
        static let buttonSpacing: CGFloat = 8
    }

    /// Определяет, какую метку показывать на динамической кнопке очистки.
    /// true — показать «AC» (полная очистка): expression пуст.
    /// false — показать «C» (очистка текущего ввода): есть выражение.
    private var isAC: Bool {
        return viewModel.expression.isEmpty
    }

    /// Динамическая спецификация кнопки буфера обмена.
    /// Меняет описание accessibility, индикатор и тултип в зависимости от режима.
    private var clipboardSpec: ButtonSpec {
        let isPasteMode = viewModel.isClipboardPasteMode
        return ButtonSpec(
            label: .clipboard,
            type: .function,
            iconOverride: "doc.on.doc",
            accessibilityLabelOverride: isPasteMode
                ? localizedString("clipboard.paste", comment: "")
                : localizedString("clipboard.copy", comment: ""),
            hasClipboardIndicator: viewModel.hasResult,
            clipboardIndicatorColor: CalculatorColors.buttonOperator,
            clipboardTooltip: isPasteMode
                ? localizedString("clipboard.paste.tooltip", comment: "")
                : localizedString("clipboard.copy.tooltip", comment: ""),
            clipboardIndicatorBorderColor: nil,
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DisplayView(
                expression: viewModel.expression,
                result: viewModel.result,
                errorMessage: viewModel.errorMessage
            )
            .frame(minHeight: 90)

            Divider()
                .opacity(0.3)
                .padding(.horizontal, 12)

            standardButtonGrid
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .task {
            await viewModel.loadInitialHistory()
        }
        .background(CalculatorColors.background)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { showHistory = true } label: {
                    Image(systemName: "clock")
                }
                .help(localizedString("history.title", comment: ""))
                .accessibilityLabel(localizedString("history.title", comment: ""))
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryPanelView(viewModel: viewModel)
                .frame(width: 340, height: 500)
        }
    }

    // MARK: - Стандартная сетка (5 столбцов)

    @ViewBuilder
    private var standardButtonGrid: some View {
        VStack(spacing: LayoutMetrics.buttonSpacing) {
            // Ряд 1: скобки, буфер обмена, backspace, AC/C (динамическая)
            buttonRow([
                ButtonSpec(label: .openParen,      type: .function),
                ButtonSpec(label: .closeParen,     type: .function),
                clipboardSpec,
                ButtonSpec(label: .backspace,      type: .function),
                ButtonSpec(label: isAC ? .clearAll : .clear, type: .function, isAC: isAC),
            ])
            // Ряд 2: память и деление
            buttonRow([
                ButtonSpec(label: .mc,             type: .function, isEnabled: viewModel.hasMemory),
                ButtonSpec(label: .mPlus,          type: .function),
                ButtonSpec(label: .mMinus,         type: .function),
                ButtonSpec(
                    label: .mR, type: .function,
                    isEnabled: viewModel.hasMemory,
                    memoryTooltip: viewModel.memoryDisplayValue,
                    accessibilityValueOverride: viewModel.memoryDisplayValue ?? ""
                ),
                ButtonSpec(label: .divide,         type: .operator),
            ])
            // Ряд 3: 7, 8, 9, %, ×
            buttonRow([
                ButtonSpec(label: .digit("7"),     type: .digit),
                ButtonSpec(label: .digit("8"),     type: .digit),
                ButtonSpec(label: .digit("9"),     type: .digit),
                ButtonSpec(label: .percent,        type: .function),
                ButtonSpec(label: .multiply,       type: .operator),
            ])
            // Ряд 4: 4, 5, 6, +/−, −
            buttonRow([
                ButtonSpec(label: .digit("4"),     type: .digit),
                ButtonSpec(label: .digit("5"),     type: .digit),
                ButtonSpec(label: .digit("6"),     type: .digit),
                ButtonSpec(label: .plusMinus,      type: .function),
                ButtonSpec(label: .subtract,       type: .operator),
            ])
            // Ряд 5: 1, 2, 3, √, +
            buttonRow([
                ButtonSpec(label: .digit("1"),     type: .digit),
                ButtonSpec(label: .digit("2"),     type: .digit),
                ButtonSpec(label: .digit("3"),     type: .digit),
                ButtonSpec(label: .sqrt,           type: .function),
                ButtonSpec(label: .add,            type: .operator),
            ])
            // Ряд 6: 0 (широкая, 2 колонки), запятая, x², =
            buttonRow([
                ButtonSpec(label: .digit("0"),       type: .digit, isWide: true),
                ButtonSpec(label: .decimalSeparator, type: .digit),
                ButtonSpec(label: .square,           type: .function),
                ButtonSpec(label: .equals,           type: .operator),
            ])
        }
    }

    // MARK: - Строка кнопок

    @ViewBuilder
    private func buttonRow(_ specs: [ButtonSpec]) -> some View {
        HStack(spacing: LayoutMetrics.buttonSpacing) {
            ForEach(specs) { spec in
                CalculatorButton(
                    spec: spec, diameter: LayoutMetrics.buttonDiameter,
                    fontSize: LayoutMetrics.buttonFontSize, spacing: LayoutMetrics.buttonSpacing,
                    onTap: { label in
                        handleButtonPress(label)
                    }, expression: viewModel.expression
                )
            }
        }
    }

    // MARK: - Обработчик нажатий

    private func handleButtonPress(_ label: ButtonLabel) {
        switch label {
        case .clear:
            viewModel.clearCurrentInput()
        case .clearAll:
            viewModel.clear()
        case .clipboard:
            viewModel.handleClipboardAction()
        case .equals:
            viewModel.evaluate()
        case .backspace:
            viewModel.backspace()
        case .plusMinus:
            viewModel.toggleSign()
        case .percent:
            viewModel.appendCharacter("%")
        case .divide, .multiply, .subtract, .add,
             .openParen, .closeParen:
            viewModel.appendCharacter(label.inputValue)
        case .decimalSeparator:
            viewModel.appendCharacter(".")
        case .digit(let d):
            viewModel.appendCharacter(d)
        case .mc:
            viewModel.memoryClear()
        case .mPlus:
            viewModel.memoryAdd()
        case .mMinus:
            viewModel.memorySubtract()
        case .mR:
            viewModel.memoryRecall()
        case .sqrt:
            viewModel.calculateSquareRoot()
        case .square:
            viewModel.calculateSquare()
        }
    }
}
