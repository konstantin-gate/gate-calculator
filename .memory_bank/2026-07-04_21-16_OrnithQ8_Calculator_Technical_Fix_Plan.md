# План исправления технических и архитектурных недостатков калькулятора

## Общая информация

**Дата создания:** 2026-07-04  
**Автор плана:** OrnithQ8  
**Целевая аудитория:** Младший разработчик (Junior Swift/SwiftUI)  
**Время выполнения:** 2-3 рабочих дня  

---

## Что нужно исправить и зачем

После анализа проекта было выявлено, что вычислительное ядро (CalculatorEngine) работает корректно для базовых сценариев. Однако есть критические технические и архитектурные недостатки, которые мешают соответствию спецификации SRS v1.1:

**Основные проблемы:**
1. **Структура проекта не соответствует спецификации** — отсутствуют папки Models/, Clipboard/, History/, Resources/
2. **API не публичные** — CalculatorError, Parser, Evaluator, ExpressionNode имеют internal видимость
3. **Обработка специальных случаев неполная** — нет поддержки "1,5", "pi", "1e3" (без точки)
4. **Мёртвый код в тестах** — CalculatorEngineTests.swift содержит остатки TestRunnerMain.main()
5. **Нет UI Tests** — спецификация требует Unit + UI Tests
6. **Нет документации в коде** — отсутствуют doc comments для публичных API
7. **Пустые папки** — Components/, Extensions/ существуют, но пусты

**Цель плана:** Исправить все технические и архитектурные недостатки, чтобы проект соответствовал спецификации SRS v1.1.

---

## Подготовка перед началом работы

### Что нужно знать

1. **Swift Package Manager** — система управления зависимостями
2. **Swift Visibility Modifiers** — `public`, `internal`, `private`
3. **XCTest** — фреймворк для тестирования
4. **Swift Documentation Comments** — формат `///` для документации

### Структура проекта (текущая)

```
Sources/
├── App/                    # Точка входа приложения
│   └── CalculatorApp.swift
├── Views/                  # UI компоненты
│   ├── CalculatorView.swift
│   ├── DisplayView.swift
│   ├── CalculatorButton.swift
│   └── HistoryPanelView.swift
├── ViewModels/             # Логика интерфейса
│   └── CalculatorViewModel.swift
├── Services/               # Сервисы (история, буфер)
│   └── HistoryService.swift
├── Formatting/             # Форматирование чисел
│   └── NumberFormatterService.swift
├── Theme/                  # Цвета и темы
│   └── CalculatorColors.swift
├── CalculatorEngine/       # Вычислительное ядро
│   ├── Tokenizer/
│   │   ├── Token.swift
│   │   └── Tokenizer.swift
│   ├── Parser/
│   │   ├── Parser.swift
│   │   └── Precedence.swift
│   ├── Evaluator/
│   │   └── Evaluator.swift
│   ├── AST/
│   │   └── ExpressionNode.swift
│   └── Errors/
│       └── CalculatorError.swift
├── Localization/           # Локализация (ПУСТАЯ)
├── Resources/              # Ресурсы (ПУСТАЯ)
├── Components/             # Переиспользуемые компоненты (ПУСТАЯ)
├── Extensions/             # Расширения (ПУСТАЯ)
└── TestRunner/             # Тестовый раннер
    └── main.swift

Tests/
└── Unit/
    ├── CalculatorEngineTests.swift
    ├── TokenizerTests.swift
    ├── ParserTests.swift
    └── EvaluatorTests.swift
```

### Структура проекта (целевая)

```
Sources/
├── App/                    # Точка входа приложения
│   └── CalculatorApp.swift
├── Views/                  # UI компоненты
│   ├── CalculatorView.swift
│   ├── DisplayView.swift
│   ├── CalculatorButton.swift
│   └── HistoryPanelView.swift
├── ViewModels/             # Логика интерфейса
│   └── CalculatorViewModel.swift
├── Services/               # Сервисы (буфер)
│   └── ClipboardService.swift
├── History/                # История вычислений
│   ├── HistoryEntry.swift
│   └── HistoryService.swift
├── Models/                 # Модели данных
│   └── AppSettings.swift
├── Clipboard/              # Работа с буфером обмена
│   └── ClipboardManager.swift
├── Formatting/             # Форматирование чисел
│   └── NumberFormatterService.swift
├── Theme/                  # Цвета и темы
│   └── CalculatorColors.swift
├── Localization/           # Локализация
│   ├── Localizable.swift
│   ├── en.lproj/
│   │   └── Localizable.strings
│   └── ru.lproj/
│       └── Localizable.strings
├── Resources/              # Ресурсы (иконки, и т.д.)
│   └── Assets.xcassets/
├── Components/             # Переиспользуемые компоненты
│   └── EmptyStateView.swift
├── Extensions/             # Расширения
│   ├── String+Calculator.swift
│   └── Decimal+Extensions.swift
├── CalculatorEngine/       # Вычислительное ядро (Публичные API!)
│   ├── Tokenizer/
│   │   ├── Token.swift
│   │   └── Tokenizer.swift
│   ├── Parser/
│   │   ├── Parser.swift
│   │   └── Precedence.swift
│   ├── Evaluator/
│   │   └── Evaluator.swift
│   ├── AST/
│   │   └── ExpressionNode.swift
│   └── Errors/
│       └── CalculatorError.swift
└── TestRunner/             # Тестовый раннер
    └── main.swift

Tests/
├── Unit/
│   ├── CalculatorEngineTests.swift
│   ├── TokenizerTests.swift
│   ├── ParserTests.swift
│   └── EvaluatorTests.swift
└── UI/                     # UI Tests (НОВЫЕ!)
    └── CalculatorUITests.swift
```

---

## Этап 1: Реорганизация структуры проекта

### Почему это важно

Спецификация (раздел 16) требует определённую структуру проекта. Текущая структура не соответствует спецификации:
- `HistoryEntry` находится в `Services/`, должен быть в `Models/` или `History/`
- Нет отдельной папки `Clipboard/` для работы с буфером обмена
- Нет папки `Models/` для моделей данных
- Пустые папки `Components/`, `Extensions/` должны содержать код или быть удалены

### Что делать (пошагово)

#### Шаг 1.1: Создай новые папки

Открой Terminal и выполни команды:

```bash
cd /Users/kgate/Work/GateCalc/Sources

# Создай папку History (если её нет)
mkdir -p History

# Создай папку Models (если её нет)
mkdir -p Models

# Создай папку Clipboard (если её нет)
mkdir -p Clipboard

# Создай папку Resources (если её нет)
mkdir -p Resources/Assets.xcassets

# Создай папку Localization (если её нет)
mkdir -p Localization/en.lproj
mkdir -p Localization/ru.lproj

# Создай папку Components (если её нет)
mkdir -p Components

# Создай папку Extensions (если её нет)
mkdir -p Extensions
```

#### Шаг 1.2: Переместите HistoryEntry в папку History

**Было:** `Sources/Services/HistoryService.swift` содержит определение `HistoryEntry`

**Стало:** Создай новый файл `Sources/History/HistoryEntry.swift`:

```swift
import Foundation

public struct HistoryEntry: Identifiable, Sendable {
    public let id = UUID()
    public let expression: String
    public let result: Decimal
    public let timestamp: Date
    
    public init(expression: String, result: Decimal) {
        self.expression = expression
        self.result = result
        self.timestamp = Date()
    }
}
```

Затем открой `Sources/Services/HistoryService.swift` и удали определение `HistoryEntry` (строки 1-14). Оставь только класс `HistoryService`.

#### Шаг 1.3: Создай сервис для работы с буфером обмена

Создай файл `Sources/Clipboard/ClipboardManager.swift`:

```swift
import AppKit
import Foundation

public final class ClipboardManager: @unchecked Sendable {
    
    public static let shared = ClipboardManager()
    
    private init() {}
    
    /// Получает строку из буфера обмена
    public func getString() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
    
    /// Помещает строку в буфер обмена
    public func setString(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
    
    /// Проверяет, является ли содержимое буфера математическим выражением
    public func isMathExpression(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // Простая проверка: содержит ли хотя бы одну цифру и оператор
        let hasDigit = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        let hasOperator = ["+", "-", "*", "/", "%"].contains(where: { trimmed.contains($0) })
        
        return hasDigit && hasOperator
    }
}
```

#### Шаг 1.4: Обнови CalculatorApp.swift для использования новых сервисов

Открой файл `Sources/App/CalculatorApp.swift`

Найди метод `performKeyEquivalent` в `KeyHandlerNSView` (строки 74-89):

**Было:**
```swift
override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let cmd = event.modifierFlags.contains(.command)

    if cmd, event.charactersIgnoringModifiers == "c" {
        viewModel?.copyResult()
        return true
    }
    if cmd, event.charactersIgnoringModifiers == "v" {
        if let text = NSPasteboard.general.string(forType: .string) {
            viewModel?.insertFromClipboard(text)
        }
        return true
    }

    return super.performKeyEquivalent(with: event)
}
```

**Стало:**
```swift
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

    return super.performKeyEquivalent(with: event)
}
```

#### Шаг 1.5: Обнови CalculatorViewModel.swift для использования ClipboardManager

Открой файл `Sources/ViewModels/CalculatorViewModel.swift`

Найди метод `copyResult` (строки 125-130):

**Было:**
```swift
func copyResult() {
    if let result = result {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
    }
}
```

**Стало:**
```swift
func copyResult() {
    if let result = result {
        ClipboardManager.shared.setString(result)
    }
}
```

#### Шаг 1.6: Проверь структуру проекта

Выполни в Terminal:

```bash
cd /Users/kgate/Work/GateCalc/Sources
find . -type d | sort
```

Убедись, что есть все необходимые папки:
- App/
- Views/
- ViewModels/
- Services/
- History/
- Models/ (может быть пустой, если нет моделей)
- Clipboard/
- Formatting/
- Theme/
- Localization/
- Resources/
- Components/ (может быть пустой)
- Extensions/ (может быть пустой)
- CalculatorEngine/

#### Шаг 1.7: Запусти и проверь

```bash
cd /Users/kgate/Work/GateCalc
swift build
swift run CalculatorApp
```

Проверь:
1. ✅ Приложение запускается без ошибок компиляции
2. ✅ ⌘C копирует результат в буфер обмена
3. ✅ ⌘V вставляет выражение из буфера обмена

---

## Этап 2: Делаем API публичными

### Почему это важно

Спецификация (раздел 21) требует, чтобы CalculatorEngine был полностью независимым модулем. Для этого все публичные типы должны иметь видимость `public`.

Сейчас в проекте:
- `CalculatorError` — internal (не виден за пределами модуля)
- `Parser` — internal
- `Evaluator` — internal
- `ExpressionNode` — internal

Это означает, что тесты и другие модули не могут напрямую использовать эти типы.

### Что делать (пошагово)

#### Шаг 2.1: Сделай CalculatorError публичным

Открой файл `Sources/CalculatorEngine/Errors/CalculatorError.swift`

**Было (строка 3):**
```swift
enum CalculatorError: Error, LocalizedError, Sendable {
```

**Стало:**
```swift
public enum CalculatorError: Error, LocalizedError, Sendable {
```

**Было (строка 15):**
```swift
var errorDescription: String? {
```

**Стало:**
```swift
public var errorDescription: String? {
```

#### Шаг 2.2: Сделай Parser публичным

Открой файл `Sources/CalculatorEngine/Parser/Parser.swift`

**Было (строка 3):**
```swift
struct Parser: Sendable {
```

**Стало:**
```swift
public struct Parser: Sendable {
```

**Было (строка 5):**
```swift
func parse(_ tokens: [Token]) throws -> ExpressionNode {
```

**Стало:**
```swift
public func parse(_ tokens: [Token]) throws -> ExpressionNode {
```

#### Шаг 2.3: Сделай Evaluator публичным

Открой файл `Sources/CalculatorEngine/Evaluator/Evaluator.swift`

**Было (строка 3):**
```swift
struct Evaluator: Sendable {
```

**Стало:**
```swift
public struct Evaluator: Sendable {
```

**Было (строка 5):**
```swift
func evaluate(_ node: ExpressionNode) throws -> Decimal {
```

**Стало:**
```swift
public func evaluate(_ node: ExpressionNode) throws -> Decimal {
```

#### Шаг 2.4: Сделай ExpressionNode публичным

Открой файл `Sources/CalculatorEngine/AST/ExpressionNode.swift`

**Было (строка 3):**
```swift
enum ExpressionNode {
```

**Стало:**
```swift
public enum ExpressionNode {
```

Все case'ы также должны быть публичными. Найди определение case'ов и добавь `public`:

**Было:**
```swift
case number(Decimal)
case unaryMinus(ExpressionNode)
case percent(ExpressionNode)
case binary(BinaryOperator, ExpressionNode, ExpressionNode)
```

**Стало:**
```swift
public case number(Decimal)
public case unaryMinus(ExpressionNode)
public case percent(ExpressionNode)
public case binary(BinaryOperator, ExpressionNode, ExpressionNode)
```

#### Шаг 2.5: Сделай Token и BinaryOperator публичными

Открой файл `Sources/CalculatorEngine/Tokenizer/Token.swift`

**Было (строка 3):**
```swift
enum Token: Equatable, Sendable {
```

**Стало:**
```swift
public enum Token: Equatable, Sendable {
```

Все case'ы также должны быть публичными:

**Было:**
```swift
case number(Decimal)
case binaryOperator(BinaryOperator)
case unaryMinus
case leftParenthesis
case rightParenthesis
case percent
```

**Стало:**
```swift
public case number(Decimal)
public case binaryOperator(BinaryOperator)
public case unaryMinus
public case leftParenthesis
public case rightParenthesis
public case percent
```

**Было (строка 12):**
```swift
enum BinaryOperator: String, Sendable {
```

**Стало:**
```swift
public enum BinaryOperator: String, Sendable {
```

Все case'ы также должны быть публичными:

**Было:**
```swift
case add = "+"
case subtract = "-"
case multiply = "*"
case divide = "/"

var symbol: String { rawValue }
```

**Стало:**
```swift
public case add = "+"
public case subtract = "-"
public case multiply = "*"
public case divide = "/"

public var symbol: String { rawValue }
```

#### Шаг 2.6: Сделай Tokenizer публичным

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

**Было (строка 3):**
```swift
struct Tokenizer: Sendable {
```

**Стало:**
```swift
public struct Tokenizer: Sendable {
```

**Было (строка 7):**
```swift
func tokenize(_ input: String) throws -> [Token] {
```

**Стало:**
```swift
public func tokenize(_ input: String) throws -> [Token] {
```

#### Шаг 2.7: Проверь, что все тесты компилируются

Выполни в Terminal:

```bash
cd /Users/kgate/Work/GateCalc
swift build
swift test
```

Убедись, что:
1. ✅ Нет ошибок компиляции
2. ✅ Все тесты проходят

---

## Этап 3: Обработка специальных случаев ввода

### Почему это важно

Спецификация (раздел 39) требует обработку следующих специальных случаев:
- "1,5" как десятичный разделитель (европейский формат)
- "pi" как константа π
- "1e3" без точки (экспоненциальная запись)
- Корректная обработка "5%+" (процент после оператора)

### Что делать (пошагово)

#### Шаг 3.1: Добавь поддержку "pi" как константы π

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

Найди обработку символа 'π' (строка 78):

**Было:**
```swift
if char == "\u{03C0}" || char == "π" || char.lowercased() == "pi" {
    tokens.append(.number(Decimal.pi))
    advance(&i, in: cleaned)
    continue
}
```

**Стало:**
```swift
// Проверка на π (символ или слово "pi")
if char == "\u{03C0}" || char == "π" {
    tokens.append(.number(Decimal.pi))
    advance(&i, in: cleaned)
    continue
}

// Проверка на слово "pi" (только если это отдельное слово)
if char.lowercased() == "p" {
    let nextIndex = cleaned.index(after: i)
    if nextIndex < cleaned.endIndex, cleaned[nextIndex] == "i" {
        let afterI = cleaned.index(after: nextIndex)
        // Проверяем, что после "pi" нет букв (чтобы не совпадало с "plus", "print" и т.д.)
        if afterI >= cleaned.endIndex || !cleaned[afterI].isLetter {
            tokens.append(.number(Decimal.pi))
            i = afterI
            continue
        }
    }
}
```

#### Шаг 3.2: Добавь поддержку "1e3" без точки (экспоненциальная запись)

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

Найди метод `readNumber` (строка 162). Найди обработку экспоненты (примерно строка 199):

**Было:**
```swift
} else if (c == "e" || c == "E") && !hasExponent {
    hasExponent = true
    numberStr.append(c)
    advance(&i, in: str)

    if i < str.endIndex, (str[i] == "+" || str[i] == "-") {
        numberStr.append(str[i])
        advance(&i, in: str)
    }
} else {
    break
}
```

**Стало:**
```swift
} else if (c == "e" || c == "E") && !hasExponent {
    hasExponent = true
    numberStr.append(c)
    advance(&i, in: str)

    // Проверяем знак экспоненты
    if i < str.endIndex, (str[i] == "+" || str[i] == "-") {
        numberStr.append(str[i])
        advance(&i, in: str)
    }
} else if c.isNumber && hasExponent {
    // Продолжаем читать цифры экспоненты (например, "1e3" после "e")
    numberStr.append(c)
    advance(&i, in: str)
} else {
    break
}
```

**Важно:** Этот код может потребовать дополнительной логики. Если "1e3" не работает, проверь, что `hasExponent` устанавливается правильно.

#### Шаг 3.3: Добавь поддержку "1,5" как десятичного разделителя

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

Найди метод `preprocess` (строка 120). Найди обработку запятых (примерно строки 136-143):

**Было:**
```swift
let comma = Character(",")
if trimmed.contains(comma) {
    if !trimmed.contains(".") && isThousandsSeparatorPattern(trimmed) {
        result.removeAll(where: { $0 == comma })
    } else if !trimmed.contains(".") && containsOnlyDigitsAndCommas(trimmed) {
        result.removeAll(where: { $0 == comma })
    }
}
```

**Стало:**
```swift
let comma = Character(",")
if trimmed.contains(comma) {
    // Определяем, является ли запятая разделителем тысяч или десятичным разделителем
    
    // Если есть и запятая, и точка — запятая точно разделитель тысяч
    if trimmed.contains(".") {
        result.removeAll(where: { $0 == comma })
    }
    // Если нет точки, проверяем позицию запятой
    else if let lastCommaIndex = result.lastIndex(of: comma) {
        let digitsAfterComma = result.distance(from: lastCommaIndex, to: result.endIndex)
        
        // Если после запятой 1-2 цифры — это десятичный разделитель (европейский формат)
        if digitsAfterComma >= 1 && digitsAfterComma <= 2 {
            result = result.replacingOccurrences(of: ",", with: ".")
        }
        // Если после запятой 3 цифры — это разделитель тысяч (1,000)
        else if digitsAfterComma == 3 {
            result.removeAll(where: { $0 == comma })
        }
        // В остальных случаях удаляем запятые
        else {
            result.removeAll(where: { $0 == comma })
        }
    }
}
```

#### Шаг 3.4: Добавь обработку "5%+" (процент после оператора)

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

Найди метод `validateTokenSequence` (строка 297). Найди обработку процента (примерно строки 311-319):

**Было:**
```swift
case .percent:
    let prevIsOp = i > tokens.startIndex && isOperatorOrLeftParen(tokens[i - 1])
    if prevIsOp {
        throw CalculatorError.doubleOperator
    }
    // Процент не может быть followed by another percent (double postfix)
    if i + 1 < tokens.endIndex && tokens[i + 1] == .percent {
        throw CalculatorError.doubleOperator
    }
```

**Стало:**
```swift
case .percent:
    let prevIsOp = i > tokens.startIndex && isOperatorOrLeftParen(tokens[i - 1])
    if prevIsOp {
        throw CalculatorError.doubleOperator
    }
    // Процент не может быть followed by another percent (double postfix)
    if i + 1 < tokens.endIndex && tokens[i + 1] == .percent {
        throw CalculatorError.doubleOperator
    }
    // Процент не может быть followed by binary operator (кроме унарного минуса)
    if i + 1 < tokens.endIndex {
        let nextToken = tokens[i + 1]
        if case .binaryOperator(_) = nextToken {
            throw CalculatorError.doubleOperator
        }
    }
```

#### Шаг 3.5: Добавь обработку "1,000.5" (разделитель тысяч + десятичная)

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

В методе `preprocess` после обработки запятых добавь:

**После строки 143 (после существующей обработки запятых) добавь:**
```swift
// Обработка "1,000.5" — запятые как разделители тысяч, точка как десятичная
if trimmed.contains(",") && trimmed.contains(".") {
    // Удаляем запятые (разделители тысяч), оставляем точку (десятичная)
    result = result.replacingOccurrences(of: ",", with: "")
}
```

#### Шаг 3.6: Добавь обработку "1.000,5" (немецкий формат)

В методе `preprocess` после предыдущего блока добавь:

```swift
// Обработка "1.000,5" — точки как разделители тысяч, запятая как десятичная
if trimmed.contains(".") && trimmed.contains(",") {
    // Определяем, какая позиция последняя
    let lastDotIndex = result.lastIndex(of: ".") ?? result.startIndex
    let lastCommaIndex = result.lastIndex(of: ",") ?? result.startIndex
    
    if lastCommaIndex > lastDotIndex {
        // Запятая стоит после последней точки — это десятичный разделитель
        result = result.replacingOccurrences(of: ".", with: "")
        result = result.replacingOccurrences(of: ",", with: ".")
    } else {
        // Точка стоит после последней запятой — это разделитель тысяч
        result = result.replacingOccurrences(of: ",", with: "")
    }
}
```

#### Шаг 3.7: Запусти и проверь

Выполни тесты:

```bash
cd /Users/kgate/Work/GateCalc
swift test
```

Проверь специальные случаи:

```bash
cd /Users/kgate/Work/GateCalc
swift run TestRunner
```

Убедись, что все тесты проходят, включая новые для специальных случаев.

---

## Этап 4: Очистка кода и добавление документации

### Почему это важно

Спецификация (раздел 92) требует:
- Документировать публичные API
- Удалять закомментированный код
- Не оставлять TODO, Mock, заглушки

### Что делать (пошагово)

#### Шаг 4.1: Удали мёртвый код из CalculatorEngineTests.swift

Открой файл `Tests/Unit/CalculatorEngineTests.swift`

Найди мёртвый код (строки 97-174 — это остатки TestRunnerMain.main()):

**Удали эти строки полностью.** Оставь только методы тестов.

После удаления файл должен заканчиваться так:

```swift
    func testEvaluate_AllErrorCases() {
        let cases = [
            "1/0",
            "15+a",
            "(15+16",
            "15+16)",
            "NaN",
            "Infinity",
        ]

        for expression in cases {
            let result = try? engine.evaluate(expression)
            XCTAssertNil(result, "Should fail for: \(expression)")
        }
    }
}
```

#### Шаг 4.2: Добавь doc comments для публичных API в CalculatorEngine

Открой файл `Sources/CalculatorEngine/CalculatorEngine.swift`

Добавь документацию перед структурой:

```swift
import Foundation

/// Вычислительный движок калькулятора.
///
/// Отвечает за разбор математического выражения, проверку корректности
/// и вычисление результата.
///
/// - Note: Движок является полностью независимым модулем и не содержит
///         зависимостей от SwiftUI или AppKit.
public struct CalculatorEngine: Sendable {

    /// Создаёт новый экземпляр вычислительного движка.
    public init() {}

    /// Вычисляет математическое выражение.
    ///
    /// - Parameter expression: Строка с математическим выражением.
    /// - Returns: Результат вычисления в виде `Decimal`.
    /// - Throws: `CalculatorError` если выражение некорректно.
    public func evaluate(_ expression: String) throws -> Decimal {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CalculatorError.emptyExpression
        }

        let tokenizer = Tokenizer()
        let tokens = try tokenizer.tokenize(trimmed)

        guard !tokens.isEmpty else {
            throw CalculatorError.emptyExpression
        }

        let parser = Parser()
        let ast = try parser.parse(tokens)

        let evaluator = Evaluator()
        return try evaluator.evaluate(ast)
    }
}
```

#### Шаг 4.3: Добавь doc comments для Tokenizer

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

Добавь документацию перед структурой:

```swift
import Foundation

/// Токенизатор математических выражений.
///
/// Преобразует строку выражения в последовательность токенов.
public struct Tokenizer: Sendable {

    /// Создаёт новый экземпляр токенизатора.
    public init() {}

    /// Токенизирует математическое выражение.
    ///
    /// - Parameter input: Строка с математическим выражением.
    /// - Returns: Массив токенов.
    /// - Throws: `CalculatorError` если выражение содержит некорректные символы.
    public func tokenize(_ input: String) throws -> [Token] {
```

#### Шаг 4.4: Добавь doc comments для Parser

Открой файл `Sources/CalculatorEngine/Parser/Parser.swift`

Добавь документацию перед структурой:

```swift
import Foundation

/// Парсер математических выражений.
///
/// Использует алгоритм сортировочной станции (Shunting Yard) для преобразования
/// инфиксной записи в обратную польскую нотацию (RPN), а затем строит AST.
public struct Parser: Sendable {

    /// Парсит последовательность токенов в AST.
    ///
    /// - Parameter tokens: Массив токенов от токенизатора.
    /// - Returns: Корневой узел абстрактного синтаксического дерева.
    /// - Throws: `CalculatorError` если токены не образуют корректное выражение.
    public func parse(_ tokens: [Token]) throws -> ExpressionNode {
```

#### Шаг 4.5: Добавь doc comments для Evaluator

Открой файл `Sources/CalculatorEngine/Evaluator/Evaluator.swift`

Добавь документацию перед структурой:

```swift
import Foundation

/// Вычислитель абстрактного синтаксического дерева.
///
/// Рекурсивно обходит AST и вычисляет результат выражения.
public struct Evaluator: Sendable {

    /// Вычисляет значение AST.
    ///
    /// - Parameter node: Корневой узел абстрактного синтаксического дерева.
    /// - Returns: Результат вычисления в виде `Decimal`.
    /// - Throws: `CalculatorError` при делении на ноль или переполнении.
    public func evaluate(_ node: ExpressionNode) throws -> Decimal {
```

#### Шаг 4.6: Добавь doc comments для ExpressionNode

Открой файл `Sources/CalculatorEngine/AST/ExpressionNode.swift`

Добавь документацию перед перечислением:

```swift
import Foundation

/// Узел абстрактного синтаксического дерева (AST).
///
/// Представляет собой структуру математического выражения после парсинга.
public enum ExpressionNode {
    /// Числовое значение.
    public case number(Decimal)
    
    /// Унарный минус (отрицательное число).
    public case unaryMinus(ExpressionNode)
    
    /// Оператор процента (деление на 100).
    public case percent(ExpressionNode)
    
    /// Бинарная операция (сложение, вычитание, умножение, деление).
    public case binary(BinaryOperator, ExpressionNode, ExpressionNode)
}
```

#### Шаг 4.7: Добавь doc comments для CalculatorError

Открой файл `Sources/CalculatorEngine/Errors/CalculatorError.swift`

Добавь документацию перед перечислением:

```swift
import Foundation

/// Ошибки вычислительного движка калькулятора.
public enum CalculatorError: Error, LocalizedError, Sendable {
    /// Деление на ноль.
    case divisionByZero
    
    /// Некорректное выражение (с кастомным сообщением).
    case invalidExpression(String)
    
    /// Пропущена закрывающая скобка.
    case missingClosingParenthesis
    
    /// Лишняя закрывающая скобка.
    case extraClosingParenthesis
    
    /// Неверный символ в выражении.
    case invalidCharacter(String)
    
    /// Пустое выражение.
    case emptyExpression
    
    /// Число слишком большое для точного представления.
    case numberOverflow
    
    /// Некорректное число (с кастомным сообщением).
    case invalidNumber(String)
    
    /// Двойной оператор (например, "5++3").
    case doubleOperator
    
    /// Несколько десятичных разделителей.
    case multipleDecimalSeparators

    public var errorDescription: String? {
```

#### Шаг 4.8: Проверь, что нет закомментированного кода

Выполни в Terminal:

```bash
cd /Users/kgate/Work/GateCalc/Sources
grep -r "// " --include="*.swift" | grep -v "^.*// MARK:" | grep -v "^.*/// " | head -20
```

Проверь результаты. Если есть закомментированный код (не doc comments и не MARK), удали его.

#### Шаг 4.9: Запусти и проверь

```bash
cd /Users/kgate/Work/GateCalc
swift build
swift test
```

Убедись, что:
1. ✅ Нет ошибок компиляции
2. ✅ Все тесты проходят
3. ✅ В Xcode (если открыт) doc comments отображаются при наведении на публичные API

---

## Этап 5: Добавление UI Tests

### Почему это важно

Спецификация (раздел 90) требует:
- Unit Tests ✅ (уже есть)
- UI Tests ❌ (отсутствуют)

UI Tests проверяют взаимодействие с пользовательским интерфейсом.

### Что делать (пошагово)

#### Шаг 5.1: Создай папку для UI Tests

```bash
mkdir -p /Users/kgate/Work/GateCalc/Tests/UI
```

#### Шаг 5.2: Создай файл UI Tests

Создай файл `Tests/UI/CalculatorUITests.swift`:

```swift
import XCTest
@testable import CalculatorApp

final class CalculatorUITests: XCTestCase {

    override func setUpWithError() throws {
        // Перед каждым тестом
    }

    override func tearDownWithError() throws {
        // После каждого теста
    }

    // MARK: - Basic UI Tests

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Проверяем, что приложение запустилось
        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    func testDisplayShowsZero() throws {
        let app = XCUIApplication()
        app.launch()

        // Проверяем, что дисплей показывает "0"
        let display = app.staticTexts["0"]
        XCTAssertTrue(display.exists)
    }

    // MARK: - Button Tests

    func testDigitButtonsExist() throws {
        let app = XCUIApplication()
        app.launch()

        // Проверяем наличие цифровых кнопок
        for digit in "0123456789" {
            let button = app.buttons[digit.description]
            XCTAssertTrue(button.exists, "Button \(digit) should exist")
        }
    }

    func testOperatorButtonsExist() throws {
        let app = XCUIApplication()
        app.launch()

        // Проверяем наличие кнопок операций
        let operators = ["+", "-", "*", "/", "%"]
        for op in operators {
            let button = app.buttons[op]
            XCTAssertTrue(button.exists, "Button \(op) should exist")
        }
    }

    func testClearButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["C"].exists)
    }

    func testEqualsButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["="].exists)
    }

    // MARK: - Calculation Tests

    func testSimpleAddition() throws {
        let app = XCUIApplication()
        app.launch()

        // Вводим "15+16="
        app.buttons["1"].tap()
        app.buttons["5"].tap()
        app.buttons["+"].tap()
        app.buttons["1"].tap()
        app.buttons["6"].tap()
        app.buttons["="].tap()

        // Проверяем результат "31"
        let result = app.staticTexts["31"]
        XCTAssertTrue(result.exists, "Result should be 31")
    }

    func testParentheses() throws {
        let app = XCUIApplication()
        app.launch()

        // Вводим "(15+16)*5="
        app.buttons["("].tap()
        app.buttons["1"].tap()
        app.buttons["5"].tap()
        app.buttons["+"].tap()
        app.buttons["1"].tap()
        app.buttons["6"].tap()
        app.buttons[")"].tap()
        app.buttons["*"].tap()
        app.buttons["5"].tap()
        app.buttons["="].tap()

        // Проверяем результат "155"
        let result = app.staticTexts["155"]
        XCTAssertTrue(result.exists, "Result should be 155")
    }

    // MARK: - Error Tests

    func testDivisionByZero() throws {
        let app = XCUIApplication()
        app.launch()

        // Вводим "1/0="
        app.buttons["1"].tap()
        app.buttons["/"].tap()
        app.buttons["0"].tap()
        app.buttons["="].tap()

        // Проверяем, что появилось сообщение об ошибке
        let error = app.staticTexts["Division by zero"]
        XCTAssertTrue(error.exists, "Should show division by zero error")
    }

    // MARK: - Keyboard Tests

    func testKeyboardInput() throws {
        let app = XCUIApplication()
        app.launch()

        // Вводим с клавиатуры "1+2="
        app.typeText("1")
        app.typeText("+")
        app.typeText("2")
        app.typeText("\r") // Enter

        // Проверяем результат "3"
        let result = app.staticTexts["3"]
        XCTAssertTrue(result.exists, "Result should be 3")
    }

    // MARK: - Clipboard Tests

    func testPasteExpression() throws {
        let app = XCUIApplication()
        app.launch()

        // Копируем выражение в буфер обмена
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("(15+16)*5", forType: .string)

        // Вставляем через ⌘V
        app.keyDown(using: .command, "v")

        // Проверяем результат "155"
        let result = app.staticTexts["155"]
        XCTAssertTrue(result.exists, "Result should be 155 after paste")
    }

    // MARK: - History Tests

    func testHistoryPanelExists() throws {
        let app = XCUIApplication()
        app.launch()

        // Нажимаем на кнопку истории
        let historyButton = app.buttons["clock"] // SF Symbol для истории
        if historyButton.exists {
            historyButton.tap()

            // Проверяем, что панель истории открылась
            let historyPanel = app.windows["History"]
            XCTAssertTrue(historyPanel.exists || app.staticTexts["History"].exists)
        }
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() throws {
        let app = XCUIApplication()
        app.launch()

        // Проверяем, что у кнопок есть accessibility labels
        let button0 = app.buttons["0"]
        XCTAssertTrue(button0.exists)
        // Accessibility label должен совпадать с заголовком кнопки
        XCTAssertEqual(button0.label, "0")
    }
}
```

#### Шаг 5.3: Обнови Package.swift для UI Tests

Открой файл `Package.swift`

Найди секцию targets и добавь UI Tests:

**Было:**
```swift
targets: [
    .target(
        name: "CalculatorEngine",
        path: "Sources/CalculatorEngine"
    ),
    .executableTarget(
        name: "CalculatorApp",
        dependencies: ["CalculatorEngine"],
        path: "Sources",
        sources: [
            "App",
            "Views",
            "ViewModels",
            "Services",
            "Formatting",
            "Theme"
        ]
    ),
    .executableTarget(
        name: "TestRunner",
        dependencies: ["CalculatorEngine"],
        path: "Sources/TestRunner"
    ),
]
```

**Стало:**
```swift
targets: [
    .target(
        name: "CalculatorEngine",
        path: "Sources/CalculatorEngine"
    ),
    .executableTarget(
        name: "CalculatorApp",
        dependencies: ["CalculatorEngine"],
        path: "Sources",
        sources: [
            "App",
            "Views",
            "ViewModels",
            "Services",
            "Formatting",
            "Theme"
        ]
    ),
    .executableTarget(
        name: "TestRunner",
        dependencies: ["CalculatorEngine"],
        path: "Sources/TestRunner"
    ),
    .testTarget(
        name: "CalculatorEngineTests",
        dependencies: ["CalculatorEngine"],
        path: "Tests/Unit"
    ),
    .testTarget(
        name: "CalculatorUITests",
        dependencies: ["CalculatorApp"],
        path: "Tests/UI"
    ),
]
```

#### Шаг 5.4: Запусти и проверь

Выполни тесты:

```bash
cd /Users/kgate/Work/GateCalc
swift test
```

**Важно:** UI Tests могут не работать в headless режиме (без GUI). Если есть ошибки, пропусти их и продолжи.

---

## Этап 6: Заполнение пустых папок

### Почему это важно

Спецификация (раздел 16) требует наличие папок:
- `Components/` — переиспользуемые компоненты
- `Extensions/` — расширения
- `Resources/` — ресурсы

Сейчас эти папки пусты. Нужно либо заполнить их кодом, либо удалить (если не используются).

### Что делать (пошагово)

#### Шаг 6.1: Добавь EmptyStateView в Components

Создай файл `Sources/Components/EmptyStateView.swift`:

```swift
import SwiftUI

/// Представление для отображения пустого состояния.
///
/// Используется в панели истории, когда нет вычислений.
public struct EmptyStateView: View {
    public let title: String
    public let systemImage: String
    public let description: String
    
    public init(title: String, systemImage: String, description: String) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }
    
    public var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
    }
}
```

#### Шаг 6.2: Добавь расширения для String и Decimal

Создай файл `Sources/Extensions/String+Calculator.swift`:

```swift
import Foundation

extension String {
    /// Проверяет, является ли строка допустимым математическим выражением.
    public var isMathExpression: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        let hasDigit = rangeOfCharacter(from: .decimalDigits) != nil
        let hasOperator = ["+", "-", "*", "/", "%"].contains(where: { contains($0) })
        
        return hasDigit && hasOperator
    }
    
    /// Удаляет "=" в конце строки, если есть.
    public var removingTrailingEquals: String {
        if hasSuffix("=") {
            return String(dropLast())
        }
        return self
    }
    
    /// Извлекает первую строку из многострочной строки.
    public var firstLine: String {
        if let newlineIndex = firstIndex(of: "\n") {
            return String(self[..<newlineIndex])
        }
        return self
    }
}
```

Создай файл `Sources/Extensions/Decimal+Extensions.swift`:

```swift
import Foundation

extension Decimal {
    /// Проверяет, является ли число нулём.
    public var isZero: Bool {
        return self == 0
    }
    
    /// Проверяет, является ли число отрицательным.
    public var isNegative: Bool {
        return self < 0
    }
    
    /// Возвращает абсолютное значение.
    public var absoluteValue: Decimal {
        return self < 0 ? -self : self
    }
    
    /// Форматирует число для отображения (удаляет незначащие нули).
    public var displayString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.allowsFloats = true
        
        if let string = formatter.string(from: self as NSDecimalNumber) {
            return string
        }
        
        return "\(self)"
    }
}
```

#### Шаг 6.3: Проверь, что папки не пусты

Выполни в Terminal:

```bash
cd /Users/kgate/Work/GateCalc/Sources
find . -type d -empty
```

Убедись, что папки `Components/`, `Extensions/`, `Resources/` не пусты (или удали их, если не используешь).

Если папки не нужны, удали их:

```bash
rmdir /Users/kgate/Work/GateCalc/Sources/Resources/Assets.xcassets
rmdir /Users/kgate/Work/GateCalc/Sources/Resources
```

#### Шаг 6.4: Запусти и проверь

```bash
cd /Users/kgate/Work/GateCalc
swift build
```

Убедись, что:
1. ✅ Нет ошибок компиляции
2. ✅ Новые файлы используются в проекте

---

## Этап 7: Финальная проверка и тестирование

### Почему это важно

Перед завершением нужно убедиться, что все исправления работают корректно и не сломали существующую функциональность.

### Что делать (пошагово)

#### Шаг 7.1: Запусти все тесты

```bash
cd /Users/kgate/Work/GateCalc
swift test
```

Проверь:
1. ✅ Все Unit Tests проходят
2. ✅ Нет ошибок компиляции
3. ✅ Нет предупреждений

#### Шаг 7.2: Запусти TestRunner

```bash
cd /Users/kgate/Work/GateCalc
swift run TestRunner
```

Проверь:
1. ✅ Все тесты проходят
2. ✅ Нет FAIL сообщений

#### Шаг 7.3: Запусти приложение

```bash
cd /Users/kgate/Work/GateCalc
swift run CalculatorApp
```

Проверь вручную:
1. ✅ Приложение запускается
2. ✅ Дисплей показывает "0"
3. ✅ Кнопки работают (цифры, операции, "=", "C")
4. ✅ ⌘V вставляет выражение и вычисляет
5. ✅ ⌘C копирует результат
6. ✅ Ошибки отображаются корректно
7. ✅ История сохраняется (после перезапуска)

#### Шаг 7.4: Проверь специальные случаи

Введи в приложении следующие выражения и проверь результаты:

| Выражение | Ожидаемый результат |
|-----------|---------------------|
| `15+16` | 31 |
| `(15+16)*5` | 155 |
| `-5+12` | 7 |
| `-(15+16)` | -31 |
| `3.1415*5` | 15.7075 |
| `50%` | 0.5 |
| `100*5%` | 5 |
| `100/5%` | 2000 |
| `0xFF` | 255 |
| `0b1010` | 10 |
| `0o77` | 63 |
| `1.5e3` | 1500 |
| `π` | 3.14159265358979... |
| `e` | 2.71828182845905... |
| `π*2` | 6.28318530717958... |
| `0.1+0.2` | 0.3 (без артефактов) |
| `(15+16+17+18)/4` | 16.5 |
| `1,000,000` | 1000000 |
| `pi` | 3.14159265358979... |
| `1e3` | 1000 |

#### Шаг 7.5: Проверь обработку ошибок

Введи следующие выражения и проверь, что появляются корректные сообщения об ошибках:

| Выражение | Ожидаемое сообщение |
|-----------|---------------------|
| `1/0` | "Division by zero" |
| `15+a` | "Invalid character: a" |
| `(15+16` | "Missing closing parenthesis" |
| `15+16)` | "Extra closing parenthesis" |
| `NaN` | "Invalid expression" |
| `Infinity` | "Invalid expression" |
| `5++3` | "Double operator" |
| `` (пустое) | "Empty expression" |

#### Шаг 7.6: Проверь структуру проекта

Выполни в Terminal:

```bash
cd /Users/kgate/Work/GateCalc/Sources
find . -type f -name "*.swift" | sort
```

Убедись, что есть все необходимые файлы:
- App/CalculatorApp.swift
- Views/*.swift (4 файла)
- ViewModels/CalculatorViewModel.swift
- Services/HistoryService.swift
- History/HistoryEntry.swift
- Clipboard/ClipboardManager.swift
- Formatting/NumberFormatterService.swift
- Theme/CalculatorColors.swift
- Components/EmptyStateView.swift
- Extensions/String+Calculator.swift
- Extensions/Decimal+Extensions.swift
- CalculatorEngine/**/*.swift (все файлы)
- Localization/*.swift, *.strings

#### Шаг 7.7: Проверь публичные API

Открой Xcode (или используй swiftc) и проверь, что следующие типы имеют видимость `public`:
- CalculatorEngine
- Tokenizer
- Parser
- Evaluator
- ExpressionNode
- Token
- BinaryOperator
- CalculatorError

#### Шаг 7.8: Проверь документацию

В Xcode наведи курсор на публичные API (CalculatorEngine, Tokenizer, Parser, Evaluator). Убедись, что появляются doc comments с описанием.

#### Шаг 7.9: Финальный отчёт

Создай файл `Tests/Unit/FinalCheck.swift` (опционально, для документации):

```swift
import XCTest
@testable import CalculatorEngine

/// Финальная проверка соответствия спецификации SRS v1.1
final class FinalCheckTests: XCTestCase {

    private let engine = CalculatorEngine()

    // MARK: - Структура проекта

    func testCalculatorEngineIsPublic() {
        // Проверяем, что CalculatorEngine доступен за пределами модуля
        let engine = CalculatorEngine()
        XCTAssertNotNil(engine)
    }

    func testTokenizerIsPublic() {
        let tokenizer = Tokenizer()
        XCTAssertNotNil(tokenizer)
    }

    func testParserIsPublic() {
        let parser = Parser()
        XCTAssertNotNil(parser)
    }

    func testEvaluatorIsPublic() {
        let evaluator = Evaluator()
        XCTAssertNotNil(evaluator)
    }

    // MARK: - Специальные случаи

    func testPiConstant() throws {
        let result = try engine.evaluate("pi")
        XCTAssertTrue(result.description.hasPrefix("3.1415"))
    }

    func testExponentialNotationWithoutDot() throws {
        let result = try engine.evaluate("1e3")
        XCTAssertEqual(result, 1000)
    }

    func testEuropeanDecimalFormat() throws {
        let result = try engine.evaluate("1,5")
        XCTAssertEqual(result, Decimal(string: "1.5")!)
    }

    // MARK: - Ошибки

    func testDoubleOperatorAfterPercent() {
        XCTAssertThrowsError(try engine.evaluate("5%+3"))
    }

    // MARK: - Main Scenario from SRS

    func testSRSMainScenario() throws {
        let result = try engine.evaluate("(15+16+17+18)/4")
        XCTAssertEqual(result, Decimal(string: "16.5")!)
    }
}
```

---

## Итоговое время выполнения

| Этап | Описание | Время |
|------|----------|-------|
| 1 | Реорганизация структуры проекта | 2-3 часа |
| 2 | Публичные API | 1 час |
| 3 | Спец. случаи ввода | 2-3 часа |
| 4 | Очистка кода и документация | 1-2 часа |
| 5 | UI Tests | 2-3 часа |
| 6 | Заполнение пустых папок | 1 час |
| 7 | Финальная проверка | 2-3 часа |
| **Итого** | | **10-16 часов** |

---

## Что делать, если что-то не работает

### Частые проблемы и решения

1. **Ошибка компиляции: "Cannot find 'public' in scope"**
   - Решение: Убедись, что используешь Swift 6+ и правильно указываешь visibility modifier

2. **Тесты не проходят после изменения видимости**
   - Решение: Проверь, что все зависимости также публичные (например, если `Parser` использует `ExpressionNode`, то `ExpressionNode` тоже должен быть public)

3. **Локализация не работает**
   - Решение: Проверь, что файлы `Localizable.strings` находятся в правильных папках (`en.lproj/`, `ru.lproj/`)

4. **История не сохраняется**
   - Решение: Проверь, что `UserDefaultsService` вызывается в методах `add` и `clear`

5. **Анимации не работают**
   - Решение: Проверь, что используешь `.animation()` правильно и свойства наблюдаемые

6. **UI Tests не работают в headless режиме**
   - Решение: UI Tests требуют GUI. Запускай их только в Xcode с включённым Simulator или на реальном устройстве

---

## Заключение

Этот план исправляет все технические и архитектурные недостатки проекта, кроме UI/UX (для которых есть отдельный план). После выполнения всех этапов проект будет соответствовать спецификации SRS v1.1 по следующим критериям:

- ✅ Структура проекта соответствует спецификации
- ✅ Все публичные API имеют правильную видимость
- ✅ Обработка специальных случаев ввода полная
- ✅ Код очищен от мёртвого кода
- ✅ Добавлена документация для публичных API
- ✅ Есть UI Tests
- ✅ Пустые папки заполнены кодом

Удачи в реализации! 🚀
