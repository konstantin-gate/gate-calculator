# План исправления: ошибка `errors.missingParenthesis` при нажатии кнопки `(`

**Дата:** 2026-07-07  
**Агент:** Qwen36  
**Проект:** GateCalc — macOS-калькулятор (Swift 6.0, SwiftUI, MVVM)

---

## 1. Описание проблемы

### 1.1. Сценарий воспроизведения

1. Пользователь нажимает кнопку `(` на клавиатуре калькулятора
2. Символ `(` добавляется в выражение на дисплее
3. Немедленно отображается ошибка: `errors.missingParenthesis` («Пропущена закрывающая скобка»)
4. Пользователь видит ошибку для выражения, которое он ещё только вводит

### 1.2. Ожидаемое поведение

При нажатии `(` символ добавляется в выражение, ошибка **НЕ отображается**. Выражение с незакрытой скобой — это промежуточное состояние ввода, а не ошибка. Ошибка `missingParenthesis` должна появляться **только** при нажатии `=` (вызов `evaluate()`) когда выражение с незакрытой скобой пытается вычислиться.

Пример корректного сценария:
```
Пользователь вводит: ( 1 5 + 1 6 ) / 4 =
Результат: 7.75
```

На промежуточных этапах `( 1 5 + 1 6 ) / 4` — ошибок быть не должно.

---

## 2. Глубокий анализ (Deep Analysis)

### 2.1. Полный поток данных от нажатия `(` до отображения ошибки

**Шаг 1: Нажатие кнопки `(` в UI**

Файл: `Sources/Views/CalculatorView.swift:143-145`
```swift
case .divide, .multiply, .subtract, .add,
     .openParen, .closeParen:
    viewModel.appendCharacter(label.inputValue)
```

`ButtonLabel.openParen.inputValue` возвращает `"("` (CalculatorButton.swift:71).

**Шаг 2: `appendCharacter` в ViewModel**

Файл: `Sources/ViewModels/CalculatorViewModel.swift:60-79`
```swift
func appendCharacter(_ char: String) {
    clearError()                              // строка 61: errorMessage = nil

    if hasResult && !isOperator(char) {       // строка 63: hasResult = false, пропускаем
        expression = ""
        result = nil
        resultDecimal = nil
    } else if hasResult && isOperator(char) { // строка 67: hasResult = false, пропускаем
        // ...
    }

    expression += char                        // строка 75: expression = "("
    if !isDigitOrDecimal(char) {              // строка 76: "(" не цифра → true
        tryAutoEvaluate()                     // строка 77: ВЫЗОВ tryAutoEvaluate()
    }
}
```

**Шаг 3: `tryAutoEvaluate`**

Файл: `Sources/ViewModels/CalculatorViewModel.swift:244-255`
```swift
private func tryAutoEvaluate() {
    let trimmed = expression.trimmingCharacters(in: .whitespaces)  // trimmed = "("
    guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }
    // trimmed = "(" → не пустой
    // isTrailingOperator("(") → false ( "(" не в ["+", "-", "*", "/", "%"] )
    // guard проходит → выполняем тело

    do {
        let value = try engine.evaluate(expression)  // строка 249: engine.evaluate("(")
        result = formatter.format(value)
        resultDecimal = value
    } catch {
        errorMessage = error.localizedDescription     // строка 253: errorMessage = "Пропущена закрывающая скобка"
    }
}
```

**Шаг 4: `engine.evaluate("(")` — вычислительный движок**

Файл: `Sources/CalculatorEngine/CalculatorEngine.swift:233-246`
```swift
public func evaluate(_ expression: String) throws -> Decimal {
    let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw CalculatorError.emptyExpression }

    let tokenizer = Tokenizer()
    let tokens = try tokenizer.tokenize(trimmed)   // tokens = [.leftParenthesis]

    let parser = Parser()
    let ast = try parser.parse(tokens)             // ← ОШИБКА ЗДЕСЬ

    let evaluator = Evaluator()
    return try evaluator.evaluate(ast)
}
```

**Шаг 5: `Tokenizer.tokenize("(")` — успешно**

Файл: `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift:29-32`
```swift
if char == "(" {
    tokens.append(.leftParenthesis)
    advance(&i, in: cleaned)
    continue
}
```

Результат: `[.leftParenthesis]` — успешно, ошибок нет.

**Шаг 6: `Parser.parse([.leftParenthesis])` — ошибка**

Файл: `Sources/CalculatorEngine/Parser/Parser.swift:11-17`
```swift
public func parse(_ tokens: [Token]) throws -> ExpressionNode {
    guard !tokens.isEmpty else {
        throw CalculatorError.emptyExpression
    }
    let rpn = try toRPN(tokens)   // ← ОШИБКА ЗДЕСЬ
    return try buildAST(from: rpn)
}
```

Файл: `Sources/CalculatorEngine/Parser/Parser.swift:20-91`
```swift
private func toRPN(_ tokens: [Token]) throws -> [Token] {
    var output: [Token] = []
    var operatorStack: [Token] = []

    for token in tokens {              // token = .leftParenthesis
        switch token {
        case .leftParenthesis:
            operatorStack.append(token)  // строка 30: stack = [.leftParenthesis]
        // ... другие кейсы не срабатывают
        }
    }

    // ИСПРАВЛЕНИЕ C-05b: остаток стека
    while let top = operatorStack.popLast() {  // строка 81: top = .leftParenthesis
        if top.isLeftParen {                    // строка 82: true
            throw CalculatorError.missingClosingParenthesis  // строка 83: ← ОШИБКА
        }
        // ...
    }
}
```

**Шаг 7: Ошибка возвращается в UI**

Файл: `Sources/ViewModels/CalculatorViewModel.swift:253`
```swift
catch {
    errorMessage = error.localizedDescription  // errorMessage = "Пропущена закрывающая скобка"
}
```

Файл: `Sources/CalculatorEngine/Errors/CalculatorError.swift:51-53`
```swift
case missingClosingParenthesis
// ...
errorDescription: NSLocalizedString("errors.missingParenthesis", comment: "")
```

Файл: `Sources/Localization/ru.lproj/Localizable.strings:21`
```
"errors.missingParenthesis" = "Пропущена закрывающая скобка";
```

### 2.2. Корень проблемы (Root Cause)

**Метод `tryAutoEvaluate()` (CalculatorViewModel.swift:244-255) вызывает `engine.evaluate()` для выражения `"("`, которое заведомо неполное.**

`tryAutoEvaluate()` проверяет только два условия (CalculatorViewModel.swift:246):
1. `!trimmed.isEmpty` — выражение не пустое ✅
2. `!isTrailingOperator(expression)` — выражение не заканчивается оператором ✅

Но **не проверяет** наличие незакрытых скобок. Выражение `"("` проходит оба guard-условия, но оно не является полным математическим выражением.

### 2.3. Почему текущие проверки не срабатывают

**`isTrailingOperator` (CalculatorViewModel.swift:257-260):**
```swift
private func isTrailingOperator(_ expr: String) -> Bool {
    guard let last = expr.last else { return false }
    return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
}
```

Проверяет только 5 символов-операторов. `"("` не входит в этот список → возвращает `false`.

**Дизайн `isTrailingOperator` корректен** — он блокирует автовычисление при `15+`, `15*` и т.д. Но он не покрывает случай незакрытых скобок, потому что скобки — это не операторы в контексте trailing-проверки (скобки меняют приоритет, а не завершают операцию).

### 2.4. Почему исправление в вычислительном движке — неправильный подход

Рассмотрены альтернативные подходы:

**Альтернатива 1: Изменить `Tokenizer` — не бросать ошибку при `(`**
- ❌ Нарушит контракты `TokenizerTests` (testTokenize_Parentheses: строка 30-34)
- ❌ Нарушит `ParserTests` (testParse_MissingClosingParenthesis: строка 108-117)
- ❌ Нарушит `CalculatorEngineTests` (testError_MissingParenthesis: строка 203-205)
- ❌ `(` сам по себе — валидный токен, ошибка выбрасывается на этапе парсинга, а не токенизации
- ❌ Нарушит архитектуру MVVM: вычислительный движок корректно определяет неполные выражения

**Альтернатива 2: Изменить `Parser` — не бросать ошибку при незакрытой скобе в стеке**
- ❌ Парсер — stateless компонент вычислительного движка, его задача — валидировать полные выражения
- ❌ `Parser.parse()` вызывается только из `CalculatorEngine.evaluate()`
- ❌ При вызове `evaluate()` (пользователь нажал `=`) ошибка **должна** выбрасываться — это корректное поведение
- ❌ Изменение парсера сломает все 12 тестов `ParserTests`

**Альтернатива 3: Изменить `CalculatorEngine.evaluate()` — не бросать ошибку при незакрытой скобе**
- ❌ `testError_MissingParenthesis` (CalculatorEngineTests.swift:203-205) ожидает ошибку
- ❌ `testEvaluate_AllErrorCases` (CalculatorEngineTests.swift:260-274) ожидает ошибку для `"(15+16"`
- ❌ Нарушит SRS: выражение `"(15+16"` должно давать ошибку при вычислении

**Вывод:** Все альтернативы, связанные с изменением вычислительного движка, нарушают существующие тесты и контракты. Решение должно быть в ViewModel.

---

## 3. Архитектурное обоснование решения

### 3.1. Почему исправление в `tryAutoEvaluate()` — единственно верный подход

**Разделение ответственности (AGENTS.md §6.1, Technical_Documentation.md §2.3):**

| Слой | Ответственность |
|---|---|
| `CalculatorEngine` | Вычисление **полных** математических выражений → Decimal |
| `CalculatorViewModel` | Управление состоянием приложения, **фильтрация** запросов к движку |
| `CalculatorView` | Визуализация, передача нажатий |

`tryAutoEvaluate()` — часть ViewModel. Его задача — попытаться показать предварительный результат для **полных** выражений. Выражение с незакрытой скобой — заведомо неполное.

**Аналогичный паттерн уже существует:**
```swift
// CalculatorViewModel.swift:246
guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }
```

`isTrailingOperator()` — аналогичная проверка: выражение `"15+"` — неполное (оператор ожидает правый операнд). Новый чек: выражение с незакрытой скобой — неполное (скобка ожидает закрывающую скобу и содержимое).

### 3.2. Слой, затрагиваемый изменением

Только один файл: `Sources/ViewModels/CalculatorViewModel.swift`

- Не затрагивается `CalculatorEngine` (вычислительный движок)
- Не затрагиваются `Tokenizer`, `Parser`, `Evaluator`
- Не затрагиваются `Views` (CalculatorView, CalculatorButton, DisplayView)
- Не затрагиваются тесты (все тесты работают с `engine.evaluate()` напрямую)
- Не затрагивается локализация
- Не затрагивается `HistoryService`, `ClipboardManager`, `NumberFormatterService`

### 3.3. Потенциальные регрессии

**Анализ всех потребителей `tryAutoEvaluate()`:**

1. `appendCharacter(_:)` (CalculatorViewModel.swift:77)
   - `tryAutoEvaluate()` вызывается при не-цифровом символе
   - Новые выражения: `(`, `(`, `(5+`, `((15+16)`
   - Все эти выражения с незакрытыми скобками — неполные → автовычисление не нужно
   - ✅ Нет регрессии

2. `backspace()` (CalculatorViewModel.swift:135)
   - `tryAutoEvaluate()` вызывается после удаления символа
   - Пример: выражение `(5+3)`, backspace → `(5+`. Незакрытая скоба → автовычисление не нужно
   - ✅ Нет регрессии

3. `useHistoryEntry(_:)` (CalculatorViewModel.swift:234)
   - `tryAutoEvaluate()` вызывается при восстановлении из истории
   - Записи в истории добавляются только при успешном вычислении (CalculatorViewModel.swift:108)
   - Полные выражения из истории не могут иметь незакрытых скобок
   - ✅ Нет регрессии

---

## 4. Детализированный план реализации

### Шаг 1: Добавить приватный метод `hasUnclosedParentheses(_:)`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Позиция:** раздел `// MARK: - Private helpers`, после `isDigitOrDecimal` (строка 272), перед закрывающей скобкой класса (строка 273)

**Добавить метод:**

```swift
    private func hasUnclosedParentheses(_ expr: String) -> Bool {
        var count = 0
        for char in expr {
            if char == "(" { count += 1 }
            else if char == ")" { count -= 1 }
            if count < 0 { return false }
        }
        return count > 0
    }
```

**Обоснование реализации:**

- `count` отслеживает баланс: `+1` за `(`, `-1` за `)`
- Если `count < 0` — есть лишняя закрывающая скобка `)`. Это не наша проверка (это обрабатывается движком как `extraClosingParenthesis`). Возвращаем `false` — автовычисление не блокируем.
- Если `count > 0` после прохода — есть незакрытые `(`. Возвращаем `true` — блокируем автовычисление.
- Если `count == 0` — все скобки закрыты. Возвращаем `false` — автовычисление разрешено.

**Верификация сигнатуры:**
- Параметр `expr: String` — тип совпадает с `expression` (CalculatorViewModel.swift:10)
- Возвращаемый тип `Bool` — стандартный Swift тип
- Видимость `private` — совпадает с другими helper-методами в классе
- Метод не использует внешние зависимости — только локальная переменная `count` и цикл по строке

**Тестирование метода (ментальные тесты):**

| Вход | `count` после прохода | Возврат | Обоснование |
|---|---|---|---|
| `"("` | 1 | `true` | Одна незакрытая `(` |
| `"(5+3"` | 1 | `true` | Одна незакрытая `(` |
| `"((5+3"` | 2 | `true` | Две незакрытые `(` |
| `"(5+3)"` | 0 | `false` | Скобки сбалансированы |
| `"(5+3)*(2+1)"` | 0 | `false` | Все скобки сбалансированы |
| `")"` | -1 → `false` | `false` | Лишняя `)`, не наша проверка |
| `"5+3"` | 0 | `false` | Нет скобок |
| `""` | 0 | `false` | Пустая строка |

### Шаг 2: Добавить проверку в `tryAutoEvaluate()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Позиция:** строка 246, guard-условие

**Было (строка 246):**
```swift
    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }
```

**Стало (строка 246):**
```swift
    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(expression) else { return }
```

**Изменение:** добавлено `, !hasUnclosedParentheses(expression)` в guard-условие.

**Логика guard-условия (все три условия должны быть true для продолжения):**

| `!trimmed.isEmpty` | `!isTrailingOperator` | `!hasUnclosedParentheses` | Результат |
|---|---|---|---|
| true | true | true | Продолжить (полное выражение) |
| true | true | false | Вернуться (незакрытая скоба) |
| true | false | true | Вернуться (trailing operator) |
| true | false | false | Вернуться (trailing operator + unclosed paren) |
| false | — | — | Вернуться (пустое выражение) |

**Примеры поведения после исправления:**

| Выражение | `isEmpty` | `isTrailingOp` | `unclosedParen` | Автовычисление? |
|---|---|---|---|---|
| `"("` | false | false | **true** | ❌ НЕТ |
| `"(5+3"` | false | false | **true** | ❌ НЕТ |
| `"((15+16"` | false | false | **true** | ❌ НЕТ |
| `"(5+3)"` | false | false | false | ✅ ДА → 8 |
| `"(5+3)*2"` | false | false | false | ✅ ДА → 14 |
| `"15+"` | false | **true** | false | ❌ НЕТ |
| `"15+3"` | false | false | false | ✅ ДА → 18 |

### Шаг 3: Верификация — отсутствие изменений в других файлах

**Не изменять:**
- `Sources/CalculatorEngine/` — все файлы (Tokenizer, Parser, Evaluator, AST, Errors, CalculatorEngine.swift)
- `Sources/Views/` — все файлы (CalculatorView, CalculatorButton, DisplayView, HistoryPanelView)
- `Sources/ViewModels/CalculatorViewModel.swift` — кроме Шагов 1 и 2
- `Sources/Localization/` — все файлы
- `Sources/Services/` — все файлы
- `Sources/Clipboard/` — все файлы
- `Sources/Formatting/` — все файлы
- `Sources/Theme/` — все файлы
- `Sources/History/` — все файлы
- `Sources/App/` — все файлы
- `Tests/` — все файлы
- `Package.swift`
- `build_app.sh`

---

## 5. Проверка существующих тестов

### 5.1. Тесты, которые НЕ затронуты изменением

Все юнит-тесты вызывают `engine.evaluate()` напрямую, минуя `tryAutoEvaluate()`:

- `Tests/Unit/TokenizerTests.swift` — 27 тестов, все через `tokenizer.tokenize()`
- `Tests/Unit/ParserTests.swift` — 12 тестов, все через `parser.parse()`
- `Tests/Unit/EvaluatorTests.swift` — 17 тестов, все через `evaluator.evaluate()`
- `Tests/Unit/CalculatorEngineTests.swift` — 45 тестов, все через `engine.evaluate()`

**Ни один тест не вызывает `CalculatorViewModel.tryAutoEvaluate()` напрямую.**

### 5.2. Конкретные тесты с скобками

- `testTokenize_Parentheses` (TokenizerTests.swift:30-34) — `tokenizer.tokenize("(15+16)")` → 5 токенов. ✅ Не затронут.
- `testParse_Parentheses` (ParserTests.swift:42-63) — `parser.parse([leftParen, 15, +, 16, rightParen, *, 5])`. ✅ Не затронут.
- `testParse_MissingClosingParenthesis` (ParserTests.swift:108-117) — `parser.parse([leftParen, 15, +, 16])` → ошибка. ✅ Не затронут.
- `testParse_ExtraClosingParenthesis` (ParserTests.swift:119-128) — `parser.parse([15, +, 16, rightParen])` → ошибка. ✅ Не затронут.
- `testParse_NestedParentheses` (ParserTests.swift:141-170) — `parser.parse(...)` → AST. ✅ Не затронут.
- `testEvaluate_ParenthesesOverridePrecedence` (CalculatorEngineTests.swift:37-40) — `engine.evaluate("(15+16)*5")` → 155. ✅ Не затронут.
- `testEvaluate_NestedParentheses` (CalculatorEngineTests.swift:42-46) — `engine.evaluate("((15+16)*5)/3")`. ✅ Не затронут.
- `testError_MissingParenthesis` (CalculatorEngineTests.swift:203-205) — `engine.evaluate("(15+16")` → ошибка. ✅ Не затронут.
- `testError_ExtraParenthesis` (CalculatorEngineTests.swift:207-209) — `engine.evaluate("15+16)")` → ошибка. ✅ Не затронут.
- `testEvaluate_AllErrorCases` (CalculatorEngineTests.swift:260-274) — включает `"(15+16"`. ✅ Не затронут.
- `testEvaluate_MainScenario` (CalculatorEngineTests.swift:233-236) — `engine.evaluate("(15+16+17+18)/4")` → 16.5. ✅ Не затронут.
- `testSpecialCase_EqualsAtEnd` (CalculatorEngineTests.swift:183-186) — `engine.evaluate("(15+16)/4=")` → 7.75. ✅ Не затронут.

### 5.3. Интеграционные сценарии

- `testEvaluate_AllSpecialCases` (CalculatorEngineTests.swift:238-258) — все выражения полные, все скобки закрыты. ✅ Не затронут.

---

## 6. Проверка потокобезопасности (Swift 6.0 Concurrency)

### 6.1. Анализ изменений с точки зрения Swift 6.0

Метод `hasUnclosedParentheses(_:)`:
- `private` — видимость только внутри `CalculatorViewModel`
- `CalculatorViewModel` помечен `@MainActor` (CalculatorViewModel.swift:6)
- Все вызовы метода происходят на главном потоке
- Метод не имеет общего состояния — только локальная переменная `count`
- Метод не возвращает `Sendable`-типы — только `Bool`
- Метод не взаимодействует с внешними ресурсами

**Вывод:** изменение полностью потокобезопасно. Нет новых `Sendable`-маркировок, нет `NSLock`, нет `actor`.

### 6.2. Guard-условие в `tryAutoEvaluate()`

- `tryAutoEvaluate()` вызывается из `appendCharacter` (MainActor) и `backspace` (MainActor)
- `expression` — свойство `@MainActor`-класса, доступ только с главного потока
- `hasUnclosedParentheses(expression)` — локальная проверка, нет гонки данных

**Вывод:** нет нарушений Swift 6.0 Concurrency.

---

## 7. Проверка Naming Conventions (AGENTS.md §8)

| Элемент | Стиль | Пример | Соответствие |
|---|---|---|---|
| Метод | `camelCase` | `hasUnclosedParentheses` | ✅ |
| Параметр | `camelCase` | `expr` | ✅ |
| Идентификаторы в коде | `camelCase` | `count` | ✅ |

---

## 8. Чеклист самопроверки (AGENTS.md §13)

- [x] Нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()` (отладочный код)
- [x] Нет force unwrap (`!`) без обоснованной гарантии
- [x] Все новые типы имеют `Sendable` (если используются вне `@MainActor`) — не требуется, метод `private` в `@MainActor`-классе
- [x] Все методы имеют объявленные типы параметров и возвращаемых значений — `hasUnclosedParentheses(_ expr: String) -> Bool`
- [x] MARK-комментарии на русском языке — не требуется, метод добавлен в существующий раздел
- [x] Идентификаторы на английском языке — `hasUnclosedParentheses`, `expr`, `count`
- [x] Нет импортов SwiftUI в вычислительном движке — изменения только в ViewModel
- [x] Все исключения обрабатываются — не требуется, метод не бросает ошибки
- [x] Нет изменяющих Git-команд
- [x] Все утверждения о коде подтверждены ссылками на файл и строку

---

## 9. Финальная сводка изменений

### 9.1. Модифицируемый файл

**`Sources/ViewModels/CalculatorViewModel.swift`**

### 9.2. Изменение 1: Добавить метод `hasUnclosedParentheses`

**Позиция:** после строки 272 (`isDigitOrDecimal`), перед закрывающей скобкой класса (строка 273)

```swift
    private func hasUnclosedParentheses(_ expr: String) -> Bool {
        var count = 0
        for char in expr {
            if char == "(" { count += 1 }
            else if char == ")" { count -= 1 }
            if count < 0 { return false }
        }
        return count > 0
    }
```

### 9.3. Изменение 2: Обновить guard в `tryAutoEvaluate`

**Позиция:** строка 246

**Было:**
```swift
        guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }
```

**Стало:**
```swift
        guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(expression) else { return }
```

### 9.4. Итоговый вид файла (изменённые участки)

**`tryAutoEvaluate` (строки 244-255):**
```swift
    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(expression) else { return }

        do {
            let value = try engine.evaluate(expression)
            result = formatter.format(value)
            resultDecimal = value
        } catch {
            errorMessage = error.localizedDescription
        }
    }
```

**Новый метод (после строки 272):**
```swift
    private func hasUnclosedParentheses(_ expr: String) -> Bool {
        var count = 0
        for char in expr {
            if char == "(" { count += 1 }
            else if char == ")" { count -= 1 }
            if count < 0 { return false }
        }
        return count > 0
    }
}
```

---

## 10. Сценарий после исправления

### 10.1. Пользовательский сценарий

```
Нажатие: (
  expression = "("
  errorMessage = nil  ← больше не устанавливается
  Отображение: "(" на дисплее, без ошибки

Нажатие: 1 5
  expression = "(15"
  errorMessage = nil
  Отображение: "(15" на дисплее, без ошибки

Нажатие: +
  expression = "(15+"
  errorMessage = nil
  Отображение: "(15+" на дисплее, без ошибки (trailing operator блокирует автовычисление)

Нажатие: 1 6 )
  expression = "(15+16)"
  errorMessage = nil
  tryAutoEvaluate: hasUnclosedParentheses("(15+16)") = false → автовычисление → result = "31"
  Отображение: выражение "(15+16", результат "31"

Нажатие: /
  expression = "31/"
  errorMessage = nil
  Отображение: "31/" на дисплее (trailing operator)

Нажатие: 4
  expression = "31/4"
  tryAutoEvaluate: hasUnclosedParentheses("31/4") = false → автовычисление → result = "7.75"
  Отображение: выражение "31/4", результат "7.75"

Нажатие: =
  expression = ""
  result = "7.75"
  Отображение: "7.75"
```

### 10.2. Сценарий ошибки (корректное поведение)

```
Нажатие: ( 1 5 + 1 6
  expression = "(15+16"
  errorMessage = nil  ← нет ошибки при вводе

Нажатие: = (evaluate)
  engine.evaluate("(15+16") → Parser выбрасывает missingClosingParenthesis
  errorMessage = "Пропущена закрывающая скобка"
  Отображение: "Пропущена закрывающая скобка"
```

Это **корректное поведение**: ошибка появляется только при явном вызове `evaluate()` (пользователь нажал `=`), а не при вводе символов.

---

## 11. Объём изменений

| Метрика | Значение |
|---|---|
| Файлов для изменения | 1 |
| Строк для добавления | 9 (метод `hasUnclosedParentheses`) |
| Строк для модификации | 1 (guard в `tryAutoEvaluate`) |
| Строк для удаления | 0 |
| Новых файлов | 0 |
| Удаление файлов | 0 |
| Изменение тестов | 0 |
| Изменение локализации | 0 |
| Изменение вычислительного движка | 0 |
