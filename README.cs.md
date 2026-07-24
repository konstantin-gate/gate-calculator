<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="GateCalc — Natívní kalkulačka pro macOS na Swift 6.0 a SwiftUI s přesnými výpočty až do 38 platných číslic">
</p>

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange?style=flat-square" alt="Swift 6.0"></a>
  <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14.0%2B-lightgray?style=flat-square" alt="macOS 14.0+"></a>
  <a href="https://www.swift.org/package-manager/"><img src="https://img.shields.io/badge/SPM-ready-green!style=flat-square" alt="Swift Package Manager"></a>
</p>

<p align="center">
  <a href="README.md" title="English version"><img src="https://img.shields.io/badge/en-English-blue?style=flat-square" alt="English version"></a>
  <a href="README.ru.md" title="Russian version"><img src="https://img.shields.io/badge/ru-%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9-red?style=flat-square" alt="Ruská verze"></a>
</p>

## Co je to

Natívní kalkulačka pro macOS inspirovaná aplikací Calculator.app z macOS Tahoe, postavená na Swift 6.0 a SwiftUI s architekturou MVVM — výpočetní engine je oddělen od UI a plně vláknově bezpečný (`Sendable`).

## Proč ne obyčejná kalkulačka

| Vlastnost | GateCalc | Obyčejné kalkulačky |
|---|---|---|
| Přesnost | Decimal (128-bit, až do 38 platných číslic) | Double / Float (64-bit, ~15 číslic) |
| Relativní % | `100 + 5%` = 105 | Pouze absolutní: `100 × 5%` = 5 |
| Číselné soustavy | HEX (`0xFF`), BIN (`0b1010`), OCT (`0o77`) | Pouze desítková |
| Historie výpočtů | Až do 50 záznamů, obnovení na displej | Žádná |
| Paměť | MC / M+ / M− / MR s indikátory | Některé (ne vždy) |

## Funkce

### Základní aritmetika

Sčítání, odčítání, násobení a dělení s přesnými výpočty (typ `Decimal`, až do 38 platných číslic). Podpora priorit operátorů a vnořených závorek:

```
(15 + 25) × (3 − 1) = 80
((10 / 2) + 3) × 4 = 32
```

### Procenta

Podpora absolutního i relativního procenta:

- `100 × 5%` = **5** (absolutní)
- `100 + 5%` = **105** (relativní — jako ve Windows Calculator)

### Funkční tlačítka

- **Odmocnina (√)** — odmocnina nezáporných čísel
- **Umocnění na druhou (x²)** — přesný výpočet přes Decimal

### Formáty čísel

| Soustava | Příklady |
|---|---|
| Šestnáctková | `0xFF`, `0XAB` |
| Dvojková | `0b1010` |
| Osmičková | `0o77` |
| Exponenciální zápis | `1.5e3`, `1.5e−2` |
| Oddělovače tisíců | mezery (`37 878`) a čárky (`1,000,000`) |

### Závorky

Plná podpora kulatých závorek pro řízení pořadí výpočtů, včetně vnořených:

```
(2 + 3) × (4 − 1) = 15
((10 / 2) + 3) × 4 = 32
```

### Copy / Paste

- **Kopírovat výsledek** — tlačítko na panelu nebo ⌘C
- **Vložit výraz ze schránky** — tlačítko na panelu nebo ⌘V; vložený výraz je automaticky vypočítán

### Paměť

Operace MC, M+, M−, MR pro ukládání a obnovování mezihodnot.

### Historie výpočtů

Všechny úspěšné výpočty jsou uloženy v historii (až do 50 záznamů). Každý záznam lze obnovit — výraz a výsledek se vrátí zpět na displej.

## Klávesové zkratky

| Klávesa | Akce |
|---|---|
| `Escape` | Úplné smazání (AC) |
| `Backspace` | Smazat poslední znak |
| `Return` / `Enter` | Vypočítat (=) |
| Číslice, operátory `+`, `-`, `*`, `/`, závorky, `%` | Vstup z klávesnice |
| ⌘C | Kopírovat výsledek |
| ⌘V | Vložit ze schránky |

## Architektura

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

- **Views** — komponenty SwiftUI (displej, tlačítka, historie)
- **ViewModel** (`@MainActor @Observable`) — stav aplikace, vstup/výpočet/paměť
- **CalculatorEngine** (`Sendable`) — vláknově bezpečný engine: Tokenizer → Parser (Shunting Yard) → Evaluator

## Budování

Projekt používá Swift Package Manager. Pro build spusťte:

```bash
swift build
```

Pro spuštění konzolového testeru výpočetního enginu:

```bash
swift run CalculatorApp
```

## Struktura projektu

```
Sources/
├── App/                    — Vstupní bod, obsluha klávesnice
├── Views/                  — Komponenty UI (displej, tlačítka, historie)
├── ViewModels/             — Logika aplikace (vstup, výpočet, paměť)
├── Services/               — Služby (historie)
├── CalculatorEngine/       — Výpočetní engine (tokenizátor, parser, evaluator)
│   ├── Tokenizer/          — Tokenizátor (Tokenizer, Token, BinaryOperator)
│   ├── Parser/             — Parser (Parser, Precedence)
│   ├── AST/                — AST (ExpressionNode)
│   ├── Evaluator/          — Evaluátor
│   └── Errors/             — Chyby (CalculatorError)
├── Clipboard/              — Schránka
├── Formatting/             — Formátování čísel
├── Theme/                  — Barevné schéma
├── History/                — Model záznamu historie
└── TestRunner/             — Konzolový tester (executable target)

Tests/
├── Unit/                   — Unit testy (CalculatorTests)
│   ├── EvaluatorTests.swift
│   ├── TokenizerTests.swift
│   ├── ParserTests.swift
│   ├── CalculatorEngineTests.swift
│   ├── CalculatorViewModelTests.swift
│   ├── HistoryServiceTests.swift
│   └── NumberFormatterServiceTests.swift
└── UI/                     — UI testy (CalculatorUITests, vyžadují Xcode)
    └── CalculatorUITests.swift
```

## Licence

© 2026 GateCalc. Všechna práva vyhrazena.
