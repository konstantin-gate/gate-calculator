import SwiftUI

// MARK: - Главный вид калькулятора

struct CalculatorView: View {

    @Bindable var viewModel: CalculatorViewModel
    @Binding var showHistory: Bool

    // Константы размеров — спецификация SRS §42
    private let buttonDiameter: CGFloat = 60
    private let buttonFontSize: CGFloat = 18
    private let buttonSpacing: CGFloat = 8

    // AC или C — зависит от состояния ViewModel
    private var isAC: Bool {
        viewModel.expression.isEmpty && viewModel.resultDecimal == nil
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

    // MARK: - Стандартная сетка (4 колонки)

    @ViewBuilder
    private var standardButtonGrid: some View {
        VStack(spacing: buttonSpacing) {
            // Строка 1: память
            buttonRow([
                ButtonSpec(label: .mc,             type: .function, isEnabled: viewModel.hasMemory),
                ButtonSpec(label: .mPlus,          type: .function),
                ButtonSpec(label: .mMinus,         type: .function),
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue),
            ])
            // Строка 2: скобки, backspace, clear
            buttonRow([
                ButtonSpec(label: .openParen,      type: .function),
                ButtonSpec(label: .closeParen,     type: .function),
                ButtonSpec(label: .backspace,      type: .function),
                ButtonSpec(label: .clear,          type: .function),
            ])
            // Строка 3: %, ±, ÷, ×
            buttonRow([
                ButtonSpec(label: .percent,        type: .function),
                ButtonSpec(label: .plusMinus,      type: .function),
                ButtonSpec(label: .divide,         type: .operator),
                ButtonSpec(label: .multiply,       type: .operator),
            ])
            // Строка 4: 7, 8, 9, −
            buttonRow([
                ButtonSpec(label: .digit("7"), type: .digit),
                ButtonSpec(label: .digit("8"), type: .digit),
                ButtonSpec(label: .digit("9"), type: .digit),
                ButtonSpec(label: .subtract,   type: .operator),
            ])
            // Строка 5: 4, 5, 6, +
            buttonRow([
                ButtonSpec(label: .digit("4"), type: .digit),
                ButtonSpec(label: .digit("5"), type: .digit),
                ButtonSpec(label: .digit("6"), type: .digit),
                ButtonSpec(label: .add,        type: .operator),
            ])
            // Строка 6: 1, 2, 3, =
            buttonRow([
                ButtonSpec(label: .digit("1"), type: .digit),
                ButtonSpec(label: .digit("2"), type: .digit),
                ButtonSpec(label: .digit("3"), type: .digit),
                ButtonSpec(label: .equals,       type: .operator),
            ])
            buttonRow([
                ButtonSpec(label: .digit("0"),       type: .digit),
                ButtonSpec(label: .decimalSeparator, type: .digit),
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
                    isAC: isAC,
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
            viewModel.clear()
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
        }
    }
}
