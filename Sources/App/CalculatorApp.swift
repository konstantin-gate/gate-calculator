import SwiftUI
import AppKit

@main
struct CalculatorApp: App {
    @State private var viewModel = CalculatorViewModel()   // @Observable

    init() {
        #if os(macOS)
        if let imagePath = Bundle.module.path(forResource: "app_icon", ofType: "png"),
           let image = NSImage(contentsOfFile: imagePath) {
            NSApplication.shared.applicationIconImage = image
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            CalculatorContentView(viewModel: viewModel)
                .preferredColorScheme(nil)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
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
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyHandlerNSView, context: Context) {
        nsView.viewModel = viewModel
    }
}

@MainActor
class KeyHandlerNSView: NSView {
    weak var viewModel: CalculatorViewModel?

    override func keyDown(with event: NSEvent) {
        guard let viewModel else {
            super.keyDown(with: event)
            return
        }

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
        case 48:        // Tab — передаём в responder chain (keyboard navigation)
            super.keyDown(with: event)
        default:
            if !characters.isEmpty {
                let char = characters.first ?? " "
                if char.isNumber || "+-*/().%,".contains(char) {
                    let normalized = char == "," ? "." : String(char)
                    viewModel.appendCharacter(normalized)
                    return
                }
            }
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let cmd = event.modifierFlags.contains(.command)

        if cmd, event.charactersIgnoringModifiers == "v" {
            viewModel?.handleClipboardAction()
            return true
        }
        if cmd, event.charactersIgnoringModifiers == "c" {
            viewModel?.copyResult()
            return true
        }
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
