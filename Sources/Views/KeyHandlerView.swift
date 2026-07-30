import SwiftUI
import AppKit

// MARK: - KeyCode Константы

enum KeyCode {
    static let escape: UInt16 = 53
    static let delete: UInt16 = 51
    static let returnKey: UInt16 = 36
    static let enterKey: UInt16 = 76
    static let numpadDivide: UInt16 = 75
    static let numpadMultiply: UInt16 = 67
    static let numpadMinus: UInt16 = 78
    static let numpadPlus: UInt16 = 69
    static let tab: UInt16 = 48
}

// MARK: - KeyHandlerView (Representable)

struct KeyHandlerView: NSViewRepresentable {
    @Bindable var viewModel: CalculatorViewModel

    func makeNSView(context: Context) -> KeyHandlerNSView {
        let view = KeyHandlerNSView()
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: KeyHandlerNSView, context: Context) {
        nsView.viewModel = viewModel
    }
}

// MARK: - KeyHandlerNSView

@MainActor
final class KeyHandlerNSView: NSView {
    weak var viewModel: CalculatorViewModel?
    private nonisolated(unsafe) var windowObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerWindowObserver()
        makeMeFirstResponder()
    }

    private func registerWindowObserver() {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        guard let window = self.window else { return }

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.makeMeFirstResponder()
            }
        }
    }

    private func makeMeFirstResponder() {
        guard let window = self.window, window.firstResponder != self else { return }
        window.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let viewModel else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case KeyCode.escape:
            viewModel.clear()
        case KeyCode.delete:
            viewModel.backspace()
        case KeyCode.returnKey, KeyCode.enterKey:
            viewModel.evaluate()
        case KeyCode.numpadDivide:
            viewModel.appendCharacter("/")
        case KeyCode.numpadMultiply:
            viewModel.appendCharacter("*")
        case KeyCode.numpadMinus:
            viewModel.appendCharacter("-")
        case KeyCode.numpadPlus:
            viewModel.appendCharacter("+")
        case KeyCode.tab:
            super.keyDown(with: event)
        default:
            if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
                let char = characters.first!
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
        guard event.modifierFlags.contains(.command),
              let chars = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }

        switch chars {
        case "v":
            viewModel?.handleClipboardAction()
            return true
        case "c":
            viewModel?.copyResult()
            return true
        case "a":
            return true
        case "z":
            return false
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
