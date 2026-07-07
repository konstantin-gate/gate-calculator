# План исправления технических и архитектурных недостатков калькулятора (Итоговая версия)

## Общая информация

**Дата создания:** 2026-07-04
**Автор плана:** OrnithQ8
**Целевая аудитория:** Младший разработчик (Junior Swift/SwiftUI)
**Время выполнения:** 10-14 часов

---

## Введение и контекст

После выполнения плана разработки калькулятора вычислительное ядро (CalculatorEngine) работает корректно для всех базовых и специальных сценариев. Однако при проверке проекта против спецификации SRS v1.1 были выявлены технические и архитектурные недостатки, которые необходимо устранить.

**Что было проверено:**
- Все файлы CalculatorEngine: Tokenizer.swift, Parser.swift, Evaluator.swift, ExpressionNode.swift, CalculatorError.swift, Precedence.swift, Token.swift, CalculatorEngine.swift
- Все файлы приложения: CalculatorApp.swift, CalculatorViewModel.swift, DisplayView.swift, CalculatorView.swift, CalculatorButton.swift, HistoryPanelView.swift
- Все файлы сервисов: HistoryService.swift, NumberFormatterService.swift, CalculatorColors.swift
- Все тесты: CalculatorEngineTests.swift, TokenizerTests.swift, ParserTests.swift, EvaluatorTests.swift
- Package.swift
- Структура директорий

**Что НЕ было проверено (UI/UX):**
- Визуальное оформление, анимации, цветовые схемы — это отдельный план.

---

## Что нужно исправить и зачем (кратко)

1. **API CalculatorEngine не публичные** — `Parser`, `Evaluator`, `ExpressionNode`, `CalculatorError` имеют видимость `internal`. Спецификация требует, чтобы CalculatorEngine был полностью независимым модулем.
2. **Нет документации в коде** — отсутствуют doc comments (`///`) для публичных API.
3. **Мёртвый код в Tokenizer** — две идентичные приватные функции `isThousandsSeparatorPattern` и `containsOnlyDigitsAndCommas`, вторая ветка `else if` в `preprocess` недостижима.
4. **Структура проекта не соответствует спецификации** — отсутствуют папки `History/`, `Models/`, `Clipboard/`. `HistoryEntry` находится в `Services/`, должен быть в `History/`.
5. **Нет сервиса буфера обмена** — clipboard используется напрямую через `NSPasteboard` в двух местах, должен быть единый сервис.
6. **Package.swift не включает новые директории** — после перемещения файлов проект не скомпилируется.
7. **Нет локализации** — папки `en.lproj/` и `ru.lproj/` пусты.
8. **Нет UI Tests** — спецификация требует Unit + UI тесты.
9. **Пустые папки** — `Components/`, `Extensions/` существуют, но пусты.

---

## Порядок выполнения

Этапы выполняются строго по порядку. Каждый этап должен быть завершён и проверен (`swift build` + `swift test`) перед переходом к следующему.

---

## Этап 1: Делаем API CalculatorEngine публичными + добавляем документацию

### Почему это важно

Спецификация (раздел 21) требует, чтобы CalculatorEngine был полностью независимым модулем. Все типы, которые используются за пределами модуля (в тестах через `@testable import`, в CalculatorApp), должны иметь видимость `public`.

**Текущее состояние:**
- `Token` — **уже public** (не меняем)
- `BinaryOperator` — **уже public** (не меняем)
- `Tokenizer` — **уже public** (не меняем, но нужно добавить doc comments)
- `CalculatorEngine` — **уже public** (не меняем, но нужно добавить doc comments)
- `Parser` — **internal** (нужно сделать public + добавить doc comments)
- `Evaluator` — **internal** (нужно сделать public + добавить doc comments)
- `ExpressionNode` — **internal** (нужно сделать public + добавить doc comments)
- `CalculatorError` — **internal** (нужно сделать public + добавить doc comments)
- `Precedence` — **internal** (оставляем internal, это внутренний тип для Parser)

### Шаг 1.1: CalculatorError — public + doc comments

**Файл:** `Sources/CalculatorEngine/Errors/CalculatorError.swift`

**Текущее содержимое (39 строк):**
```swift
import Foundation

enum CalculatorError: Error, LocalizedError, Sendable {
    case divisionByZero
    case invalidExpression(String)
    case missingClosingParenthesis
    case extraClosingParenthesis
    case invalidCharacter(String)
    case emptyExpression
    case numberOverflow
    case invalidNumber(String)
    case doubleOperator
    case multipleDecimalSeparators

    var errorDescription: String? {
        switch self {
        case .divisionByZero:
            return "Division by zero"
        case .invalidExpression(let msg):
            return msg
        case .missingClosingParenthesis:
            return "Missing closing parenthesis"
        case .extraClosingParenthesis:
            return "Extra closing parenthesis"
        case .invalidCharacter(let char):
            return "Invalid character: \(char)"
        case .emptyExpression:
            return "Empty expression"
        case .numberOverflow:
            return "Number too large"
        case .invalidNumber(let num):
            return "Invalid number: \(num)"
        case .doubleOperator:
            return "Double operator"
        case .multipleDecimalSeparators:
            return "Multiple decimal separators"
        }
    }
}
```

**Новое содержимое (заменить весь файл):**
```swift
import Foundation

/// Ошибки вычислительного движка калькулятора.
///
/// Перечисление описывает все возможные ошибки, которые могут возникнуть
/// при разборе и вычислении математического выражения.
public enum CalculatorError: Error, LocalizedError, Sendable {
    /// Деление на ноль.
    case divisionByZero

    /// Некорректное выражение с кастомным сообщением.
    case invalidExpression(String)

    /// Пропущена закрывающая скобка (например, "(15+16").
    case missingClosingParenthesis

    /// Лишняя закрывающая скобка (например, "15+16)").
    case extraClosingParenthesis

    /// Неверный символ в выражении (например, "15+a").
    case invalidCharacter(String)

    /// Пустое выражение.
    case emptyExpression

    /// Число слишком большое для точного представления.
    case numberOverflow

    /// Некорректное число с кастомным сообщением.
    case invalidNumber(String)

    /// Двойной оператор (например, "5++3").
    case doubleOperator

    /// Несколько десятичных разделителей (например, "1.5.3").
    case multipleDecimalSeparators

    /// Человекочитаемое описание ошибки.
    public var errorDescription: String? {
        switch self {
        case .divisionByZero:
            return "Division by zero"
        case .invalidExpression(let msg):
            return msg
        case .missingClosingParenthesis:
            return "Missing closing parenthesis"
        case .extraClosingParenthesis:
            return "Extra closing parenthesis"
        case .invalidCharacter(let char):
            return "Invalid character: \(char)"
        case .emptyExpression:
            return "Empty expression"
        case .numberOverflow:
            return "Number too large"
        case .invalidNumber(let num):
            return "Invalid number: \(num)"
        case .doubleOperator:
            return "Double operator"
        case .multipleDecimalSeparators:
            return "Multiple decimal separators"
        }
    }
}
```

**Что изменилось:**
- Строка 3: `enum` → `public enum`
- Строка 27: `var errorDescription` → `public var errorDescription`
- Добавлены doc comments (`///`) перед каждым case и перед `errorDescription`

---

### Шаг 1.2: ExpressionNode — public + doc comments

**Файл:** `Sources/CalculatorEngine/AST/ExpressionNode.swift`

**Текущее содержимое (7 строк):**
```swift
import Foundation

indirect enum ExpressionNode: Sendable {
    case number(Decimal)
    case unaryMinus(ExpressionNode)
    case binary(BinaryOperator, ExpressionNode, ExpressionNode)
}
```

**Новое содержимое (заменить весь файл):**
```swift
import Foundation

/// Узел абстрактного синтаксического дерева (AST).
///
/// Представляет структуру математического выражения после парсинга.
/// Используется для рекурсивного вычисления результата.
public indirect enum ExpressionNode: Sendable {
    /// Числовое значение (листовой узел).
    public case number(Decimal)

    /// Унарный минус (отрицательное число или операция отрицания).
    public case unaryMinus(ExpressionNode)

    /// Бинарная операция (сложение, вычитание, умножение, деление).
    public case binary(BinaryOperator, ExpressionNode, ExpressionNode)
}
```

**Что изменилось:**
- Строка 3: `indirect enum` → `public indirect enum`
- Все case'ы получили модификатор `public`
- Добавлены doc comments

---

### Шаг 1.3: Parser — public + doc comments

**Файл:** `Sources/CalculatorEngine/Parser/Parser.swift`

**Текущее содержимое (124 строки):**
```swift
import Foundation

struct Parser: Sendable {

    func parse(_ tokens: [Token]) throws -> ExpressionNode {
        guard !tokens.isEmpty else {
            throw CalculatorError.emptyExpression
        }

        let rpn = try toRPN(tokens)
        return try buildAST(from: rpn)
    }

    private func toRPN(_ tokens: [Token]) throws -> [Token] {
        // ... (алгоритм сортировочной станции)
    }

    private func buildAST(from rpn: [Token]) throws -> ExpressionNode {
        // ... (построение AST из RPN)
    }
}
```

**Новое содержимое (заменить только первые 12 строк, остальное без изменений):**

Найди строку 3:
```swift
struct Parser: Sendable {
```

Замени на:
```swift
/// Парсер математических выражений.
///
/// Использует алгоритм сортировочной станции (Shunting Yard) для преобразования
/// инфиксной записи в обратную польскую нотацию (RPN), а затем строит
/// абстрактное синтаксическое дерево (AST).
public struct Parser: Sendable {

    /// Парсит последовательность токенов в AST.
    ///
    /// - Parameter tokens: Массив токенов, полученный от `Tokenizer`.
    /// - Returns: Корневой узел абстрактного синтаксического дерева.
    /// - Throws: `CalculatorError` если токены не образуют корректное выражение.
    public func parse(_ tokens: [Token]) throws -> ExpressionNode {
        guard !tokens.isEmpty else {
            throw CalculatorError.emptyExpression
        }

        let rpn = try toRPN(tokens)
        return try buildAST(from: rpn)
    }
```

**Остальные методы (`toRPN`, `buildAST`) остаются `private` и без изменений.**

---

### Шаг 1.4: Evaluator — public + doc comments

**Файл:** `Sources/CalculatorEngine/Evaluator/Evaluator.swift`

**Текущее содержимое (33 строки):**
```swift
import Foundation

struct Evaluator: Sendable {

    func evaluate(_ node: ExpressionNode) throws -> Decimal {
        switch node {
        case .number(let value):
            return value

        case .unaryMinus(let inner):
            let val = try evaluate(inner)
            return -val

        case .binary(let op, let left, let right):
            let l = try evaluate(left)
            let r = try evaluate(right)

            switch op {
            case .add:
                return l + r
            case .subtract:
                return l - r
            case .multiply:
                return l * r
            case .divide:
                guard r != 0 else {
                    throw CalculatorError.divisionByZero
                }
                return l / r
            }
        }
    }
}
```

**Новое содержимое (заменить первые 10 строк, остальное без изменений):**

Найди строку 3:
```swift
struct Evaluator: Sendable {
```

Замени на:
```swift
/// Вычислитель абстрактного синтаксического дерева.
///
/// Рекурсивно обходит AST и вычисляет результат математического выражения.
public struct Evaluator: Sendable {

    /// Вычисляет значение AST.
    ///
    /// - Parameter node: Корневой узел абстрактного синтаксического дерева.
    /// - Returns: Результат вычисления в виде `Decimal`.
    /// - Throws: `CalculatorError.divisionByZero` при делении на ноль.
    public func evaluate(_ node: ExpressionNode) throws -> Decimal {
        switch node {
```

**Остальной код метода `evaluate` без изменений.**

---

### Шаг 1.5: Tokenizer — добавляем doc comments

**Файл:** `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

Этот файл уже имеет `public` видимость. Нужно добавить doc comments перед структурой и публичным методом.

Найди строку 3:
```swift
public struct Tokenizer: Sendable {
```

Замени на:
```swift
/// Токенизатор математических выражений.
///
/// Преобразует строку выражения в последовательность токенов (`[Token]`).
/// Выполняет предварительную обработку: удаление "=", обработка переносов строк,
/// нормализация разделителей тысяч/десятичных запятых, проверка на NaN/Infinity.
public struct Tokenizer: Sendable {

    /// Создаёт новый экземпляр токенизатора.
    public init() {}

    /// Токенизирует математическое выражение.
    ///
    /// - Parameter input: Строка с математическим выражением.
    /// - Returns: Массив токенов. Пустой массив для пустого ввода.
    /// - Throws: `CalculatorError` если выражение содержит некорректные символы,
    ///   двойные операторы или другие синтаксические ошибки.
    public func tokenize(_ input: String) throws -> [Token] {
```

**Остальной код файла без изменений.**

---

### Шаг 1.6: CalculatorEngine — добавляем doc comments

**Файл:** `Sources/CalculatorEngine/CalculatorEngine.swift`

Найди строку 3:
```swift
public struct CalculatorEngine: Sendable {
```

Замени на:
```swift
/// Вычислительный движок калькулятора.
///
/// Фасадный тип, объединяющий Tokenizer, Parser и Evaluator.
/// Отвечает за полный цикл: строка → токены → AST → результат.
///
/// - Note: Движок является полностью независимым модулем и не содержит
///         зависимостей от SwiftUI или AppKit.
public struct CalculatorEngine: Sendable {

    /// Создаёт новый экземпляр вычислительного движка.
    public init() {}

    /// Вычисляет математическое выражение.
    ///
    /// Выполняет полную цепочку: предварительная обработка → токенизация →
    /// парсинг → построение AST → вычисление.
    ///
    /// - Parameter expression: Строка с математическим выражением.
    /// - Returns: Результат вычисления в виде `Decimal`.
    /// - Throws: `CalculatorError` если выражение некорректно.
    public func evaluate(_ expression: String) throws -> Decimal {
```

**Остальной код файла без изменений.**

---

### Шаг 1.7: Проверка после Этапа 1

Выполни в Terminal:
```bash
cd /Users/kgate/Work/GateCalc
swift build
```

Если компиляция успешна, запусти тесты:
```bash
swift test
```

Все тесты должны пройти. Если есть ошибки — исправь до перехода к Этапу 2.

---

## Этап 2: Реорганизация структуры проекта

### Почему это важно

Спецификация (раздел 16) требует определённую структуру проекта. Текущая структура не соответствует:
- `HistoryEntry` находится в `Services/`, должен быть в отдельной папке `History/`
- Нет отдельной папки `Clipboard/` для работы с буфером обмена
- Нет папки `Models/` (может быть пустой, но должна существовать)

### Шаг 2.1: Создай новые папки

Открой Terminal и выполни команды по порядку:

```bash
cd /Users/kgate/Work/GateCalc/Sources

mkdir -p History
mkdir -p Models
mkdir -p Clipboard
```

**Проверь, что папки созданы:**
```bash
ls -la History Models Clipboard
```

---

### Шаг 2.2: Перемести HistoryEntry в Sources/History/

**Создай новый файл:** `Sources/History/HistoryEntry.swift`

**Содержимое файла (скопируй полностью):**
```swift
import Foundation

/// Запись истории вычислений.
///
/// Содержит исходное выражение, результат вычисления и метку времени.
public struct HistoryEntry: Identifiable, Sendable {
    /// Уникальный идентификатор записи.
    public let id = UUID()

    /// Исходное математическое выражение.
    public let expression: String

    /// Результат вычисления.
    public let result: Decimal

    /// Время добавления записи в историю.
    public let timestamp: Date

    /// Создаёт новую запись истории.
    ///
    /// - Parameters:
    ///   - expression: Исходное выражение.
    ///   - result: Результат вычисления.
    public init(expression: String, result: Decimal) {
        self.expression = expression
        self.result = result
        self.timestamp = Date()
    }
}
```

**Открой файл:** `Sources/Services/HistoryService.swift`

**Удали определение `HistoryEntry` (строки 1-14).** После удаления файл должен начинаться со строки `public final class HistoryService: @unchecked Sendable {`.

**Текущее содержимое (строки 1-57):**
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

public final class HistoryService: @unchecked Sendable {
    // ... остальной код без изменений
}
```

**Новое содержимое (удали строки 1-14, оставь только):**
```swift
import Foundation

public final class HistoryService: @unchecked Sendable {

    public static let shared = HistoryService()

    private var entries: [HistoryEntry] = []
    private let maxEntries: Int
    private let lock = NSLock()

    public init(maxEntries: Int = 50) {
        self.maxEntries = maxEntries
    }

    public func add(expression: String, result: Decimal) {
        lock.lock()
        defer { lock.unlock() }

        let entry = HistoryEntry(expression: expression, result: result)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    public func getEntries() -> [HistoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    public func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}
```

**Важно:** `HistoryEntry` остаётся в файле `HistoryService.swift`? **НЕТ.** Он перемещён в отдельный файл. В `HistoryService.swift` он больше не определяется. Но `HistoryEntry` используется в методах `add`, `getEntries`, `count` — это нормально, потому что компилятор найдёт его в том же модуле (в папке `History/`).

---

### Шаг 2.3: Создай ClipboardManager в Sources/Clipboard/

**Создай новый файл:** `Sources/Clipboard/ClipboardManager.swift`

**Содержимое файла (скопируй полностью):**
```swift
import AppKit
import Foundation

/// Менеджер буфера обмена.
///
/// Предоставляет единый интерфейс для чтения и записи строк в системный
/// буфер обмена через NSPasteboard.
public final class ClipboardManager: @unchecked Sendable {

    /// Общий экземпляр менеджера.
    public static let shared = ClipboardManager()

    private init() {}

    /// Получает строку из буфера обмена.
    ///
    /// - Returns: Строка из буфера обмена или `nil`, если буфер пуст.
    public func getString() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    /// Помещает строку в буфер обмена.
    ///
    /// - Parameter string: Строка для записи в буфер обмена.
    public func setString(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    /// Проверяет, является ли строка математическим выражением.
    ///
    /// Выражение считается математическим, если содержит хотя бы одну цифру
    /// и хотя бы один оператор (+, -, *, /, %).
    ///
    /// - Parameter text: Проверяемая строка.
    /// - Returns: `true`, если строка является математическим выражением.
    public func isMathExpression(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let hasDigit = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        let hasOperator = ["+", "-", "*", "/", "%"].contains(where: { trimmed.contains($0) })

        return hasDigit && hasOperator
    }
}
```

---

### Шаг 2.4: Проверка после Этапа 2

Выполни в Terminal:
```bash
cd /Users/kgate/Work/GateCalc
swift build
```

**Ожидаемый результат:** Компиляция успешна. Если есть ошибка "Cannot find 'HistoryEntry' in scope" — проверь, что определение `HistoryEntry` удалено из `HistoryService.swift` и добавлено в новый файл `History/HistoryEntry.swift`.

---

## Этап 3: Обновление Package.swift

### Почему это важно

После создания новых директорий (`History/`, `Clipboard/`) и перемещения файлов, Package.swift должен знать о новых источниках. Без этого `CalculatorApp` не найдёт файлы в новых папках и проект не скомпилируется.

### Шаг 3.1: Открой Package.swift

**Файл:** `Package.swift`

**Текущее содержимое (строки 30-38):**
```swift
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
```

**Замени на:**
```swift
        .executableTarget(
            name: "CalculatorApp",
            dependencies: ["CalculatorEngine"],
            path: "Sources",
            sources: [
                "App",
                "Views",
                "ViewModels",
                "Services",
                "History",
                "Clipboard",
                "Models",
                "Formatting",
                "Theme"
            ]
        ),
```

**Что добавлено:** `"History"`, `"Clipboard"`, `"Models"` в массив `sources`.

**Важно:** Папка `Localization/` НЕ добавляется в sources, потому что `.strings` файлы не компилируются как Swift. Они подключаются автоматически через Xcode/SPM как ресурсы.

---

### Шаг 3.2: Проверка после Этапа 3

Выполни в Terminal:
```bash
cd /Users/kgate/Work/GateCalc
swift build
```

Компиляция должна быть успешной.

---

## Этап 4: Обновление кода приложения для использования ClipboardManager

### Почему это важно

Сейчас буфер обмена используется напрямую через `NSPasteboard.general` в двух местах:
1. `CalculatorApp.swift` — метод `performKeyEquivalent` (вставка из буфера)
2. `CalculatorViewModel.swift` — метод `copyResult` (копирование в буфер)

После создания `ClipboardManager` нужно заменить прямые вызовы на использование сервиса. Это обеспечивает единую точку контроля и соответствует архитектуре проекта.

### Шаг 4.1: Обновление CalculatorApp.swift

**Файл:** `Sources/App/CalculatorApp.swift`

Найди метод `performKeyEquivalent` (строки 74-89). Текущий код:
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

**Замени на:**
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

**Что изменилось:** Строка `NSPasteboard.general.string(forType: .string)` заменена на `ClipboardManager.shared.getString()`.

---

### Шаг 4.2: Обновление CalculatorViewModel.swift

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

Найди метод `copyResult` (строки 125-130). Текущий код:
```swift
    func copyResult() {
        if let result = result {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
        }
    }
```

**Замени на:**
```swift
    func copyResult() {
        if let result = result {
            ClipboardManager.shared.setString(result)
        }
    }
```

**Что изменилось:** Прямые вызовы `NSPasteboard.general` заменены на `ClipboardManager.shared`.

---

### Шаг 4.3: Проверка после Этапа 4

Выполни в Terminal:
```bash
cd /Users/kgate/Work/GateCalc
swift build
```

Компиляция должна быть успешной. Если есть ошибка "Cannot find 'ClipboardManager' in scope" — проверь, что:
1. Файл `Sources/Clipboard/ClipboardManager.swift` создан
2. Папка `"Clipboard"` добавлена в `sources` в `Package.swift`

---

## Этап 5: Очистка мёртвого кода в Tokenizer

### Почему это важно

В методе `preprocess` файла `Tokenizer.swift` есть два дефекта:
1. Две идентичные приватные функции `isThousandsSeparatorPattern` и `containsOnlyDigitsAndCommas` (строки 148-160).
2. Вторая ветка `else if` в `preprocess` (строки 140-142) недостижима, потому что первая ветка `if` (строки 138-140) уже покрывает тот же случай.

Это нарушает принцип DRY и создаёт путаницу.

### Шаг 5.1: Удали дублирующуюся функцию и ветку в preprocess

**Файл:** `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

#### 5.1.1: Удали функцию `containsOnlyDigitsAndCommas`

Найди строки 155-160:
```swift
    private func containsOnlyDigitsAndCommas(_ str: String) -> Bool {
        for c in str {
            if !c.isNumber && c != "," { return false }
        }
        return true
    }
```

**Удали эти 6 строк полностью.**

#### 5.1.2: Удали вторую ветку `else if` в preprocess

Найди строки 136-143 (блок обработки запятых):
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

**Замени на:**
```swift
        let comma = Character(",")
        if trimmed.contains(comma) {
            if !trimmed.contains(".") && isThousandsSeparatorPattern(trimmed) {
                result.removeAll(where: { $0 == comma })
            }
        }
```

**Что изменилось:** Удалена ветка `else if !trimmed.contains(".") && containsOnlyDigitsAndCommas(trimmed) { result.removeAll(where: { $0 == comma }) }`.

**Почему это безопасно:** Функция `isThousandsSeparatorPattern` проверяет, что строка содержит только цифры и запятые. Функция `containsOnlyDigitsAndCommas` делает то же самое. Первая ветка уже обрабатывает все случаи, когда запятые являются разделителями тысяч (или должны быть удалены как невалидные). Вторая ветка никогда не выполняется, потому что если первая условие `!trimmed.contains(".") && isThousandsSeparatorPattern(trimmed)` ложно, то либо есть точка, либо строка содержит не только цифры и запятые — в обоих случаях вторая ветка тоже была бы ложной.

---

### Шаг 5.2: Проверка после Этапа 5

Выполни в Terminal:
```bash
cd /Users/kgate/Work/GateCalc
swift test
```

Все тесты должны пройти. Особое внимание уделите:
- `testTokenize_ThousandsSeparator` — должен проходить (1,000,000 → 1000000)
- `testTokenize_EmptyString` — должен проходить

---

## Этап 6: Локализация

### Почему это важно

Спецификация (раздел 8) требует поддержку локализации. Папки `en.lproj/` и `ru.lproj/` существуют, но пусты. Нужно создать файлы `.strings` с основными строками приложения.

### Шаг 6.1: Создай английский файл локализации

**Создай файл:** `Sources/Localization/en.lproj/Localizable.strings`

**Содержимое файла (скопируй полностью):**
```
/* English localization */

/* Display */
"display.default" = "0";
"display.expression" = "%@";

/* Buttons */
"button.clear" = "C";
"button.equals" = "=";

/* History */
"history.title" = "History";
"history.empty.title" = "No History";
"history.empty.description" = "Calculations will appear here";
"history.done" = "Done";
"history.clear" = "Clear";

/* Errors */
"errors.divisionByZero" = "Division by zero";
"errors.invalidExpression" = "Invalid expression";
"errors.missingParenthesis" = "Missing closing parenthesis";
"errors.extraParenthesis" = "Extra closing parenthesis";
"errors.doubleOperator" = "Double operator";
"errors.emptyExpression" = "Empty expression";

/* Clipboard */
"clipboard.cannotEvaluate" = "Cannot evaluate";
```

### Шаг 6.2: Создай русский файл локализации

**Создай файл:** `Sources/Localization/ru.lproj/Localizable.strings`

**Содержимое файла (скопируй полностью):**
```
/* Russian localization */

/* Display */
"display.default" = "0";
"display.expression" = "%@";

/* Buttons */
"button.clear" = "C";
"button.equals" = "=";

/* History */
"history.title" = "История";
"history.empty.title" = "Нет истории";
"history.empty.description" = "Вычисления появятся здесь";
"history.done" = "Готово";
"history.clear" = "Очистить";

/* Errors */
"errors.divisionByZero" = "Деление на ноль";
"errors.invalidExpression" = "Неверное выражение";
"errors.missingParenthesis" = "Пропущена закрывающая скобка";
"errors.extraParenthesis" = "Лишняя закрывающая скобка";
"errors.doubleOperator" = "Двойной оператор";
"errors.emptyExpression" = "Пустое выражение";

/* Clipboard */
"clipboard.cannotEvaluate" = "Невозможно вычислить";
```

---

### Шаг 6.3: Проверка после Этапа 6

Выполни в Terminal:
```bash
cd /Users/kgate/Work/GateCalc/Sources/Localization
ls -la en.lproj/ru.lproj/
```

Убедись, что в каждой папке есть файл `Localizable.strings`.

---

## Этап 7: Заполнение пустых папок Components/ и Extensions/

### Почему это важно

Спецификация (раздел 16) требует наличие папок `Components/` и `Extensions/`. Они не должны быть пустыми. Нужно добавить полезный код, который будет использоваться в проекте.

### Шаг 7.1: Создай EmptyStateView в Components/

**Создай файл:** `Sources/Components/EmptyStateView.swift`

**Содержимое файла (скопируй полностью):**
```swift
import SwiftUI

/// Представление для отображения пустого состояния.
///
/// Используется в панели истории и других местах, где может не быть данных.
public struct EmptyStateView: View {
    /// Заголовок пустого состояния.
    public let title: String

    /// Имя системного изображения (SF Symbols).
    public let systemImage: String

    /// Описание пустого состояния.
    public let description: String

    /// Создаёт представление пустого состояния.
    ///
    /// - Parameters:
    ///   - title: Заголовок.
    ///   - systemImage: Имя системного изображения.
    ///   - description: Описание.
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

---

### Шаг 7.2: Создай расширения для String в Extensions/

**Создай файл:** `Sources/Extensions/String+Calculator.swift`

**Содержимое файла (скопируй полностью):**
```swift
import Foundation

extension String {
    /// Удаляет символ "=" в конце строки, если он присутствует.
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

    /// Проверяет, является ли строка допустимым математическим выражением.
    ///
    /// Выражение должно содержать хотя бы одну цифру и хотя бы один оператор.
    public var isMathExpression: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let hasDigit = rangeOfCharacter(from: .decimalDigits) != nil
        let hasOperator = ["+", "-", "*", "/", "%"].contains(where: { contains($0) })

        return hasDigit && hasOperator
    }
}
```

---

### Шаг 7.3: Создай расширения для Decimal в Extensions/

**Создай файл:** `Sources/Extensions/Decimal+Extensions.swift`

**Содержимое файла (скопируй полностью):**
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
    ///
    /// Использует `NumberFormatter` с десятичным стилем и максимальным
    /// количеством знаков после запятой, равным 10.
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

---

### Шаг 7.4: Проверка после Этапа 7

Выполни в Terminal:
```bash
cd /Users/kgate/Work/GateCalc
swift build
```

Компиляция должна быть успешной.

---

## Этап 8: Добавление UI Tests

### Почему это важно

Спецификация (раздел 90) требует наличие как Unit Tests, так и UI Tests. Сейчас в проекте есть только `Tests/Unit/`. Нужно создать `Tests/UI/` с базовыми тестами взаимодействия с интерфейсом.

### Шаг 8.1: Создай папку для UI Tests

Открой Terminal и выполни:
```bash
mkdir -p /Users/kgate/Work/GateCalc/Tests/UI
```

---

### Шаг 8.2: Создай файл UI Tests

**Создай файл:** `Tests/UI/CalculatorUITests.swift`

**Содержимое файла (скопируй полностью):**
```swift
import XCTest
@testable import CalculatorApp

final class CalculatorUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    // MARK: - Launch Tests

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.exists, "Application window should exist after launch")
    }

    // MARK: - Button Existence Tests

    func testDigitButtonsExist() throws {
        let app = XCUIApplication()
        app.launch()

        for digit in "0123456789" {
            let button = app.buttons[digit.description]
            XCTAssertTrue(button.exists, "Button '\(digit)' should exist")
        }
    }

    func testOperatorButtonsExist() throws {
        let app = XCUIApplication()
        app.launch()

        let operators: [String] = ["+", "-", "*", "/", "%"]
        for op in operators {
            let button = app.buttons[op]
            XCTAssertTrue(button.exists, "Button '\(op)' should exist")
        }
    }

    func testClearButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["C"].exists, "Clear button should exist")
    }

    func testEqualsButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["="].exists, "Equals button should exist")
    }

    // MARK: - Calculation Tests

    func testSimpleAddition() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["1"].tap()
        app.buttons["5"].tap()
        app.buttons["+"].tap()
        app.buttons["1"].tap()
        app.buttons["6"].tap()
        app.buttons["="].tap()

        let result = app.staticTexts["31"]
        XCTAssertTrue(result.exists, "Result should be 31")
    }

    func testParenthesesCalculation() throws {
        let app = XCUIApplication()
        app.launch()

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

        let result = app.staticTexts["155"]
        XCTAssertTrue(result.exists, "Result should be 155")
    }

    // MARK: - Error Tests

    func testDivisionByZeroShowsError() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["1"].tap()
        app.buttons["/"].tap()
        app.buttons["0"].tap()
        app.buttons["="].tap()

        let error = app.staticTexts["Division by zero"]
        XCTAssertTrue(error.exists, "Should show division by zero error")
    }

    // MARK: - Keyboard Tests

    func testKeyboardInput() throws {
        let app = XCUIApplication()
        app.launch()

        app.typeText("1")
        app.typeText("+")
        app.typeText("2")
        app.typeText("\r")

        let result = app.staticTexts["3"]
        XCTAssertTrue(result.exists, "Result should be 3")
    }

    // MARK: - Clipboard Tests

    func testPasteExpression() throws {
        let app = XCUIApplication()
        app.launch()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("(15+16)*5", forType: .string)

        app.keyDown(using: .command, "v")

        let result = app.staticTexts["155"]
        XCTAssertTrue(result.exists, "Result should be 155 after paste")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() throws {
        let app = XCUIApplication()
        app.launch()

        let button0 = app.buttons["0"]
        XCTAssertTrue(button0.exists, "Button '0' should exist")
        XCTAssertEqual(button0.label, "0", "Button '0' label should be '0'")
    }
}
```

---

### Шаг 8.3: Добавь UI Tests в Package.swift

**Файл:** `Package.swift`

Найди секцию targets. Текущее содержимое (строки 22-45):
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
                "History",
                "Clipboard",
                "Models",
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

**Замени на:**
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
                "History",
                "Clipboard",
                "Models",
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

**Что добавлено:** Два новых `.testTarget`:
1. `CalculatorEngineTests` — зависимости: `CalculatorEngine`, путь: `Tests/Unit`
2. `CalculatorUITests` — зависимости: `CalculatorApp`, путь: `Tests/UI`

---

### Шаг 8.4: Проверка после Этапа 8

Выполни в Terminal:
```bash
cd /Users/kgate/Work/GateCalc
swift build
```

Компиляция должна быть успешной.

**Важно:** UI Tests могут не работать в headless-режиме (без GUI). Если `swift test` выдаёт ошибки, связанные с UI Tests — это нормально. Unit Tests должны проходить.

---

## Этап 9: Финальная проверка и тестирование

### Почему это важно

Перед завершением нужно убедиться, что все исправления работают корректно и не сломали существующую функциональность.

### Шаг 9.1: Запусти все тесты

Открой Terminal и выполни:
```bash
cd /Users/kgate/Work/GateCalc
swift test
```

**Ожидаемый результат:** Все Unit Tests проходят. UI Tests могут не работать в headless-режиме — это допустимо.

**Проверь, что проходят следующие тесты:**
- `testEvaluate_SimpleAddition` — 15+16 = 31
- `testEvaluate_PercentWithAddition` — 100+5% = 100.05
- `testSpecialCase_HexNumber` — 0xFF = 255
- `testSpecialCase_ExponentialNotation` — 1.5e3 = 1500
- `testTokenize_ThousandsSeparator` — 1,000,000 = 1000000
- `testParse_Percent` — процент как деление на 100

---

### Шаг 9.2: Запусти TestRunner

```bash
cd /Users/kgate/Work/GateCalc
swift run TestRunner
```

**Ожидаемый результат:** Все тесты проходят, нет FAIL сообщений.

---

### Шаг 9.3: Проверь структуру проекта

```bash
cd /Users/kgate/Work/GateCalc/Sources
find . -type f -name "*.swift" | sort
```

**Убедись, что есть следующие файлы:**
- `App/CalculatorApp.swift`
- `Views/CalculatorView.swift`
- `Views/DisplayView.swift`
- `Views/CalculatorButton.swift`
- `Views/HistoryPanelView.swift`
- `ViewModels/CalculatorViewModel.swift`
- `Services/HistoryService.swift` (без HistoryEntry)
- `History/HistoryEntry.swift` (новый файл)
- `Clipboard/ClipboardManager.swift` (новый файл)
- `Formatting/NumberFormatterService.swift`
- `Theme/CalculatorColors.swift`
- `Components/EmptyStateView.swift` (новый файл)
- `Extensions/String+Calculator.swift` (новый файл)
- `Extensions/Decimal+Extensions.swift` (новый файл)
- `CalculatorEngine/CalculatorEngine.swift`
- `CalculatorEngine/Tokenizer/Token.swift`
- `CalculatorEngine/Tokenizer/Tokenizer.swift`
- `CalculatorEngine/Parser/Parser.swift`
- `CalculatorEngine/Parser/Precedence.swift`
- `CalculatorEngine/Evaluator/Evaluator.swift`
- `CalculatorEngine/AST/ExpressionNode.swift`
- `CalculatorEngine/Errors/CalculatorError.swift`

---

### Шаг 9.4: Проверь публичные API

Открой Xcode (или используй `swiftc`) и проверь, что следующие типы имеют видимость `public`:
- `CalculatorEngine` — в `Sources/CalculatorEngine/CalculatorEngine.swift`
- `Tokenizer` — в `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`
- `Token` — в `Sources/CalculatorEngine/Tokenizer/Token.swift`
- `BinaryOperator` — в `Sources/CalculatorEngine/Tokenizer/Token.swift`
- `Parser` — в `Sources/CalculatorEngine/Parser/Parser.swift`
- `Evaluator` — в `Sources/CalculatorEngine/Evaluator/Evaluator.swift`
- `ExpressionNode` — в `Sources/CalculatorEngine/AST/ExpressionNode.swift`
- `CalculatorError` — в `Sources/CalculatorEngine/Errors/CalculatorError.swift`
- `ClipboardManager` — в `Sources/Clipboard/ClipboardManager.swift`
- `HistoryEntry` — в `Sources/History/HistoryEntry.swift`
- `EmptyStateView` — в `Sources/Components/EmptyStateView.swift`

---

### Шаг 9.5: Проверь документацию

В Xcode наведи курсор на следующие публичные API:
- `CalculatorEngine` — должно появиться описание "Вычислительный движок калькулятора..."
- `Tokenizer` — должно появиться описание "Токенизатор математических выражений..."
- `Parser` — должно появиться описание "Парсер математических выражений..."
- `Evaluator` — должно появиться описание "Вычислитель абстрактного синтаксического дерева..."
- `CalculatorError` — должно появиться описание "Ошибки вычислительного движка..."

---

### Шаг 9.6: Проверь ручные сценарии

Запусти приложение:
```bash
cd /Users/kgate/Work/GateCalc
swift run CalculatorApp
```

**Проверь вручную:**
1. Приложение запускается без ошибок
2. Дисплей показывает "0"
3. Кнопки работают (цифры, операции, "=", "C")
4. ⌘V вставляет выражение из буфера обмена и вычисляет
5. ⌘C копирует результат в буфер обмена
6. Ошибки отображаются корректно (например, 1/0)
7. История сохраняется и отображается в панели

---

### Шаг 9.7: Проверь специальные случаи

Введи следующие выражения и проверь результаты:

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

---

### Шаг 9.8: Проверь обработку ошибок

Введи следующие выражения и проверь, что появляются корректные сообщения:

| Выражение | Ожидаемое сообщение |
|-----------|---------------------|
| `1/0` | "Division by zero" |
| `15+a` | "Invalid character: a" |
| `(15+16` | "Missing closing parenthesis" |
| `15+16)` | "Extra closing parenthesis" |
| `NaN` | "Invalid expression" |
| `Infinity` | "Invalid expression" |
| `5++3` | "Double operator" |
| (пустое) | "Empty expression" |

---

## Итоговое время выполнения

| Этап | Описание | Время |
|------|----------|-------|
| 1 | Публичные API + Doc Comments | 2-3 часа |
| 2 | Реорганизация структуры проекта | 1-2 часа |
| 3 | Обновление Package.swift | 30 мин |
| 4 | Обновление кода приложения | 1 час |
| 5 | Очистка мёртвого кода в Tokenizer | 30 мин |
| 6 | Локализация | 1 час |
| 7 | Заполнение пустых папок | 1-2 часа |
| 8 | UI Tests | 2-3 часа |
| 9 | Финальная проверка | 2-3 часа |
| **Итого** | | **10-15 часов** |

---

## Частые проблемы и решения

### 1. Ошибка: "Cannot find 'HistoryEntry' in scope"

**Причина:** Определение `HistoryEntry` не удалено из `Sources/Services/HistoryService.swift`.

**Решение:** Удали строки 1-14 из `HistoryService.swift` (всё до `public final class HistoryService`).

### 2. Ошибка: "Cannot find 'ClipboardManager' in scope"

**Причина:** Либо файл `Sources/Clipboard/ClipboardManager.swift` не создан, либо папка `"Clipboard"` не добавлена в `sources` в `Package.swift`.

**Решение:** Проверь наличие файла и проверь `Package.swift` (строки 31-40).

### 3. Ошибка: "Cannot find 'public' in scope"

**Причина:** Используется Swift < 6.0.

**Решение:** Убедись, что `swift-tools-version` в `Package.swift` равен 6.0.

### 4. Тесты не проходят после изменения видимости

**Причина:** Если `Parser` использует `ExpressionNode`, то `ExpressionNode` тоже должен быть public.

**Решение:** Проверь, что все типы, используемые в публичных методах, также имеют `public` видимость.

### 5. UI Tests не работают в headless режиме

**Причина:** UI Tests требуют GUI-сессии (macOS).

**Решение:** Запускай UI Tests только в Xcode с открытым интерфейсом. В CI/CD можно пропустить UI Tests.

### 6. Package.swift не компилируется после добавления новых targets

**Причина:** Опечатка в имени target или пути.

**Решение:** Проверь, что имена targets в `Package.swift` совпадают с именами папок и файлов.

---

## Заключение

После выполнения всех этапов проект будет соответствовать спецификации SRS v1.1 по следующим критериям:

- ✅ Структура проекта соответствует спецификации (раздел 16)
- ✅ Все публичные API имеют правильную видимость и документацию
- ✅ Мёртвый код удалён (DRY)
- ✅ Есть сервис буфера обмена (ClipboardManager)
- ✅ История вынесена в отдельную папку
- ✅ Есть локализация (en, ru)
- ✅ Пустые папки заполнены полезным кодом
- ✅ Есть UI Tests
- ✅ Все Unit Tests проходят
