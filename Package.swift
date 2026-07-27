// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Calculator",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "CalculatorEngine",
            targets: ["CalculatorEngine"]
        ),
        .executable(
            name: "CalculatorApp",
            targets: ["CalculatorApp"]
        ),
        .executable(
            name: "TestRunner",
            targets: ["TestRunner"]
        ),
    ],
    targets: [
        .target(
            name: "CalculatorEngine",
            path: "Sources/CalculatorEngine"
        ),
        .executableTarget(
            name: "CalculatorApp",
            dependencies: ["CalculatorEngine"],
            path: "Sources",
            exclude: [
                "CalculatorEngine",
                "TestRunner"
            ],
            sources: [
                "App",
                "Views",
                "ViewModels",
                "Services",
                "History",
                "Clipboard",
                "Formatting",
                "Theme"
            ],
            resources: [
                .process("Localization"),
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: ["CalculatorEngine"],
            path: "Sources/TestRunner"
        ),
        .testTarget(
            name: "CalculatorTests",
            dependencies: ["CalculatorEngine", "CalculatorApp"],
            path: "Tests/Unit"
        ),
        .testTarget(
            name: "CalculatorUITests",
            dependencies: ["CalculatorApp"],
            path: "Tests/UI"
        ),
    ]
)
