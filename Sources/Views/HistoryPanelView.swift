import SwiftUI

struct HistoryPanelView: View {
    @Bindable var viewModel: CalculatorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if viewModel.historyEntries.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString("history.empty.title", comment: ""),
                    systemImage: "clock",
                    description: Text(NSLocalizedString("history.empty.description", comment: ""))
                )
            } else {
                List(viewModel.historyEntries) { entry in
                    Button {
                        viewModel.useHistoryEntry(entry)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.expression)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)

                            Text(entry.timestamp, style: .time)
                                .font(.system(size: 12))
                                .foregroundStyle(CalculatorColors.displayTextSecondary)

                            Text("= \(NumberFormatterService.shared.format(entry.result))")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(NSLocalizedString("history.title", comment: ""))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("history.done", comment: "")) { dismiss() }
            }

            ToolbarItem(placement: .destructiveAction) {
                Button(NSLocalizedString("history.clear", comment: "")) {
                    viewModel.clearHistory()
                }
                .disabled(viewModel.historyEntries.isEmpty)
            }
        }
        .frame(width: 340, height: 500)
    }
}
