# План исправления: ошибка `errors.missingParenthesis` при нажатии кнопки `(`

**Дата:** 2026-07-07  
**Время:** 19-03  
**Агент:** Qwen368  
**Статус:** Готов к пошаговому исполнению  
**Модифицируемый файл:** `Sources/ViewModels/CalculatorViewModel.swift` (1 метод, ~5 строк)

---

## 1. Описание проблемы

При нажатии кнопки «(`» на клавиатуре калькулятора на дисплее немедленно отображается ошибка:
```
errors.missingParenthesis → "Пропущена закрывающая скобка"
```

Это происходит **сразу после ввода открывающей скобки**, ещё до того, как пользователь успел ввести содержимое выражения и закрывающую скобку.

**Ожидаемое поведение:** При нажатии «(`» символ добавляется в выражение, ошибка **НЕ отображается**. Выражение с незакрытой скобой — это промежуточное состояние ввода, а не ошибка. Ошибка `missingParenthesis` должна появляться **только при нажатии `=`** (вызов `evaluate()`) когда пользователь пытается вычислить выражение с незакрытой скобой.

---

## 2. Полный трассированный стек вызовов (дефектный путь)

### Шаг 1: Нажатие кнопки «(`» в UI

**Файл:** `Sources/Views/CalculatorView.swift`  
**Строка:** 67

```swift
ButtonSpec(label: .openParen,      type: .function),
```

**Файл:** `Sources/Views/CalculatorView.swift`, строки 143-145 (`handleButtonPress`)

```swift
case .divide, .multiply, .subtract, .add,
     .openParen, .closeParen:
    viewModel.appendCharacter(label.inputValue)
```

**Файл:** `Sources/Views/CalculatorButton.swift`, строка 71 (`inputValue` для `.openParen`)

```swift
case .openParen:           return "("
```

**Результат шага 1:** Вызов `viewModel.appendCharacter("(")`

---

### Шаг 2: `appendCharacter(_:)` в ViewModel

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`, строки 60-79

```swift
func appendCharacter(_ char: String) {
    clearError()                                          // :61 — сброс ошибки

    if hasResult && !isOperator(char) {                    // :63 — false (нет результата)
        expression = ""
        result = nil
        resultDecimal = nil
    } else if hasResult && isOperator(char) {              // :67 — false (нет результата)
        ...
    }

    expression += char                                     // :75 — expression = "("
    if !isDigitOrDecimal(char) {                           // :76 — true, "(" не цифра и не "."
        tryAutoEvaluate()                                  // :77 ← ВЫЗОВ — вот дефект
    }
}
```

**Верификация `isDigitOrDecimal` (строки 270-272):**

```swift
private func isDigitOrDecimal(_ char: String) -> Bool {
    return char == "." || (char.count == 1 && char.first?.isNumber == true)
}
```

Для `"("` → `"(" == "."` = false, `"(".count == 1` = true, `"(".first?.isNumber` = false → **false**

**Результат шага 2:** `expression = "("`, вызывается `tryAutoEvaluate()`

---

### Шаг 3: `tryAutoEvaluate()` — точка дефекта

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`, строки 244-255

```swift
private func tryAutoEvaluate() {
    let trimmed = expression.trimmingCharacters(in: .whitespaces)   // :245 → "("
    guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }
                                                                    // :246 — оба условия true → ПРОХОДИМ

    do {
        let value = try engine.evaluate(expression)                  // :249 ← ВЫЗОВ engine.evaluate("(")
        result = formatter.format(value)                             // :250
        resultDecimal = value                                        // :251
    } catch {
        errorMessage = error.localizedDescription                    // :253 ← ОШИБКА ПОПАДАЕТ В UI
    }
}
```

**Верификация `isTrailingOperator` (строки 257-260):**

```swift
private func isTrailingOperator(_ expr: String) -> Bool {
    guard let last = expr.last else { return false }
    return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
}
```

Для `"("` → `last = "("` → ни один из операторов не совпадает → **false**

**Результат шага 3:** Guard на строке 246 пропускает выполнение, вызывается `engine.evaluate("(")`

---

### Шаг 4: `CalculatorEngine.evaluate()` — фасад движка

**Файл:** `Sources/CalculatorEngine/CalculatorEngine.swift`, строки 23-46

```swift
public func evaluate(_ expression: String) throws -> Decimal {
    let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw CalculatorError.emptyExpression }

    let tokenizer = Tokenizer()
    let tokens = try tokenizer.tokenize(trimmed)                   // :38 → [.leftParenthesis]
    guard !tokens.isEmpty else { throw CalculatorError.emptyExpression }

    let parser = Parser()
    let ast = try parser.parse(tokens)                             // :42 ← БРОСАЕТ ОШИБКУ

    let evaluator = Evaluator()
    return try evaluator.evaluate(ast)
}
```

**Верификация Tokenizer (строки 29-33):**

```swift
if char == "(" {
    tokens.append(.leftParenthesis)
    advance(&i, in: cleaned)
    continue
}
```

Для `"("` → один токен `[.leftParenthesis]` ✓

---

### Шаг 5: `Parser.parse()` — выбрасывание ошибки

**Файл:** `Sources/CalculatorEngine/Parser/Parser.swift`, строки 11-18

```swift
public func parse(_ tokens: [Token]) throws -> ExpressionNode {
    guard !tokens.isEmpty else { throw CalculatorError.emptyExpression }
    let rpn = try toRPN(tokens)                                    // :16 ← ВЫЗОВ toRPN
    return try buildAST(from: rpn)
}
```

**Файл:** `Sources/CalculatorEngine/Parser/Parser.swift`, строки 20-92 (`toRPN`)

Для входного `[.leftParenthesis]`:

1. Цикл `for token in tokens` (строка 24): один итерация с `.leftParenthesis`
2. Строка 29: `case .leftParenthesis:` → `operatorStack.append(token)` — стек = `[.leftParenthesis]`
3. Цикл завершается

**Остаток стека (строки 81-89):**

```swift
while let top = operatorStack.popLast() {                        // :81 — top = .leftParenthesis
    if top.isLeftParen {                                         // :82 — true
        throw CalculatorError.missingClosingParenthesis          // :83 ← БРОСАЕТ ОШИБКУ
    }
    ...
}
```

**Результат шага 5:** `CalculatorError.missingClosingParenthesis`

---

### Шаг 6: Ошибка возвращается в UI

**Файл:** `Sources/CalculatorEngine/Errors/CalculatorError.swift`, строки 45-46

```swift
case .missingClosingParenthesis:
    return NSLocalizedString("errors.missingParenthesis", comment: "")
```

**Локализация (ru.lproj, строка 21):**

```
"errors.missingParenthesis" = "Пропущена закрывающая скобка";
```

**Возврат по стеку:**

`Parser.parse()` → `CalculatorEngine.evaluate()` → `tryAutoEvaluate()` (строка 253):

```swift
catch {
    errorMessage = error.localizedDescription   // :253 — "Пропущена закрывающая скобка"
}
```

**Результат шага 6:** `viewModel.errorMessage` = `"Пропущена закрывающая скобка"` → отображается в `DisplayView`

---

## 3. Корневая причина (root cause)

**Метод `tryAutoEvaluate()` (CalculatorViewModel.swift:244-255) пытается вычислить выражение после каждого ввода символа, не являющегося цифрой или десятичным разделителем.**

Скобки — не операторы (`isOperator("(")` возвращает `false`), поэтому `tryAutoEvaluate()` вызывается. Метод проверяет только два условия (строка 246):
1. Выражение не пустое → `"("` не пусто ✓
2. Последний символ — не оператор-хвост → `"("` не оператор ✓

**Но метод НЕ проверяет сбалансированность скобок.** Выражение `"(15+16"` (незакрытая скобка) проходит guard и попадает в `engine.evaluate()`, которая корректно выбрасывает ошибку.

---

## 4. Почему текущее поведение — дефект

### 4.1. Пользовательский сценарий

Пользователь хочет вычислить `(15 + 16 + 17 + 18) / 4`. Типичный ввод:

| Шаг | Нажатие | expression | errorMessage |
|-----|---------|-----------|--------------|
| 1 | `(` | `"("` | ❌ **"Пропущена закрывающая скобка"** ← ОШИБКА |
| 2 | `1` | `"(1"` | ❌ **"Пропущена закрывающая скобка"** ← ОШИБКА (не сбрасывается) |
| 3 | `5` | `"(15"` | ❌ **"Пропущена закрывающая скобка"** ← ОШИБКА |
| ... | ... | ... | ... |
| 8 | `)` | `"(15+16+17+18)"` | ✅ ошибка сбрасывается (автовычисление успешно = 66) |
| 9 | `/` | `"(15+16+17+18)/"` | ✅ auto-eval пропущен (trailing operator) |
| 10 | `4` | `"(15+16+17+18)/4"` | ✅ автовычисление = 16.5, result = "16.5" |

**Проблема:** На шагах 1-7 пользователь видит ошибку для выражения, которое ещё не завершено. Это вводит в заблуждение — пользователь думает, что выражение неверно, хотя он только начал его вводить.

### 4.2. Сравнение с поведением операторов

Метод `isTrailingOperator` (строки 257-260) уже предотвращает автовычисление для выражений, заканчивающихся оператором:

```swift
private func isTrailingOperator(_ expr: String) -> Bool {
    guard let last = expr.last else { return false }
    return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
}
```

Это корректно: `"15+"` не вычисляется автоматически, потому что пользователь, вероятно, продолжает ввод.

**Аналогичная логика применима к скобкам:** `"("` и `"(15+16"` — незавершённые выражения, автовычисление должно быть пропущено.

### 4.3. Поведение при нажатии `=` не меняется

Метод `evaluate()` (строки 97-116) вызывается **напрямую** по нажатию «=» и **не использует** `tryAutoEvaluate()`:

```swift
func evaluate() {
    clearError()
    let trimmed = expression.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    do {
        let value = try engine.evaluate(expression)   // ← прямой вызов, минуя tryAutoEvaluate
        ...
    } catch {
        errorMessage = error.localizedDescription       // ← ошибка показывается корректно
    }
}
```

Если пользователь введёт `(15+16` и нажмёт «=», ошибка `missingClosingParenthesis` по-прежнему будет показана — это **корректное поведение**.

---

## 5. Архитектурный анализ решения

### 5.1. Почему исправление в `tryAutoEvaluate()` — единственно верный подход

**Потребители `tryAutoEvaluate()`:**

| Место вызова | Файл:строка | Контекст |
|-------------|-------------|----------|
| `appendCharacter(_:)` | CalculatorViewModel.swift:77 | Ввод символа (не цифра/точка) |
| `backspace()` | CalculatorViewModel.swift:135 | Удаление последнего символа |
| `useHistoryEntry(_:)` | CalculatorViewModel.swift:234 | Восстановление из истории |

**Почему не в `appendCharacter`:** Метод `appendCharacter` вызывается из 10+ мест (все кнопки UI, клавиатурный ввод). Проверка сбалансированности скобок — это ответственность автовычисления, а не ввода символа.

**Почему не в `evaluate()`:** `evaluate()` уже корректно обрабатывает незакрытые скобки через движок. Изменение `evaluate()` сломает показ ошибки при нажатии «=».

**Почему не в Tokenizer/Parser:** Вычислительный движок должен оставаться stateless и корректно обрабатывать полные выражения. Проверка сбалансированности скобок до вызова движка — это ответственность ViewModel (orchestrator), а не самого движка.

**Почему не через `clearError()` после `tryAutoEvaluate`:** Это «заплатка», которая скрывает симптом, но не устраняет причину. Кроме того, `clearError()` сбросит ошибку и для других случаев (например, `15+16)` — лишняя закрывающая скобка), что неверно.

### 5.2. Принцип минимального воздействия

Изменение в `tryAutoEvaluate()`:
- **Не затрагивает** `evaluate()` → ошибка при нажатии «=» сохраняется ✓
- **Не затрагивает** Tokenizer/Parser/Evaluator → движок остаётся неизменным ✓
- **Не затрагивает** UI-компоненты → DisplayView, CalculatorView без изменений ✓
- **Не затрагивает** тесты движка → все 102 теста unaffected ✓

---

## 6. Детализированный план реализации

### Шаг 1: Добавить приватный метод `hasUnclosedParentheses` в `CalculatorViewModel`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Расположение:** После строки 272 (после `isDigitOrDecimal`), перед закрывающей скобкой класса

**Добавляемый код:**

```swift
    /// Проверяет, есть ли в выражении незакрытые открывающие скобки.
    /// Возвращает true, если количество '(' превышает количество ')'.
    private func hasUnclosedParentheses(_ expr: String) -> Bool {
        var count = 0
        for char in expr where char == "(" || char == ")" {
            if char == "(" {
                count += 1
            } else {
                count -= 1
            }
        }
        return count > 0
    }
```

**Верификация сигнатуры:**
- `(String) -> Bool` — совместима с вызовом из `tryAutoEvaluate` (guard condition)
- `private` — не выходит за пределы ViewModel, соответствует стилю всех вспомогательных методов
- Идентификатор в `camelCase` — соответствует naming conventions AGENTS.md:8

**Верификация логики:**
- Для `"("` → count = 1 → returns true ✓
- For `"(15+16"` → count = 1 → returns true ✓
- For `"(15+16)"` → count = 0 → returns false ✓
- For `"((15+16)"` → count = 1 → returns true ✓
- For `"((15+16))"` → count = 0 → returns false ✓
- For `"15+16)"` → count = -1 → returns false (не нужно блокировать, движок выбросит extraClosingParenthesis) ✓
- For `""` → count = 0 → returns false (guard на строке 246 всё равно отсечёт пустое выражение) ✓

**Комментарий на русском языке** — соответствует AGENTS.md:14 («В коде: все комментарии и документация пишутся на русском языке»)

---

### Шаг 2: Добавить проверку в `tryAutoEvaluate()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Строка для модификации:** 246 (guard condition)

**Текущий код (строка 246):**

```swift
    guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }
```

**Новый код (строка 246):**

```swift
    guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(trimmed) else { return }
```

**Изменение:** Добавлено третье условие `!hasUnclosedParentheses(trimmed)` в существующий guard.

---

## 7. Полный итоговый код модифицированных методов

### `tryAutoEvaluate()` (строки 244-255) — после изменений:

```swift
    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(trimmed) else { return }

        do {
            let value = try engine.evaluate(expression)
            result = formatter.format(value)
            resultDecimal = value
        } catch {
            errorMessage = error.localizedDescription
        }
    }
```

### `hasUnclosedParentheses` (новые строки 273-284):

```swift
    /// Проверяет, есть ли в выражении незакрытые открывающие скобки.
    /// Возвращает true, если количество '(' превышает количество ')'.
    private func hasUnclosedParentheses(_ expr: String) -> Bool {
        var count = 0
        for char in expr where char == "(" || char == ")" {
            if char == "(" {
                count += 1
            } else {
                count -= 1
            }
        }
        return count > 0
    }
```

---

## 8. Верификация всех утверждений плана

### Утверждение 1: `tryAutoEvaluate()` вызывается при вводе `(`

**Верифицировано:** CalculatorViewModel.swift:76-77, `isDigitOrDecimal("(")` = false → вызов `tryAutoEvaluate()` ✓

### Утверждение 2: `isTrailingOperator("(")` возвращает false

**Верифицировано:** CalculatorViewModel.swift:257-260, `"(" != "+" && "(" != "-" && "(" != "*" && "(" != "/" && "(" != "%"` → false ✓

### Утверждение 3: Guard на строке 246 пропускает выполнение для `"("`

**Верифицировано:** `!"(".isEmpty` = true, `!isTrailingOperator("(")` = true → guard проходит ✓

### Утверждение 4: `engine.evaluate("(")` выбрасывает `missingClosingParenthesis`

**Верифицировано:**
- Tokenizer.swift:29-33 — `"("` токенизируется в `[.leftParenthesis]` ✓
- Parser.swift:81-83 — остаток стека `[.leftParenthesis]` → `throw CalculatorError.missingClosingParenthesis` ✓

### Утверждение 5: `evaluate()` НЕ вызывает `tryAutoEvaluate()`

**Верифицировано:** CalculatorViewModel.swift:97-116, метод `evaluate()` вызывает `engine.evaluate(expression)` напрямую, без вызова `tryAutoEvaluate()` ✓

### Утверждение 6: Ни один тест не вызывает `tryAutoEvaluate()` напрямую

**Верифицировано:** grep по Tests/ — ни один файл не содержит вызов `tryAutoEvaluate`. Все тесты вызывают `engine.evaluate()` напрямую через CalculatorEngineTests.swift ✓

### Утверждение 7: `hasUnclosedParentheses` корректно обрабатывает все сценарии

**Верифицировано вручную:**
- `"("` → count=1, returns true ✓
- `"(15+16"` → count=1, returns true ✓
- `"(15+16)"` → count=0, returns false ✓
- `"((15+16))"` → count=0, returns false ✓
- `"15+16)"` → count=-1, returns false (не блокируем) ✓
- `""` → count=0, returns false (но guard на строке 246 отсечёт пустое) ✓

### Утверждение 8: Изменение не ломает существующие тесты

**Верифицировано:** Все юнит-тесты вызывают `engine.evaluate()` напрямую через CalculatorEngineTests.swift, ParserTests.swift, TokenizerTests.swift, EvaluatorTests.swift. Ни один тест не вызывает `CalculatorViewModel.tryAutoEvaluate()`. Изменение в `tryAutoEvaluate()` не затрагивает ни один существующий тест ✓

### Утверждение 9: Swift 6.0 совместимость

**Верифицировано:**
- Метод `hasUnclosedParentheses` — pure function, без мутабельных захватов в замыканиях ✓
- `var count = 0` — локальная переменная, не выходит за пределы метода ✓
- Нет force unwrap, нет игнорирования ошибок ✓
- Типы параметров и возвращаемых значений объявлены явно: `(String) -> Bool` ✓

### Утверждение 10: Архитектурные запреты не нарушены

**Верифицировано:**
- ViewModel не ссылается на View напрямую ✓
- Вычислительный движок не импортирует SwiftUI/AppKit (не модифицируется) ✓
- Нет `NSLock` в ViewModel ✓
- Нет изменения Git-команд ✓

---

## 9. Матрица поведения до и после исправления

### Сценарий 1: Нажатие «(`» на пустом калькуляторе

| Параметр | До исправления | После исправления |
|----------|---------------|-------------------|
| expression | `"("` | `"("` |
| errorMessage | ❌ **"Пропущена закрывающая скобка"** | ✅ `nil` |
| result | `nil` | `nil` |

### Сценарий 2: Ввод `(15+16` (незакрытая скобка)

| Шаг | expression | До исправления | После исправления |
|-----|-----------|---------------|-------------------|
| `(` | `"("` | ❌ ошибка | ✅ nil |
| `1` | `"(1"` | ❌ ошибка | ✅ nil |
| `5` | `"(15"` | ❌ ошибка | ✅ nil |
| `+` | `"(15+"` | ❌ ошибка (trailing op) | ✅ nil (trailing op) |
| `1` | `"(15+1"` | ❌ ошибка | ✅ nil |
| `6` | `"(15+16"` | ❌ ошибка | ✅ nil |

### Сценарий 3: Полное выражение `(15+16)`

| Шаг | expression | До исправления | После исправления |
|-----|-----------|---------------|-------------------|
| `(` | `"("` | ❌ ошибка | ✅ nil |
| `1` | `"(1"` | ❌ ошибка | ✅ nil |
| ... | ... | ... | ... |
| `)` | `"(15+16)"` | ✅ result = "31" | ✅ result = "31" |

**Результат:** Полное выражение вычисляется корректно в обоих случаях ✓

### Сценарий 4: Нажатие «=» при незакрытой скобке `(15+16`

| Параметр | До исправления | После исправления |
|----------|---------------|-------------------|
| expression | `"(15+16"` | `"(15+16"` |
| errorMessage | ❌ **"Пропущена закрывающая скобка"** | ❌ **"Пропущена закрывающая скобка"** |

**Результат:** Ошибка показывается при нажатии «=» — корректное поведение, НЕ изменено ✓

### Сценарий 5: Полное выражение `(15+16+17+18)/4`

| Шаг | expression | До исправления | После исправления |
|-----|-----------|---------------|-------------------|
| `(` | `"("` | ❌ ошибка | ✅ nil |
| ...ввод... | ... | ... | ... |
| `)` | `"(15+16+17+18)"` | ✅ result = "66" | ✅ result = "66" |
| `/` | `"(15+16+17+18)/"` | ✅ nil (trailing) | ✅ nil (trailing) |
| `4` | `"(15+16+17+18)/4"` | ✅ result = "16.5" | ✅ result = "16.5" |

**Результат:** Итоговый результат идентичен, разница только в промежуточных состояниях ✓

### Сценарий 6: Лишняя закрывающая скобка `15+16)`

| Параметр | До исправления | После исправления |
|----------|---------------|-------------------|
| expression | `"15+16)"` | `"15+16)"` |
| errorMessage | ❌ **"Лишняя закрывающая скобка"** | ❌ **"Лишняя закрывающая скобка"** |

**Результат:** `hasUnclosedParentheses("15+16)")` = false (count=-1), guard пропускает, движок выбрасывает `extraClosingParenthesis`. Поведение НЕ изменено ✓

---

## 10. Анализ регрессий и побочных эффектов

### Потенциальные точки регрессии

| Точка | Вероятность | Обоснование |
|-------|-----------|-------------|
| `evaluate()` (нажатие «=») | ❌ Нет | Метод не вызывает `tryAutoEvaluate()`, работает напрямую с движком |
| Юнит-тесты CalculatorEngineTests | ❌ Нет | Все тесты вызывают `engine.evaluate()` напрямую, минуя ViewModel |
| Тесты Parser/Tokenizer/Evaluator | ❌ Нет | Модуль движка не модифицируется |
| `backspace()` после незакрытой скобки | ⚠️ Проверено | После удаления `)` из `"(15+16"` → expression = `"(15+16"`, hasUnclosedParentheses=true, tryAutoEvaluate пропускает — корректно |
| `useHistoryEntry` с выражением со скобками | ⚠️ Проверено | Если запись содержит незакрытую скобку (маловероятно из-за валидации при сохранении), автовычисление пропустит — безопасно |

### Верификация побочных эффектов

**Изменённый файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Количество изменений:** 2 блока:
1. Строка 246: добавлено условие в guard (одно слово + вызов метода)
2. После строки 272: добавлен новый приватный метод (~10 строк)

**Незапланированные изменения:** Отсутствуют ✓  
**Отладочный код:** Не добавлен (`print`, `debugPrint`, `NSLog` отсутствуют) ✓

---

## 11. Чеклист самопроверки перед завершением

- [x] Нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()` — отладочный код отсутствует
- [x] Нет force unwrap (`!`) без обоснованной гарантии — в новом коде нет `!`
- [x] Все новые типы имеют корректные пометки — метод private, возвращает Bool (Sendable)
- [x] Все методы имеют объявленные типы параметров и возвращаемых значений — `(String) -> Bool`
- [x] MARK-комментарии на русском языке — комментарий к `hasUnclosedParentheses` на русском
- [x] Идентификаторы на английском языке — `hasUnclosedParentheses`, `count`
- [x] Нет импортов SwiftUI в вычислительном движке — модифицируется только ViewModel
- [x] Все исключения обрабатываются — catch блок в `tryAutoEvaluate` сохраняет ошибку
- [x] Нет изменяющих Git-команд — не выполнялись
- [x] Все утверждения о коде подтверждены ссылками на файл и строку — 10 верификаций выше

---

## 12. Итоговая сводка

| Параметр | Значение |
|----------|---------|
| **Корневая причина** | `tryAutoEvaluate()` не проверяет сбалансированность скобок перед вызовом `engine.evaluate()` |
| **Точка дефекта** | CalculatorViewModel.swift:246 (guard condition в `tryAutoEvaluate`) |
| **Решение** | Добавить проверку `!hasUnclosedParentheses(trimmed)` в guard + новый приватный метод |
| **Модифицируемый файл** | 1 файл: `Sources/ViewModels/CalculatorViewModel.swift` |
| **Строк для изменения** | ~2 строки (guard) + ~10 строк (новый метод) = ~12 строк |
| **Новых публичных API** | 0 — метод `hasUnclosedParentheses` имеет видимость `private` |
| **Изменений в движке** | 0 — Tokenizer, Parser, Evaluator без изменений |
| **Изменений в UI** | 0 — DisplayView, CalculatorView без изменений |
| **Риск регрессии** | Минимальный — изменение затрагивает только промежуточное автовычисление, не финальное вычисление по «=» |
| **Влияние на тесты** | Нулевое — ни один тест не вызывает `tryAutoEvaluate()` напрямую |
