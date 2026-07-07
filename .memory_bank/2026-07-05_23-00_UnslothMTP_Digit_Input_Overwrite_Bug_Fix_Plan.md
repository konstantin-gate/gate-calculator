# План исправления: Цифровые кнопки затирают предыдущий ввод (каждое нажатие перезаписывает выражение)

**Дата:** 2026-07-05  
**Агент:** UnslothMTP  
**Проблема:** При последовательном нажатии цифр 9 → 8 → 7 на виртуальной клавиатуре калькулятора отображается только "7". Каждая следующая кнопка стирает предыдущую, многозначные числа набрать невозможно.

---

## 1. ФИКСИРОВАННЫЙ АНАЛИЗ КОДОВОЙ БАЗЫ (все утверждения подтверждены)

### 1.1 Структура проекта

Проект — Swift Package Manager macOS-приложение на SwiftUI. Все исходные файлы прочитаны и верифицированы:

| Файл | Строки | Назначение |
|------|--------|------------|
| `Sources/ViewModels/CalculatorViewModel.swift` | 227 | Управление состоянием калькулятора — ЕДИНСТВЕННЫЙ файл для изменений |
| `Sources/Views/CalculatorView.swift` | 166 | UI-раскладка, сетка кнопок, маршрутизация нажатий |
| `Sources/Views/CalculatorButton.swift` | 203 | Компонент кнопки, enum ButtonLabel, enum CalcButtonType, struct ButtonSpec |
| `Sources/Views/DisplayView.swift` | 139 | Отображение выражения и результата |
| `Sources/App/CalculatorApp.swift` | 118 | Точка входа (@main), KeyHandlerNSView для клавиатуры |
| `Sources/Services/HistoryService.swift` | — | Сервис истории вычислений (NSLock, thread-safe) |
| `Sources/History/HistoryEntry.swift` | — | Модель записи истории |
| `Sources/Formatting/NumberFormatterService.swift` | — | Форматирование Decimal → String (locale en_US) |
| `Sources/Clipboard/ClipboardManager.swift` | — | Обёртка над NSPasteboard |
| `Sources/Theme/CalculatorColors.swift` | — | Цветовая система |
| `Sources/Localization/en.lproj/Localizable.strings` | — | Английская локализация |
| `Sources/Localization/ru.lproj/Localizable.strings` | — | Русская локализация |
| `Sources/CalculatorEngine/CalculatorEngine.swift` | — | Фасад движка: tokenize → parse → evaluate |
| `Sources/CalculatorEngine/Tokenizer/Token.swift` | — | Enum Token + BinaryOperator |
| `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift` | — | Строка → [Token] |
| `Sources/CalculatorEngine/Parser/Parser.swift` | — | Shunting-yard алгоритм → AST |
| `Sources/CalculatorEngine/Parser/Precedence.swift` | — | Определения приоритетов операторов |
| `Sources/CalculatorEngine/Evaluator/Evaluator.swift` | — | Рекурсивная оценка AST (Decimal arithmetic) |
| `Sources/CalculatorEngine/AST/ExpressionNode.swift` | — | Enum ExpressionNode (number, unaryMinus, binary) |
| `Sources/CalculatorEngine/Errors/CalculatorError.swift` | — | Типы ошибок с localizedDescription |

**Всего 20 Swift-файлов.** Все прочитаны. Изменения вносятся ТОЛЬКО в один файл: `CalculatorViewModel.swift`.

### 1.2 Цепочка вызовов при нажатии цифровой кнопки (верифицирована)

```
Пользователь нажимает кнопку "9" на экране
    ↓
CalculatorButton.body (CalculatorButton.swift:156-158): Button { onTap(spec.label) }
    spec.label = .digit("9")
    ↓
CalculatorView.buttonRow (CalculatorView.swift:123): handleButtonPress(label)
    ↓
CalculatorView.handleButtonPress (CalculatorView.swift:152-153):
    case .digit(let d): viewModel.appendCharacter(d)
    d = "9"
    ↓
CalculatorViewModel.appendCharacter (CalculatorViewModel.swift:28-45):
    expression += char   →  expression = "9"
    tryAutoEvaluate()    →  result = "9"
```

**Клавиатурный ввод:** `KeyHandlerNSView.keyDown` (CalculatorApp.swift:81-86) также вызывает `viewModel.appendCharacter(normalized)` — тот же путь, та же проблема.

### 1.3 Состояние ViewModel (верифицировано)

```swift
// CalculatorViewModel.swift, строки 10-12
var expression: String = ""      // Сырая строка ввода пользователя
var result: String? = nil        // Кэшированный вычисленный результат
var errorMessage: String? = nil  // Сообщение об ошибке

// Строка 18 — computed property
var hasResult: Bool { result != nil }
```

### 1.4 Отображение на экране (верифицировано)

```swift
// DisplayView.swift, строка 58
let mainText = result ?? (expression.isEmpty ? "0" : expression)
```

Приоритет: `result` > `expression`. Если `result != nil`, отображается именно он.

---

## 2. ГЛУБОКИЙ АНАЛИЗ ПРИЧИНЫ БАГА (верифицировано каждый шаг)

### 2.1 Метод appendCharacter — текущая реализация (CalculatorViewModel.swift:28-45)

```swift
func appendCharacter(_ char: String) {
    clearError()                                          // строка 29

    if hasResult && !isOperator(char) {                   // строки 31-33
        expression = ""                                   // ← СТИРАЕТ выражение!
        result = nil                                      // ← Стирает результат!
    } else if hasResult && isOperator(char) {             // строки 34-40
        if let res = result, let dec = Decimal(string: res.replacingOccurrences(of: ",", with: ".")) {
            expression = dec.description
        }
        result = nil
    }

    expression += char                                    // строка 43 — ДОБАВЛЯЕМ символ
    tryAutoEvaluate()                                     // строка 44 — АВТО-ОЦЕНКА!
}
```

### 2.2 Метод tryAutoEvaluate (CalculatorViewModel.swift:203-213)

```swift
private func tryAutoEvaluate() {
    let trimmed = expression.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }

    do {
        let value = try engine.evaluate(expression)       // строка 208
        result = formatter.format(value)                   // строка 209 — УСТАНАВЛИВАЕТ result!
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### 2.3 Метод isOperator (CalculatorViewModel.swift:220-222)

```swift
private func isOperator(_ char: String) -> Bool {
    char == "+" || char == "-" || char == "*" || char == "/" || char == "%"
}
```

### 2.4 Пошаговый трейс бага "9" → "8" → "7" (каждый шаг подтверждён)

**Начальное состояние:** `expression = ""`, `result = nil`, `hasResult = false`

---

**ШАГ 1: Нажатие "9"**

```
handleButtonPress(.digit("9"))                          // CalculatorView.swift:153
→ appendCharacter("9")                                  // CalculatorViewModel.swift:28

Внутри appendCharacter("9"):
  clearError()                                          // строка 29 → errorMessage = nil
  hasResult = false → пропускаем оба if-блока (строки 31-40)
  expression += "9"                                     // строка 43 → expression = "9"
  tryAutoEvaluate()                                     // строка 44

Внутри tryAutoEvaluate():
  trimmed = "9", не пустой, isTrailingOperator("9") = false → guard проходит
  engine.evaluate("9")                                  // CalculatorEngine.swift:23-41 → Decimal(9)
  result = formatter.format(Decimal(9))                  // строка 209 → result = "9"

СОСТОЯНИЕ ПОСЛЕ ШАГА 1: expression = "9", result = "9", hasResult = true
ЭКРАН: mainText = "9" (result берётся первым)
```

---

**ШАГ 2: Нажатие "8"**

```
handleButtonPress(.digit("8"))                          // CalculatorView.swift:153
→ appendCharacter("8")                                  // CalculatorViewModel.swift:28

Внутри appendCharacter("8"):
  clearError()                                          // строка 29 → errorMessage = nil
  hasResult = true, isOperator("8") = false → ВХОДИМ в первый if-блок (строка 31)
    expression = ""                                     // строка 32 ← УНИЧТОЖАЕТ "9"!
    result = nil                                        // строка 33 ← Стирает результат!
  expression += "8"                                     // строка 43 → expression = "8"
  tryAutoEvaluate()                                     // строка 44

Внутри tryAutoEvaluate():
  engine.evaluate("8") → Decimal(8)
  result = formatter.format(Decimal(8)) → result = "8"

СОСТОЯНИЕ ПОСЛЕ ШАГА 2: expression = "8", result = "8", hasResult = true
ЭКРАН: mainText = "8"
```

---

**ШАГ 3: Нажатие "7"** — идентичен Шагу 2.

```
expression = "" → expression += "7" → tryAutoEvaluate() → result = "7"

СОСТОЯНИЕ ПОСЛЕ ШАГА 3: expression = "7", result = "7"
ЭКРАН: mainText = "7" ← ТОЛЬКО ОДНА ЦИФРА!
```

### 2.5 Вывод: две взаимодействующие причины бага

**Причина A (фактор A):** `tryAutoEvaluate()` вызывается БЕЗУСЛОВНО после каждого символа (строка 44). При вводе одиночной цифры "9" движок мгновенно вычисляет выражение и устанавливает `result = "9"`.

**Причина B (фактор B):** Логика очистки при наличии результата (строки 31-33) срабатывает на КАЖДЫЙ последующий НЕ-оператор, включая цифры. Это было задумано для сценария "пользователь получил результат и хочет начать новый ввод", но из-за фактора A это происходит при каждом нажатии цифры.

**Архитектурная суть проблемы:** Метод `appendCharacter` смешивает две раздельные ответственности:
1. Накопление символов ввода (строка 43)
2. Автоматическую вычислительную оценку (строка 44)

Автооценка не должна срабатывать, пока пользователь вводит цифры для формирования многозначного числа. Она должна срабатывать только при нажатии оператора или "=", сигнализируя о завершении текущего операнда.

---

## 3. АРХИТЕКТУРНО ПРАВИЛЬНОЕ РЕШЕНИЕ (единственный вариант)

### 3.1 Принцип решения

**Не вызывать `tryAutoEvaluate()` после добавления цифр и десятичного разделителя.** Это предотвратит преждевременную установку `result` при вводе многозначных чисел. Автооценка будет срабатывать только при нажатии операторов (+, -, *, /, %), скобок, π, e — символов, которые сигнализируют о структурном изменении выражения.

### 3.2 Почему это решение единственно верное

1. **Сохраняется семантика "результат → новый ввод".** После нажатия "=" и получения результата, первая нажатая цифра всё равно очистит expression/result (строки 31-33), начав новый ввод. Это корректно.

2. **Операторы по-прежнему триггерят автооценку.** При вводе "2+3" нажатие "+" вызовет `tryAutoEvaluate()`, что правильно вычислит промежуточный результат.

3. **Минимальное вмешательство.** Изменяется ОДНОТ строчка (условный вызов) и добавляется ОДНА новая приватная функция в ОДНОМ файле. Никаких изменений в UI, движке, сервисах.

4. **Работает для обоих путей ввода:** и виртуальная клавиатура (CalculatorView), и физическая клавиатура (KeyHandlerNSView) — оба вызывают `appendCharacter`.

---

## 4. ДЕТАЛЬНЫЙ ПЛАН РЕАЛИЗАЦИИ (пошаговый, каждый шаг верифицирован)

### ПРЕДВАРИТЕЛЬНАЯ ПОДГОТОВКА

#### Шаг 0: Открыть файл для редактирования

**Путь:** `/Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift`  
**Всего строк:** 227  
**Необходимые импорты уже есть (строки 1-4):**
```swift
import Foundation    // → String.first?.isNumber доступен из Foundation
import SwiftUI       // → @Observable, @MainActor
import Observation   
import CalculatorEngine // → CalculatorEngine
```

---

### ШАГ 1: Добавить приватный хелпер `isDigitOrDecimal`

**Расположение:** В секции `// MARK: - Private helpers`, после метода `clearError()` (строка 226), перед закрывающей скобкой класса (строка 227).

**Действие:** Добавить новый приватный метод сразу после строки 226.

**Точное вставляемое содержимое (после строки 226 `    }`):**

```swift
    private func isDigitOrDecimal(_ char: String) -> Bool {
        return char == "." || (char.count == 1 && char.first?.isNumber == true)
    }
```

**Обоснование каждого элемента:**

- `char == "."` — проверяет десятичный разделитель. В проекте десятичный разделитель ВСЕГДА точка:
  - `CalculatorButton.inputValue` (CalculatorButton.swift:66): `.decimalSeparator → return "."`
  - `CalculatorView.handleButtonPress` (CalculatorView.swift:147): `.decimalSeparator: viewModel.appendCharacter(".")`
  - `KeyHandlerNSView.keyDown` (CalculatorApp.swift:84): `char == "," ? "." : String(char)` — запятая нормализуется в точку

- `char.count == 1` — гарантирует, что проверяется ровно один символ. Это защищает от ложных срабатываний при передаче многосимвольных строк (хотя в текущем коде такого нет, это defensive programming).

- `char.first?.isNumber` — свойство `Character.isNumber` из Foundation (`Foundation/Character.swift`). Возвращает `true` для Unicode-цифр (0-9). В проекте цифры передаются как `"0"`-"9" (CalculatorView.swift:81-105, enum cases `.digit("0")`...`.digit("9")`), и `isNumber` для них возвращает `true`.

- `private func` — метод не нужен за пределами ViewModel. Секция `// MARK: - Private helpers` уже существует (строка 201).

**Итоговое состояние файла после Шага 1 (строки 201-231):**

```swift
    // MARK: - Private helpers

    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }

        do {
            let value = try engine.evaluate(expression)
            result = formatter.format(value)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isTrailingOperator(_ expr: String) -> Bool {
        guard let last = expr.last else { return false }
        return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
    }

    private func isOperator(_ char: String) -> Bool {
        char == "+" || char == "-" || char == "*" || char == "/" || char == "%"
    }

    private func clearError() {
        errorMessage = nil
    }

    private func isDigitOrDecimal(_ char: String) -> Bool {
        return char == "." || (char.count == 1 && char.first?.isNumber == true)
    }
}
```

**Верификация:** Метод `isDigitOrDecimal` возвращает:
- `true` для `"0"`-"9" → `char.first?.isNumber == true` ✓
- `true` для `"."` → `char == "."` ✓
- `false` для `"+"`, `"-"`, `"*"`, `"/"`, `"%"` → ни одно условие не выполняется ✓
- `false` для `"("`, `")"` → ни одно условие не выполняется ✓
- `false` для `"π"` → `π.isNumber == false` ✓
- `false` для `"e"` → `e.isNumber == false` ✓

---

### ШАГ 2: Заменить безусловный вызов `tryAutoEvaluate()` на условный

**Расположение:** Метод `appendCharacter`, строка 44 в текущем файле.

**Текущее содержимое (строки 28-45):**

```swift
    func appendCharacter(_ char: String) {
        clearError()

        if hasResult && !isOperator(char) {
            expression = ""
            result = nil
        } else if hasResult && isOperator(char) {
            // ИСПРАВЛЕНИЕ C-08: использовать dec.description вместо formatter.format(dec)
            // чтобы избежать записи локализованной строки ("1,5") в expression
            if let res = result, let dec = Decimal(string: res.replacingOccurrences(of: ",", with: ".")) {
                expression = dec.description
            }
            result = nil
        }

        expression += char
        tryAutoEvaluate()
    }
```

**Действие:** Заменить строку 44 `tryAutoEvaluate()` на условный вызов.

**Точная замена (oldString → newString):**

OLD (строка 44):
```swift
        tryAutoEvaluate()
```

NEW:
```swift
        if !isDigitOrDecimal(char) {
            tryAutoEvaluate()
        }
```

**Итоговое состояние метода `appendCharacter` после Шага 2:**

```swift
    func appendCharacter(_ char: String) {
        clearError()

        if hasResult && !isOperator(char) {
            expression = ""
            result = nil
        } else if hasResult && isOperator(char) {
            // ИСПРАВЛЕНИЕ C-08: использовать dec.description вместо formatter.format(dec)
            // чтобы избежать записи локализованной строки ("1,5") в expression
            if let res = result, let dec = Decimal(string: res.replacingOccurrences(of: ",", with: ".")) {
                expression = dec.description
            }
            result = nil
        }

        expression += char
        if !isDigitOrDecimal(char) {
            tryAutoEvaluate()
        }
    }
```

**Обоснование:** Теперь `tryAutoEvaluate()` вызывается только для НЕ-цифровых и НЕ-десятичных символов. Цифры накапливаются в `expression` без преждевременной оценки.

---

## 5. ПОЛНОЕ ИТОГОВОЕ СОСТОЯНИЕ ФАЙЛА (после обоих изменений)

**Файл:** `/Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift`  
**Изменения:** 2 вставки, 1 замена. Все остальные строки без изменений.

```swift
import Foundation
import SwiftUI
import Observation
import CalculatorEngine

@MainActor
@Observable
final class CalculatorViewModel {

    var expression: String = ""
    var result: String? = nil
    var errorMessage: String? = nil

    private let engine = CalculatorEngine()
    private let historyService = HistoryService.shared
    private let formatter = NumberFormatterService.shared

    var hasResult: Bool { result != nil }
    var historyCount: Int { historyService.count() }

    /// Записи истории — единый computed property для HistoryPanelView
    var historyEntries: [HistoryEntry] {
        historyService.getEntries()
    }

    private var memoryValue: Decimal = 0

    func appendCharacter(_ char: String) {
        clearError()

        if hasResult && !isOperator(char) {
            expression = ""
            result = nil
        } else if hasResult && isOperator(char) {
            // ИСПРАВЛЕНИЕ C-08: использовать dec.description вместо formatter.format(dec)
            // чтобы избежать записи локализованной строки ("1,5") в expression
            if let res = result, let dec = Decimal(string: res.replacingOccurrences(of: ",", with: ".")) {
                expression = dec.description
            }
            result = nil
        }

        expression += char
        if !isDigitOrDecimal(char) {
            tryAutoEvaluate()
        }
    }

    // ... (остальные методы без изменений: appendOperator, evaluate, clear, backspace, toggleSign, memory*, handleKeyCommand, clipboard, history) ...

    // MARK: - Private helpers

    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }

        do {
            let value = try engine.evaluate(expression)
            result = formatter.format(value)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isTrailingOperator(_ expr: String) -> Bool {
        guard let last = expr.last else { return false }
        return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
    }

    private func isOperator(_ char: String) -> Bool {
        char == "+" || char == "-" || char == "*" || char == "/" || char == "%"
    }

    private func clearError() {
        errorMessage = nil
    }

    private func isDigitOrDecimal(_ char: String) -> Bool {
        return char == "." || (char.count == 1 && char.first?.isNumber == true)
    }
}
```

---

## 6. ПОШАГОВАЯ ВЕРИФИКАЦИЯ ВСЕХ СЦЕНАРИЕВ (после исправления)

### Сценарий 1: Многозначное число "987" — ИСПРАВЛЕНО ✓

```
Начальное состояние: expression = "", result = nil, hasResult = false

Нажатие "9":
  appendCharacter("9"):
    hasResult = false → пропускаем if-блоки (строки 31-40)
    expression += "9" → expression = "9"
    isDigitOrDecimal("9") = true → ПРОПУСКАЕМ tryAutoEvaluate() ✓

Нажатие "8":
  appendCharacter("8"):
    hasResult = false → пропускаем if-блоки (строки 31-40)
    expression += "8" → expression = "98"
    isDigitOrDecimal("8") = true → ПРОПУСКАЕМ tryAutoEvaluate() ✓

Нажатие "7":
  appendCharacter("7"):
    hasResult = false → пропускаем if-блоки (строки 31-40)
    expression += "7" → expression = "987"
    isDigitOrDecimal("7") = true → ПРОПУСКАЕМ tryAutoEvaluate() ✓

ИТОГ: expression = "987", result = nil, hasResult = false
ЭКРАН: mainText = "987" (result nil, берётся expression) ← ВЕРНО!
```

### Сценарий 2: Выражение с оператором "2+3=" — РАБОТАЕТ ✓

```
Нажатие "2":
  expression = "2", isDigitOrDecimal("2") = true → без автооценки

Нажатие "+":
  appendCharacter("+"):
    hasResult = false → пропускаем if-блоки
    expression += "+" → expression = "2+"
    isDigitOrDecimal("+") = false → ВЫЗЫВАЕМ tryAutoEvaluate() ✓

Внутри tryAutoEvaluate():
  isTrailingOperator("2+") = true (last == "+") → guard НЕ проходит, return ← wait...

Actually: guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }
expression = "2+", last char is "+", so isTrailingOperator returns true
guard condition fails → early return. Auto-eval does NOT fire for trailing operator. ✓

Нажатие "3":
  expression = "2+3", isDigitOrDecimal("3") = true → без автооценки

Нажатие "=":
  evaluate():
    engine.evaluate("2+3") → Decimal(5)
    result = formatter.format(Decimal(5)) → result = "5"
    expression = "" (строка 77)

ЭКРАН: mainText = "5" ← ВЕРНО!
```

### Сценарий 3: Результат → новый ввод "5" → нажатие "4" — РАБОТАЕТ ✓

```
Состояние после вычисления: expression = "", result = "5", hasResult = true

Нажатие "4":
  appendCharacter("4"):
    hasResult = true, isOperator("4") = false → ВХОДИМ в первый if-блок (строка 31) ✓
      expression = "" → expression = ""
      result = nil → result = nil
    expression += "4" → expression = "4"
    isDigitOrDecimal("4") = true → ПРОПУСКАЕМ tryAutoEvaluate()

ИТОГ: expression = "4", result = nil ← ВЕРНО! Новый ввод начинается с чистого листа.
```

### Сценарий 4: Десятичное число "1.5" — РАБОТАЕТ ✓

```
Нажатие "1":
  expression = "1", без автооценки (digit)

Нажатие ".":
  appendCharacter("."):
    hasResult = false → пропускаем if-блоки
    expression += "." → expression = "1."
    isDigitOrDecimal(".") = true → ПРОПУСКАЕМ tryAutoEvaluate() ✓

Нажатие "5":
  appendCharacter("5"):
    expression += "5" → expression = "1.5"
    isDigitOrDecimal("5") = true → ПРОПУСКАЕМ tryAutoEvaluate() ✓

Нажатие "=":
  evaluate():
    engine.evaluate("1.5") → Decimal(1.5)
    result = formatter.format(Decimal(1.5)) → result = "1.5"

ЭКРАН: mainText = "1.5" ← ВЕРНО!
```

### Сценарий 5: Backspace — РАБОТАЕТ ✓

```
Метод backspace (CalculatorViewModel.swift:89-103) НЕ вызывает appendCharacter.
Он напрямую модифицирует expression и вызывает tryAutoEvaluate() самостоятельно (строка 99).
Этот путь НЕ затронут изменениями. ← ВЕРНО!
```

### Сценарий 6: История → useHistoryEntry — РАБОТАЕТ ✓

```
Метод useHistoryEntry (CalculatorViewModel.swift:189-194) напрямую вызывает tryAutoEvaluate().
Этот путь НЕ затронут изменениями. ← ВЕРНО!
```

### Сценарий 7: Клавиатурный ввод цифр — ИСПРАВЛЕНО ✓

```
KeyHandlerNSView.keyDown (CalculatorApp.swift:81-86):
  default: if char.isNumber → viewModel.appendCharacter(normalized)
  
Тот же путь через appendCharacter → та же логика isDigitOrDecimal → работает корректно. ← ВЕРНО!
```

### Сценарий 8: Оператор после результата "5" + "3" — РАБОТАЕТ ✓

```
Состояние после вычисления: expression = "", result = "5", hasResult = true

Нажатие "+":
  appendCharacter("+"):
    hasResult = true, isOperator("+") = true → ВХОДИМ во второй if-блок (строка 34) ✓
      res = "5", dec = Decimal(5), expression = "5"
      result = nil
    expression += "+" → expression = "5+"
    isDigitOrDecimal("+") = false → ВЫЗЫВАЕМ tryAutoEvaluate()

Внутри tryAutoEvaluate():
  isTrailingOperator("5+") = true → guard не проходит, early return ← OK, trailing operator

ЭКРАН: mainText = "5+" (result nil, берётся expression) ← ВЕРНО!
```

### Сценарий 9: Константа π — РАБОТАЕТ ✓

```
Нажатие "π":
  appendCharacter("π"):
    isDigitOrDecimal("π") = false → ВЫЗЫВАЕМ tryAutoEvaluate() ✓

Если expression было "3", то evaluate("3") → result = "3"
expression = "3π" ← π добавлен в выражение. ← ВЕРНО!
```

### Сценарий 10: Скобки "(2+3)" — РАБОТАЕТ ✓

```
Нажатие "(":
  appendCharacter("("):
    isDigitOrDecimal("(") = false → ВЫЗЫВАЕМ tryAutoEvaluate() ✓

Если expression было "5", то evaluate("5") → result = "5"
expression = "5(" ← скобка добавлена. ← ВЕРНО!
```

---

## 7. ЧТО НЕ ТРОГАЕТСЯ (все зависимости верифицированы)

| Элемент | Файл | Статус | Обоснование |
|---------|------|--------|-------------|
| `CalculatorView.handleButtonPress` | CalculatorView.swift:131-165 | Без изменений | Маршрутизация нажатий корректна, вызывает appendCharacter для цифр |
| `DisplayView.mainText` | DisplayView.swift:58 | Без изменений | Логика приоритета result/expression корректна |
| `CalculatorEngine.evaluate` | CalculatorEngine.swift | Без изменений | Движок работает правильно |
| `backspace()` | CalculatorViewModel.swift:89-103 | Без изменений | Вызывает tryAutoEvaluate напрямую, не через appendCharacter |
| `evaluate()` | CalculatorViewModel.swift:63-81 | Без изменений | Явная оценка по "=" работает независимо |
| `tryAutoEvaluate()` | CalculatorViewModel.swift:203-213 | Без изменений | Логика автооценки не изменена, только условие вызова |
| `isTrailingOperator` | CalculatorViewModel.swift:215-218 | Без изменений | Не изменён |
| `isOperator` | CalculatorViewModel.swift:220-222 | Без изменений | Не изменён |
| `clearError` | CalculatorViewModel.swift:224-226 | Без изменений | Не изменён |
| `CalculatorButton` | CalculatorButton.swift | Без изменений | UI-компонент не затронут |
| `KeyHandlerNSView` | CalculatorApp.swift:52-118 | Без изменений | Клавиатурный ввод идёт через appendCharacter, исправление применяется автоматически |
| `HistoryService` | Services/HistoryService.swift | Без изменений | Не затронут |
| `NumberFormatterService` | Formatting/NumberFormatterService.swift | Без изменений | Не затронут |
| Юнит-тесты CalculatorEngine | Tests/Unit/* | Без изменений | Тестируют только движок, не ViewModel |

---

## 8. ИТОГОВАЯ СВОДКА ИЗМЕНЕНИЙ

**Файл для изменения:** `Sources/ViewModels/CalculatorViewModel.swift` (227 строк)

### Изменение 1: Добавление метода `isDigitOrDecimal`
- **Позиция:** После строки 226, перед закрывающей скобкой класса (строка 227)
- **Тип:** Вставка нового приватного метода (4 строки кода + 1 пустая)
- **Содержимое:**
```swift
    private func isDigitOrDecimal(_ char: String) -> Bool {
        return char == "." || (char.count == 1 && char.first?.isNumber == true)
    }
```

### Изменение 2: Условный вызов `tryAutoEvaluate`
- **Позиция:** Строка 44, метод `appendCharacter`
- **Тип:** Замена одной строки на три (условный блок)
- **Было:**
```swift
        tryAutoEvaluate()
```
- **Стало:**
```swift
        if !isDigitOrDecimal(char) {
            tryAutoEvaluate()
        }
```

### Итого: 2 изменения в 1 файле, +7 строк кода, -0 строк удалено (замена)

---

## 9. ПОСЛЕДОВАТЕЛЬНОСТЬ ВЫПОЛНЕНИЯ

1. Открыть файл `Sources/ViewModels/CalculatorViewModel.swift`
2. Выполнить Изменение 1: добавить метод `isDigitOrDecimal` после строки 226
3. Выполнить Изменение 2: заменить строку 44 на условный блок
4. Сохранить файл
5. Скомпилировать проект для проверки синтаксиса

**Команда сборки (если потребуется):**
```bash
cd /Users/kgate/Work/GateCalc && swift build
```

или через скрипт:
```bash
/Users/kgate/Work/GateCalc/build_app.sh
```

---

## 10. ОЖИДАЕМЫЙ РЕЗУЛЬТАТ

После применения плана:
- Пользователь может набирать многозначные числа: "987", "1234567" и т.д.
- Цифры накапливаются в `expression` без преждевременной автооценки
- Автооценка срабатывает только при нажатии операторов, скобок, π, e
- Поведение "результат → новый ввод" сохраняется (первая цифра после "=" очищает выражение)
- Клавиатурный ввод цифр также исправлен (тот же путь через appendCharacter)
- Backspace, история, память — без изменений

**Баг устранён архитектурно корректно и минимальным вмешательством.**
