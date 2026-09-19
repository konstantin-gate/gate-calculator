import SwiftUI
import AppKit

// MARK: - Podklad okna (matné sklo)

/// Průhledný podklad okna pro tmavé téma.
/// V tmavém tématu zobrazuje materiál `.underWindowBackground` s rozostřením
/// obsahu za oknem; ve světlém tématu je skrytý a okno je neprůhledné.
struct VisualEffectBackground: NSViewRepresentable {

    /// `true` — tmavé téma (průhledné okno), `false` — světlé téma (neprůhledné okno).
    let isTranslucent: Bool

    func makeNSView(context: Context) -> VisualEffectBackgroundNSView {
        let view = VisualEffectBackgroundNSView()
        view.setTranslucent(isTranslucent)
        return view
    }

    func updateNSView(_ nsView: VisualEffectBackgroundNSView, context: Context) {
        nsView.setTranslucent(isTranslucent)
    }
}

// MARK: - NSView podkladu

@MainActor
final class VisualEffectBackgroundNSView: NSVisualEffectView {

    private var isTranslucent = false
    private var appliedTranslucency: Bool?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyToWindow()
    }

    /// Nastaví režim podkladu a okna.
    func setTranslucent(_ translucent: Bool) {
        if appliedTranslucency != translucent {
            appliedTranslucency = translucent
            isTranslucent = translucent
            isHidden = !translucent
            if translucent {
                material = .underWindowBackground
                blendingMode = .behindWindow
                state = .followsWindowActiveState
            }
        }
        applyToWindow()
    }

    /// Aplikuje průhlednost na okno včetně záhlaví (skleněný pruh s tlačítky).
    private func applyToWindow() {
        guard let window else { return }
        // Obsah roztahujeme pod záhlaví vždy, aby sklo mohlo pokrýt i horní pruh;
        // v tmavém tématu je záhlaví průhledné, ve světlém si drží standardní vzhled.
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.titlebarAppearsTransparent = isTranslucent
        let shouldBeOpaque = !isTranslucent
        guard window.isOpaque != shouldBeOpaque else { return }
        window.isOpaque = shouldBeOpaque
        window.backgroundColor = isTranslucent ? .clear : .windowBackgroundColor
        window.invalidateShadow()
    }
}
