import SwiftUI

@main
struct CalculatorApp: App {
    @State private var viewModel = CalculatorViewModel()   // @Observable

    var body: some Scene {
        WindowGroup {
            CalculatorContentView(viewModel: viewModel)
                .preferredColorScheme(nil)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        // ИСПРАВЛЕНИЕ S-07 и перестановка кнопок 6x5: размеры 380×520
        .defaultSize(width: 380, height: 520)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct CalculatorContentView: View {
    @Bindable var viewModel: CalculatorViewModel  // @Observable
    @State private var showHistory = false

    var body: some View {
        CalculatorView(viewModel: viewModel, showHistory: $showHistory)
            .background(
                KeyHandlerView(viewModel: viewModel)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            )
    }
}

struct KeyHandlerView: NSViewRepresentable {
    @Bindable var viewModel: CalculatorViewModel

    func makeNSView(context: Context) -> KeyHandlerNSView {
        let view = KeyHandlerNSView()
        view.viewModel = viewModel

        // NSEventLocalMonitor перехватывает ⌘C на уровне run loop,
        // независимо от first responder. Возвращает nil для ⌘C (перехват),
        // все остальные события передаются дальше.
        view.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
                view.viewModel?.copyResult()
                return nil
            }
            return event
        }

        // ⌘C также обрабатывается в performKeyEquivalent как fallback,
        // когда монитор не перехватывает событие (например, при потере first responder).
        return view
    }

    func updateNSView(_ nsView: KeyHandlerNSView, context: Context) {
        nsView.viewModel = viewModel
    }
}

// ИСПРАВЛЕНИЕ M-07: добавлен @MainActor — KeyHandlerNSView вызывает viewModel методы на главном потоке
@MainActor
class KeyHandlerNSView: NSView {
    weak var viewModel: CalculatorViewModel?
    internal var eventMonitor: Any?

    override func keyDown(with event: NSEvent) {
        guard let viewModel else { return }

        let code = event.keyCode
        let characters = event.charactersIgnoringModifiers ?? ""

        switch code {
        case 53:        // Escape → AC/C
            viewModel.clear()
        case 51:        // Backspace/Delete
            viewModel.backspace()
        case 36, 76:    // Return / Enter → =
            viewModel.evaluate()
        case 75:        // Numpad /
            viewModel.appendCharacter("/")
        case 67:        // Numpad *
            viewModel.appendCharacter("*")
        case 78:        // Numpad −
            viewModel.appendCharacter("-")
        case 69:        // Numpad +
            viewModel.appendCharacter("+")
        case 48:        // Tab — ИСПРАВЛЕНИЕ S-11
            // Tab / Shift+Tab: в текущей реализации фокус калькулятора
            // (без полноценной keyboard navigation) — заглушка
            break
        default:
            if !characters.isEmpty {
                let char = characters.first ?? " "
                if char.isNumber || "+-*/().%,".contains(char) {
                    let normalized = char == "," ? "." : String(char)
                    viewModel.appendCharacter(normalized)
                }
            }
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let cmd = event.modifierFlags.contains(.command)

        if cmd, event.charactersIgnoringModifiers == "c" {
            viewModel?.copyResult()
            return true
        }
        if cmd, event.charactersIgnoringModifiers == "v" {
            if let text = ClipboardManager.shared.getString() {
                viewModel?.insertFromClipboard(text)
            }
            return true
        }
        // ИСПРАВЛЕНИЕ S-10: ⌘A и ⌘Z
        if cmd, event.charactersIgnoringModifiers == "a" {
            // Select All — в контексте калькулятора заглушка
            return true
        }
        if cmd, event.charactersIgnoringModifiers == "z" {
            // Undo — заглушка (может быть реализовано в будущем)
            return false
        }

        return super.performKeyEquivalent(with: event)
    }

    override var acceptsFirstResponder: Bool { true }
}
