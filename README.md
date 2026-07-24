<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="GateCalc — Native macOS Calculator on Swift 6.0 and SwiftUI with exact calculations up to 38 significant digits">
</p>

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange?style=flat-square" alt="Swift 6.0"></a>
  <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14.0%2B-lightgray?style=flat-square" alt="macOS 14.0+"></a>
  <a href="https://www.swift.org/package-manager/"><img src="https://img.shields.io/badge/SPM-ready-green!style=flat-square" alt="Swift Package Manager"></a>
</p>

<p align="center">
  <a href="README.ru.md" title="Russian version"><img src="https://img.shields.io/badge/ru-%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9-red?style=flat-square" alt="Русская версия"></a>
  <a href="README.cs.md" title="Czech version"><img src="https://img.shields.io/badge/cs-Čeština-yellow?style=flat-square" alt="Czech version"></a>
</p>

## What it is

A native macOS calculator inspired by Calculator.app from macOS Tahoe, built with Swift 6.0 and SwiftUI using the MVVM architecture — the calculation engine is separated from the UI and fully thread-safe (`Sendable`).

## Why not just another calculator

| Feature | GateCalc | Regular calculators |
|---|---|---|
| Accuracy | Decimal (128-bit, up to 38 significant digits) | Double / Float (64-bit, ~15 digits) |
| Relative % | `100 + 5%` = 105 | Only absolute: `100 × 5%` = 5 |
| Number systems | HEX (`0xFF`), BIN (`0b1010`), OCT (`0o77`) | Decimal only |
| Calculation history | Up to 50 entries, restore to display | None |
| Memory | MC / M+ / M− / MR with indicators | Some (not always) |

## Features

### Basic arithmetic

Addition, subtraction, multiplication and division with exact calculations (`Decimal` type, up to 38 significant digits). Support for operator precedence and nested parentheses:

```
(15 + 25) × (3 − 1) = 80
((10 / 2) + 3) × 4 = 32
```

### Percentages

Support for both absolute and relative percentages:

- `100 × 5%` = **5** (absolute)
- `100 + 5%` = **105** (relative — like in Windows Calculator)

### Function buttons

- **Square root (√)** — square root of non-negative numbers
- **Square (x²)** — exact calculation via Decimal

### Number formats

| System | Examples |
|---|---|
| Hexadecimal | `0xFF`, `0XAB` |
| Binary | `0b1010` |
| Octal | `0o77` |
| Exponential notation | `1.5e3`, `1.5e−2` |
| Thousands separators | spaces (`37 878`) and commas (`1,000,000`) |

### Parentheses

Full support for parentheses to control calculation order, including nested ones:

```
(2 + 3) × (4 − 1) = 15
((10 / 2) + 3) × 4 = 32
```

### Copy / Paste

- **Copy result** — button on the panel or ⌘C
- **Paste expression from clipboard** — button on the panel or ⌘V; pasted expression is automatically calculated

### Memory

MC, M+, M−, MR operations for saving and restoring intermediate values.

### Calculation history

All successful calculations are saved in the history (up to 50 entries). Each entry can be restored — expression and result are placed back on the display.

## Keyboard shortcuts

| Key | Action |
|---|---|
| `Escape` | Full clear (AC) |
| `Backspace` | Delete last character |
| `Return` / `Enter` | Calculate (=) |
| Digits, operators `+`, `-`, `*`, `/`, parentheses, `%` | Keyboard input |
| ⌘C | Copy result |
| ⌘V | Paste from clipboard |

## Architecture

```
┌─────────────┐    ┌───────────────┐    ┌──────────────┐
│   SwiftUI    │◄──►│  ViewModel    │◄──►│ Calculator   │
│   Views      │    │ @Observable   │    │  Engine      │
│              │    │               │    │ Sendable     │
└─────────────┘    └───────────────┘    └──────────────┘
                           ▲                    ▲
                           │                    │
                    ┌──────┴──────┐      ┌───────┴───────┐
                    │  Services   │      │ Tokenizer     │
                    │ History     │      │ Parser        │
                    │ Clipboard   │      │ Evaluator     │
                    └─────────────┘      └───────────────┘
```

- **Views** — SwiftUI components (display, buttons, history)
- **ViewModel** (`@MainActor @Observable`) — app state, input/calculation/memory
- **CalculatorEngine** (`Sendable`) — thread-safe engine: Tokenizer → Parser (Shunting Yard) → Evaluator

## Building

The project uses Swift Package Manager. To build, run:

```bash
swift build
```

To run the console tester for the calculation engine:

```bash
swift run CalculatorApp
```

## Project structure

```
Sources/
├── App/                    — Entry point, keyboard handler
├── Views/                  — UI components (display, buttons, history)
├── ViewModels/             — App logic (input, calculation, memory)
├── Services/               — Services (history)
├── CalculatorEngine/       — Calculator engine (tokenizer, parser, evaluator)
│   ├── Tokenizer/          — Tokenizer (Tokenizer, Token, BinaryOperator)
│   ├── Parser/             — Parser (Parser, Precedence)
│   ├── AST/                — AST (ExpressionNode)
│   ├── Evaluator/          — Evaluator
│   └── Errors/             — Errors (CalculatorError)
├── Clipboard/              — Clipboard
├── Formatting/             — Number formatting
├── Theme/                  — Color scheme
├── History/                — History entry model
└── TestRunner/             — Console tester (executable target)

Tests/
├── Unit/                   — Unit tests (CalculatorTests)
│   ├── EvaluatorTests.swift
│   ├── TokenizerTests.swift
│   ├── ParserTests.swift
│   ├── CalculatorEngineTests.swift
│   ├── CalculatorViewModelTests.swift
│   ├── HistoryServiceTests.swift
│   └── NumberFormatterServiceTests.swift
└── UI/                     — UI tests (CalculatorUITests, require Xcode)
    └── CalculatorUITests.swift
```

## License

© 2026 GateCalc. All rights reserved.
