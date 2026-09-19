import SwiftUI

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
    @AppStorage(CalculatorTheme.userDefaultsKey) private var isDarkTheme = false

    var body: some View {
        CalculatorView(viewModel: viewModel, showHistory: $showHistory, isDarkTheme: $isDarkTheme)
            .environment(\.calculatorTheme, CalculatorTheme(isDark: isDarkTheme))
            .background(
                KeyHandlerView(viewModel: viewModel)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            )
            .background(VisualEffectBackground(isTranslucent: isDarkTheme).ignoresSafeArea())
            .preferredColorScheme(isDarkTheme ? .dark : .light)
    }
}
