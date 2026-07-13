import SwiftUI

// MARK: - Главный вид калькулятора

struct CalculatorView: View {

    @Bindable var viewModel: CalculatorViewModel
    @Binding var showHistory: Bool

    // Константы размеров — спецификация SRS §42
    private let buttonDiameter: CGFloat = 60
    private let buttonFontSize: CGFloat = 18
    private let buttonSpacing: CGFloat = 8

    /// Определяет, какую метку показывать на динамической кнопке очистки.
    /// true — показать «AC» (полная очистка): expression пуст.
    /// false — показать «C» (очистка текущего ввода): есть выражение.
    private var isAC: Bool {
        return viewModel.expression.isEmpty
    }

    /// Динамическая спецификация кнопки буфера обмена.
    /// Меняет иконку, описание accessibility, индикатор и тултип в зависимости от режима.
    private var clipboardSpec: ButtonSpec {
        let isPasteMode = viewModel.isClipboardPasteMode
        return ButtonSpec(
            label: .clipboard,
            type: .function,
            iconOverride: isPasteMode ? "doc.on.clipboard" : "doc.on.doc",
            accessibilityLabelOverride: isPasteMode
                ? NSLocalizedString("clipboard.paste", comment: "")
                : NSLocalizedString("clipboard.copy", comment: ""),
            hasClipboardIndicator: true,
            clipboardIndicatorColor: isPasteMode ? Color.green : CalculatorColors.buttonOperator,
            clipboardTooltip: isPasteMode
                ? NSLocalizedString("clipboard.paste.tooltip", comment: "")
                : NSLocalizedString("clipboard.copy.tooltip", comment: "")
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
        .background(CalculatorColors.background)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { showHistory = true } label: {
                    Image(systemName: "clock")
                }
                .help(NSLocalizedString("history.title", comment: ""))
                .accessibilityLabel(NSLocalizedString("history.title", comment: ""))
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
        VStack(spacing: buttonSpacing) {
            // Ряд 1: скобки, буфер обмена, backspace, AC/C (динамическая)
            buttonRow([
                ButtonSpec(label: .openParen,      type: .function),
                ButtonSpec(label: .closeParen,     type: .function),
                clipboardSpec,
                ButtonSpec(label: .backspace,      type: .function),
                ButtonSpec(label: isAC ? .clearAll : .clear, type: .function),
            ])
            // Ряд 2: память и деление
            buttonRow([
                ButtonSpec(label: .mc,             type: .function, isEnabled: viewModel.hasMemory),
                ButtonSpec(label: .mPlus,          type: .function),
                ButtonSpec(label: .mMinus,         type: .function),
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue),
                ButtonSpec(label: .divide,         type: .operator),
            ])
            // Ряд 3: %, +/−, √, x², ×
            buttonRow([
                ButtonSpec(label: .percent,        type: .function),
                ButtonSpec(label: .plusMinus,      type: .function),
                ButtonSpec(label: .sqrt,           type: .function),
                ButtonSpec(label: .square,         type: .function),
                ButtonSpec(label: .multiply,       type: .operator),
            ])
            // Ряд 4: 6, 7, 8, 9, −
            buttonRow([
                ButtonSpec(label: .digit("6"),     type: .digit),
                ButtonSpec(label: .digit("7"),     type: .digit),
                ButtonSpec(label: .digit("8"),     type: .digit),
                ButtonSpec(label: .digit("9"),     type: .digit),
                ButtonSpec(label: .subtract,       type: .operator),
            ])
            // Ряд 5: 2, 3, 4, 5, +
            buttonRow([
                ButtonSpec(label: .digit("2"),     type: .digit),
                ButtonSpec(label: .digit("3"),     type: .digit),
                ButtonSpec(label: .digit("4"),     type: .digit),
                ButtonSpec(label: .digit("5"),     type: .digit),
                ButtonSpec(label: .add,            type: .operator),
            ])
            // Ряд 6: 0, 1, запятая, = (широкая)
            buttonRow([
                ButtonSpec(label: .digit("0"),       type: .digit),
                ButtonSpec(label: .digit("1"),       type: .digit),
                ButtonSpec(label: .decimalSeparator, type: .digit),
                ButtonSpec(label: .equals,           type: .operator, isWide: true),
            ])
        }
    }

    // MARK: - Строка кнопок

    @ViewBuilder
    private func buttonRow(_ specs: [ButtonSpec]) -> some View {
        HStack(spacing: buttonSpacing) {
            ForEach(specs) { spec in
                CalculatorButton(
                    spec: spec,
                    diameter: buttonDiameter,
                    fontSize: buttonFontSize,
                    spacing: buttonSpacing
                ) { label in
                    handleButtonPress(label)
                }
            }
        }
    }

    // MARK: - Обработчик нажатий

    private func handleButtonPress(_ label: ButtonLabel) {
        switch label {
        case .clear:
            if isAC {
                viewModel.clear()
            } else {
                viewModel.clearCurrentInput()
            }
        case .clearAll:
            viewModel.clear()
        case .clipboard:
            if viewModel.displayValue != "0" {
                viewModel.copyResult()
            } else {
                if let text = ClipboardManager.shared.getString() {
                    viewModel.insertFromClipboard(text)
                }
            }
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
