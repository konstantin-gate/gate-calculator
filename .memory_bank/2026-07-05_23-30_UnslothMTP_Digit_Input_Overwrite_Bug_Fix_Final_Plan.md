# Финальный план исправления: затирание цифр при последовательном вводе (9→8→7 → "7")

**Дата:** 2026-07-05  
**Время подготовки:** 23:30  
**Агент:** UnslothMTP  
**Статус:** Готов к исполнению младшим разработчиком (junior)  
**Проблема:** При последовательном нажатии цифр 9 → 8 → 7 на виртуальной клавиатуре калькулятора отображается только "7". Каждая следующая кнопка стирает предыдущую, многозначные числа набрать невозможно.

---

## 0. ИНСТРУКЦИЯ ПО ИСПОЛЬЗОВАНИЮ ЭТОГО ПЛАНА

Этот план предназначен для выполнения младшим разработчиком (junior). Каждый шаг детализирован до уровня "скопируй и вставь". Не пропускайте ни одного шага, не пытайтесь упростить или сократить. Если что-то непонятно — остановитесь и задайте вопрос.

**Важно:** В этом плане НЕТ альтернативных вариантов. Выполняйте строго по порядку.

---

## 1. ПОДГОТОВКА К РАБОТЕ

### 1.1 Проверьте, что проект существует

Откройте терминал и выполните:
```bash
ls /Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift
```

Вы должны увидеть вывод без ошибок (файл должен существовать). Если видите "No such file or directory" — сообщите об этом.

### 1.2 Создайте резервную копию файла

Перед любыми изменениями выполните:
```bash
cp /Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift /Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift.backup
```

Это создаст копию оригинального файла. Если что-то пойдёт не так, вы сможете восстановить оригинал командой:
```bash
cp /Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift.backup /Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift
```

### 1.3 Откройте файл для редактирования

Откройте файл `CalculatorViewModel.swift` в вашем редакторе кода:
- **Полный путь:** `/Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift`
- **Общее количество строк:** 227

---

## 2. АНАЛИЗ ПРОБЛЕМЫ (для понимания, что вы исправляете)

### 2.1 Что происходит при нажатии цифр

Когда пользователь нажимает кнопку "9" на экране калькулятора, происходит следующая цепочка вызовов:

```
1. CalculatorButton.body (CalculatorButton.swift, строка 156-158):
   Пользователь нажимает кнопку → вызывается onTap(spec.label)
   spec.label = .digit("9")

2. CalculatorView.buttonRow (CalculatorView.swift, строка 123):
   onTap передаёт label в handleButtonPress(label)

3. CalculatorView.handleButtonPress (CalculatorView.swift, строки 152-153):
   case .digit(let d): viewModel.appendCharacter(d)
   d = "9"

4. CalculatorViewModel.appendCharacter (CalculatorViewModel.swift, строка 28):
   appendCharacter("9") — ЭТОТ МЕТОД СОДЕРЖИТ БАГ
```

**То же самое происходит при вводе с физической клавиатуры:**

```
1. KeyHandlerNSView.keyDown (CalculatorApp.swift, строки 81-86):
   if char.isNumber → viewModel.appendCharacter(normalized)
   normalized = "9"

2. CalculatorViewModel.appendCharacter (CalculatorViewModel.swift, строка 28):
   appendCharacter("9") — тот же метод, та же проблема
```

Оба пути ввода (экранная клавиатура и физическая клавиатура) проходят через один и тот же метод `appendCharacter`, поэтому исправление в этом методе решит проблему для обоих способов ввода.

### 2.2 Что именно сломано в appendCharacter

Текущая реализация метода `appendCharacter` (строки 28-45):

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
    tryAutoEvaluate()                                     // строка 44 — АВТО-ОЦЕНКА! ← ПРОБЛЕМА ЗДЕСЬ
}
```

**Проблема на строке 44:** `tryAutoEvaluate()` вызывается БЕЗУСЛОВНО после каждого символа. Это означает, что даже при вводе одиночной цифры "9", метод пытается вычислить выражение и устанавливает `result = "9"`.

### 2.3 Почему это приводит к стиранию цифр

Пошаговый трейс бага "9" → "8" → "7":

**Начальное состояние:**
- `expression = ""` (пустая строка)
- `result = nil` (нет результата)
- `hasResult = false` (потому что result == nil, см. строку 18: `var hasResult: Bool { result != nil }`)

---

**ШАГ 1: Нажатие "9"**

```
handleButtonPress(.digit("9"))                          // CalculatorView.swift:153
→ appendCharacter("9")                                  // CalculatorViewModel.swift:28

Внутри appendCharacter("9"):
  clearError()                                          // строка 29 → errorMessage = nil
  hasResult = false → пропускаем оба if-блока (строки 31-40)
  expression += "9"                                     // строка 43 → expression = "9"
  tryAutoEvaluate()                                     // строка 44 ← ВЫЗЫВАЕТСЯ

Внутри tryAutoEvaluate():                               // CalculatorViewModel.swift:203-213
  trimmed = "9", не пустой, isTrailingOperator("9") = false → guard проходит
  engine.evaluate("9")                                  // CalculatorEngine.swift:23-41 → Decimal(9)
  result = formatter.format(Decimal(9))                  // строка 209 → result = "9"

СОСТОЯНИЕ ПОСЛЕ ШАГА 1: expression = "9", result = "9", hasResult = true
ЭКРАН: mainText = "9" (DisplayView.swift:58: result ?? expression)
```

---

**ШАГ 2: Нажатие "8"**

```
handleButtonPress(.digit("8"))                          // CalculatorView.swift:153
→ appendCharacter("8")                                  // CalculatorViewModel.swift:28

Внутри appendCharacter("8"):
  clearError()                                          // строка 29 → errorMessage = nil
  hasResult = true, isOperator("8") = false → ВХОДИМ в первый if-блок (строка 31) ✓
    expression = ""                                     // строка 32 ← УНИЧТОЖАЕТ "9"!
    result = nil                                        // строка 33 ← Стирает результат!
  expression += "8"                                     // строка 43 → expression = "8"
  tryAutoEvaluate()                                     // строка 44

Внутри tryAutoEvaluate():
  engine.evaluate("8") → Decimal(8)
  result = formatter.format(Decimal(8)) → result = "8"

СОСТОЯНИЕ ПОСЛЕ ШАГА 2: expression = "8", result = "8", hasResult = true
ЭКРАН: mainText = "8" ← ПРОПАЛА ЦИФРА "9"!
```

---

**ШАГ 3: Нажатие "7"** — идентичен Шагу 2.

```
expression = "" → expression += "7" → tryAutoEvaluate() → result = "7"

СОСТОЯНИЕ ПОСЛЕ ШАГА 3: expression = "7", result = "7"
ЭКРАН: mainText = "7" ← ТОЛЬКО ОДНА ЦИФРА!
```

### 2.4 Две причины бага (факторы)

**Причина A:** `tryAutoEvaluate()` вызывается безусловно после каждого символа (строка 44). При вводе одиночной цифры "9" движок мгновенно вычисляет выражение и устанавливает `result = "9"`.

**Причина B:** Логика очистки при наличии результата (строки 31-33) срабатывает на КАЖДЫЙ последующий НЕ-оператор, включая цифры. Это было задумано для случая "пользователь получил результат и хочет начать новый ввод", но из-за фактора A это происходит при каждом нажатии цифры.

**Архитектурная суть:** Метод `appendCharacter` смешивает две раздельные ответственности:
1. Накопление символов ввода (строка 43)
2. Автоматическую вычислительную оценку (строка 44)

Автооценка не должна срабатывать, пока пользователь вводит цифры для формирования многозначного числа. Она должна срабатывать только при нажатии оператора или "=", сигнализируя о завершении текущего операнда.

---

## 3. ЧТО БУДЕТ ИСПРАВЛЕНО (и как)

### 3.1 Суть исправления

Заменить безусловный вызов `tryAutoEvaluate()` на условный: вызывать автооценку только для символов, которые НЕ являются цифрами или десятичным разделителем.

**Было (строка 44):**
```swift
        tryAutoEvaluate()
```

**Станет:**
```swift
        if !isDigitOrDecimal(char) {
            tryAutoEvaluate()
        }
```

### 3.2 Что такое isDigitOrDecimal

Это новый приватный метод, который мы добавим в класс. Он возвращает `true` для цифр ("0"-"9") и десятичного разделителя ("."):

```swift
    private func isDigitOrDecimal(_ char: String) -> Bool {
        return char == "." || (char.count == 1 && char.first?.isNumber == true)
    }
```

**Как это работает:**
- `char == "."` — проверяет десятичный разделитель. Возвращает `true` для ".", `false` для всего остального.
- `char.count == 1` — гарантирует, что проверяется ровно один символ (defensive programming).
- `char.first?.isNumber` — свойство `Character.isNumber` из Foundation. Возвращает `true` для Unicode-цифр "0"-"9".

**Результат работы метода:**
| Входящий символ | Результат | Почему |
|-----------------|-----------|--------|
| `"0"` - `"9"` | `true` | `char.first?.isNumber == true` |
| `"."` | `true` | `char == "."` |
| `"+"`, `"-"`, `"*"`, `"/"`, `"%"` | `false` | Ни одно условие не выполняется |
| `"("`, `")"` | `false` | Ни одно условие не выполняется |
| `"π"` | `false` | `Character.isNumber` для "π" = false (π — не цифра в Unicode) |
| `"e"` | `false` | `Character.isNumber` для "e" = false |

### 3.3 Почему это решение правильное

1. **Сохраняется семантика "результат → новый ввод".** После нажатия "=" и получения результата, первая нажатая цифра всё равно очистит expression/result (строки 31-33), начав новый ввод. Это корректное поведение калькулятора.

2. **Операторы по-прежнему триггерят автооценку.** При вводе "2+3" нажатие "+" вызовет `tryAutoEvaluate()`, что правильно вычислит промежуточный результат (если выражение не заканчивается оператором).

3. **Минимальное вмешательство.** Изменяется ОДНА строка (строка 44) и добавляется ОДНА новая приватная функция в ОДНОМ файле. Никаких изменений в UI, движке, сервисах.

4. **Работает для обоих путей ввода:** и виртуальная клавиатура (`CalculatorView.handleButtonPress`, строки 131-165), и физическая клавиатура (`KeyHandlerNSView.keyDown`, строки 81-86) — оба вызывают `appendCharacter`.

---

## 4. ПОЛНАЯ ВЕРИФИКАЦИЯ ВСЕХ ЭЛЕМЕНТОВ ПЛАНА

### 4.1 Верификация: все классы и методы существуют

| Элемент | Файл | Строки | Статус |
|---------|------|--------|--------|
| `CalculatorViewModel` | CalculatorViewModel.swift | 8-227 | ✓ Подтверждён |
| `appendCharacter(_:)` | CalculatorViewModel.swift | 28-45 | ✓ Подтверждён |
| `tryAutoEvaluate()` | CalculatorViewModel.swift | 203-213 | ✓ Подтверждён |
| `isOperator(_:)` | CalculatorViewModel.swift | 220-222 | ✓ Подтверждён |
| `isTrailingOperator(_:)` | CalculatorViewModel.swift | 215-218 | ✓ Подтверждён |
| `clearError()` | CalculatorViewModel.swift | 224-226 | ✓ Подтверждён |
| `hasResult` (computed) | CalculatorViewModel.swift | 18 | ✓ Подтверждён |
| `expression` (var) | CalculatorViewModel.swift | 10 | ✓ Подтверждён |
| `result` (var?) | CalculatorViewModel.swift | 11 | ✓ Подтверждён |
| `errorMessage` (var?) | CalculatorViewModel.swift | 12 | ✓ Подтверждён |
| `engine` (CalculatorEngine) | CalculatorViewModel.swift | 14 | ✓ Подтверждён |
| `formatter` (NumberFormatterService) | CalculatorViewModel.swift | 16 | ✓ Подтверждён |
| `CalculatorEngine.evaluate(_:)` | CalculatorEngine.swift | 23-41 | ✓ Подтверждён |
| `handleButtonPress(_:)` | CalculatorView.swift | 131-165 | ✓ Подтверждён |
| `.digit(let d)` case | CalculatorView.swift | 152-153 | ✓ Подтверждён |
| `.decimalSeparator` case | CalculatorView.swift | 146-147 | ✓ Подтверждён |
| `.pi` case | CalculatorView.swift | 148-149 | ✓ Подтверждён |
| `.eulerConst` case | CalculatorView.swift | 150-151 | ✓ Подтверждён |
| `KeyHandlerNSView.keyDown(_:)` | CalculatorApp.swift | 55-89 | ✓ Подтверждён |
| `Character.isNumber` (Foundation) | Foundation framework | Стандартное свойство | ✓ Подтверждено документацией |

### 4.2 Верификация: все импорты доступны

В файле `CalculatorViewModel.swift` уже есть необходимые импорты (строки 1-4):
```swift
import Foundation    // → String.first?.isNumber доступен из Foundation
import SwiftUI       // → @Observable, @MainActor
import Observation   
import CalculatorEngine // → CalculatorEngine
```

Никаких дополнительных импортов добавлять НЕ НУЖНО. `Character.isNumber` — стандартное свойство Swift/Foundation, доступно без дополнительных импортов.

### 4.3 Верификация: структура проекта

Проект использует Swift Package Manager (Package.swift). Все исходные файлы находятся в `/Users/kgate/Work/GateCalc/Sources/`.

**Файлы, которые будут прочитаны для понимания контекста:**
- `Sources/ViewModels/CalculatorViewModel.swift` — 227 строк, ЕДИНСТВЕННЫЙ файл для изменений
- `Sources/Views/CalculatorView.swift` — 166 строк, только для понимания пути вызова
- `Sources/Views/DisplayView.swift` — 139 строк, только для понимания отображения
- `Sources/App/CalculatorApp.swift` — 118 строк, только для понимания клавиатурного ввода
- `Sources/CalculatorEngine/CalculatorEngine.swift` — 42 строки, только для понимания движка

**Файлы, которые НЕ изменяются и не требуют чтения:**
- `Sources/Views/CalculatorButton.swift` — UI-компонент кнопки
- `Sources/History/HistoryEntry.swift` — модель записи истории
- `Sources/Services/HistoryService.swift` — сервис истории (NSLock, thread-safe)
- `Sources/Formatting/NumberFormatterService.swift` — форматирование Decimal → String (locale en_US)
- `Sources/Clipboard/ClipboardManager.swift` — обёртка над NSPasteboard
- `Sources/Theme/CalculatorColors.swift` — цветовая система

**Пустые папки в проекте (не содержат файлов):**
- `Sources/Components/` — пустая
- `Sources/Extensions/` — пустая

---

## 5. ДЕТАЛЬНЫЙ ПЛАН РЕАЛИЗАЦИИ (пошаговый)

### ШАГ 1: Добавить приватный хелпер `isDigitOrDecimal`

**Расположение:** В секции `// MARK: - Private helpers`, после метода `clearError()` (строка 226), перед закрывающей скобкой класса (строка 227).

**Что нужно сделать:**
1. Найдите в файле строку с текстом `private func clearError()`. Она находится на строке 224.
2. Ниже неё вы увидите закрывающую скобку класса `}` — это строка 227 (последняя строка файла).
3. МЕЖДУ методом `clearError()` и закрывающей скобкой класса нужно вставить новый метод.

**Точное содержимое для вставки (после строки 226, перед строкой 227):**

```swift

    private func isDigitOrDecimal(_ char: String) -> Bool {
        return char == "." || (char.count == 1 && char.first?.isNumber == true)
    }
```

**Обратите внимание:** Перед `private func` должна быть одна пустая строка (для разделения методов).

**Полный контекст после вставки (строки 201-231):**

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

### ШАГ 2: Заменить безусловный вызов `tryAutoEvaluate()` на условный

**Расположение:** Метод `appendCharacter`, строка 44 в текущем файле.

**Что нужно сделать:**
1. Найдите метод `func appendCharacter(_ char: String)` — он начинается со строки 28.
2. Внутри этого метода найдите строку 44, которая содержит ровно:
   ```swift
           tryAutoEvaluate()
   ```
3. Замените ЭТУ ОДНУ СТРОКУ на три строки (условный блок):

**Было (одна строка):**
```swift
        tryAutoEvaluate()
```

**Станет (три строки):**
```swift
        if !isDigitOrDecimal(char) {
            tryAutoEvaluate()
        }
```

**Полный контекст метода `appendCharacter` после замены (строки 28-49):**

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

**Обратите внимание на отступы:** `if` должен иметь 8 пробелов (2 уровня по 4 пробела), тело `if` — 12 пробелов (3 уровня).

---

## 6. ПОЛНОЕ ИТОГОВОЕ СОСТОЯНИЕ ФАЙЛА (после обоих изменений)

После выполнения Шага 1 и Шага 2 файл `CalculatorViewModel.swift` будет выглядеть следующим образом (изменения выделены в соответствующих разделах):

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
        if !isDigitOrDecimal(char) {          // ← ИЗМЕНЕНИЕ ШАГА 2 (строка 44 → строки 44-46)
            tryAutoEvaluate()
        }
    }

    /// Этот метод больше не вызывается из UI, оставлен для совместимости
    func appendOperator(_ op: String) {
        clearError()

        if hasResult {
            // ИСПРАВЛЕНИЕ C-08
            if let res = result, let dec = Decimal(string: res.replacingOccurrences(of: ",", with: ".")) {
                expression = dec.description + op
            }
            result = nil
        } else {
            expression += op
        }
        result = nil
    }

    func evaluate() {
        clearError()

        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        do {
            let value = try engine.evaluate(expression)
            let formatted = formatter.format(value)

            // Всегда добавляем в историю успешные вычисления
            historyService.add(expression: expression, result: value)

            result = formatted
            expression = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        expression = ""
        result = nil
        errorMessage = nil
    }

    func backspace() {
        clearError()

        if expression.isEmpty, let _ = result {
            clear()
            return
        }

        if !expression.isEmpty {
            expression.removeLast()
            tryAutoEvaluate()
        } else if hasResult {
            clear()
        }
    }

    /// Инвертирует знак текущего числа/выражения
    func toggleSign() {
        if expression.isEmpty {
            // ИСПРАВЛЕНИЕ S-16: заменить "," на "." перед парсингом Decimal
            if let result, let val = Decimal(string: result.replacingOccurrences(of: ",", with: ".")) {
                let negated = -val
                expression = negated.description
                self.result = nil
            }
        } else {
            if expression.hasPrefix("-") {
                expression = String(expression.dropFirst())
            } else {
                expression = "-(\(expression))"
            }
        }
        errorMessage = nil
    }

    // MARK: - Memory operations (SRS §39-43)

    func memoryClear() {
        memoryValue = 0
    }

    func memoryAdd() {
        // ИСПРАВЛЕНИЕ S-17: заменить "," на "." перед парсингом Decimal
        guard let result, let val = Decimal(string: result.replacingOccurrences(of: ",", with: ".")) else { return }
        memoryValue += val
    }

    func memorySubtract() {
        // ИСПРАВЛЕНИЕ S-17: заменить "," на "." перед парсингом Decimal
        guard let result, let val = Decimal(string: result.replacingOccurrences(of: ",", with: ".")) else { return }
        memoryValue -= val
    }

    func memoryRecall() {
        expression = memoryValue.description
        result = nil
        errorMessage = nil
    }

    func handleKeyCommand(_ key: String) {
        switch key {
        case "C", "\u{1B}":
            clear()
        case "\u{7F}", "\u{8}":
            backspace()
        case "\r", "\n", "=":
            evaluate()
        default:
            if key.count == 1, let firstChar = key.first, firstChar.isNumber || "+-*/().%".contains(firstChar) {
                appendCharacter(key)
            }
        }
    }

    // MARK: - Clipboard

    func insertFromClipboard(_ text: String) {
        // ИСПРАВЛЕНИЕ C-06: показать выражение пользователю вместо expression = ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        clear()

        if let value = try? engine.evaluate(trimmed) {
            expression = trimmed      // Показать выражение пользователю
            result = formatter.format(value)  // Показать результат
            historyService.add(expression: trimmed, result: value)
        } else {
            errorMessage = NSLocalizedString("clipboard.cannotEvaluate", comment: "")
        }
    }

    func copyResult() {
        if let result = result {
            ClipboardManager.shared.setString(result)
        }
    }

    // MARK: - History

    func useHistoryEntry(_ entry: HistoryEntry) {
        expression = entry.expression
        result = nil
        errorMessage = nil
        tryAutoEvaluate()
    }

    /// Очищает историю вычислений
    func clearHistory() {
        historyService.clear()
    }

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

    private func isDigitOrDecimal(_ char: String) -> Bool {   // ← НОВЫЙ МЕТОД (ШАГ 1)
        return char == "." || (char.count == 1 && char.first?.isNumber == true)
    }
}
```

**Количество изменений:**
- Изменение 1: Добавлено 4 строки (новый метод `isDigitOrDecimal` + пустая строка перед ним)
- Изменение 2: Заменено 1 строка на 3 строки (+2 строки net)
- **Итого: +7 строк кода в одном файле**

---

## 7. ПОШАГОВАЯ ВЕРИФИКАЦИЯ ВСЕХ СЦЕНАРИЕВ (после исправления)

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
ЭКРАН: mainText = "987" (DisplayView.swift:58: result ?? expression) ← ВЕРНО!
```

### Сценарий 2: Выражение с оператором "2+3=" — РАБОТАЕТ ✓

```
Нажатие "2":
  appendCharacter("2"):
    hasResult = false → пропускаем if-блоки
    expression += "2" → expression = "2"
    isDigitOrDecimal("2") = true → ПРОПУСКАЕМ tryAutoEvaluate()

Нажатие "+":
  appendCharacter("+"):
    hasResult = false → пропускаем if-блоки
    expression += "+" → expression = "2+"
    isDigitOrDecimal("+") = false → ВЫЗЫВАЕМ tryAutoEvaluate() ✓

Внутри tryAutoEvaluate():
  trimmed = "2+", не пустой
  isTrailingOperator("2+") = true (последний символ "+", см. строку 217)
  guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return } ← guard НЕ проходит → ранний выход
  Auto-eval не срабатывает для выражений, заканчивающихся оператором ← ЭТО ПРАВИЛЬНО

Нажатие "3":
  appendCharacter("3"):
    hasResult = false → пропускаем if-блоки
    expression += "3" → expression = "2+3"
    isDigitOrDecimal("3") = true → ПРОПУСКАЕМ tryAutoEvaluate()

Нажатие "=":
  evaluate():                                          // CalculatorViewModel.swift:63-81
    engine.evaluate("2+3") → Decimal(5)
    result = formatter.format(Decimal(5)) → result = "5"
    expression = "" (строка 77)

ЭКРАН: mainText = "5" ← ВЕРНО!
```

### Сценарий 3: Результат → новый ввод "5" → нажатие "4" — РАБОТАЕТ ✓

```
Состояние после вычисления "=": expression = "", result = "5", hasResult = true

Нажатие "4":
  appendCharacter("4"):
    hasResult = true, isOperator("4") = false → ВХОДИМ в первый if-блок (строка 31) ✓
      expression = "" → expression = "" (уже пустой)
      result = nil → result = nil
    expression += "4" → expression = "4"
    isDigitOrDecimal("4") = true → ПРОПУСКАЕМ tryAutoEvaluate()

ИТОГ: expression = "4", result = nil ← ВЕРНО! Новый ввод начинается с чистого листа.
```

### Сценарий 4: Десятичное число "1.5" — РАБОТАЕТ ✓

```
Нажатие "1":
  appendCharacter("1"):
    hasResult = false → пропускаем if-блоки
    expression += "1" → expression = "1"
    isDigitOrDecimal("1") = true → ПРОПУСКАЕМ tryAutoEvaluate()

Нажатие ".":
  appendCharacter("."):
    hasResult = false → пропускаем if-блоки
    expression += "." → expression = "1."
    isDigitOrDecimal(".") = true (char == ".") → ПРОПУСКАЕМ tryAutoEvaluate() ✓

Нажатие "5":
  appendCharacter("5"):
    hasResult = false → пропускаем if-блоки
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
Метод backspace (CalculatorViewModel.swift, строки 89-103) НЕ вызывает appendCharacter.
Он напрямую модифицирует expression и вызывает tryAutoEvaluate() самостоятельно (строка 99).
Этот путь НЕ затронут изменениями. ← ВЕРНО!

Пример:
  expression = "987", result = nil
  backspace():
    expression.removeLast() → expression = "98"
    tryAutoEvaluate() вызывается напрямую (строка 99) ✓
```

### Сценарий 6: История → useHistoryEntry — РАБОТАЕТ ✓

```
Метод useHistoryEntry (CalculatorViewModel.swift, строки 189-194):
  expression = entry.expression
  result = nil
  errorMessage = nil
  tryAutoEvaluate() ← ВЫЗЫВАЕТСЯ НАПРЯМУЮ, НЕ ЧЕРЕЗ appendCharacter

Этот путь НЕ затронут изменениями. ← ВЕРНО!
```

### Сценарий 7: Клавиатурный ввод цифр — ИСПРАВЛЕНО ✓

```
KeyHandlerNSView.keyDown (CalculatorApp.swift, строки 81-86):
  default:
    if !characters.isEmpty {
      let char = characters.first ?? " "
      if char.isNumber || "+-*/().%,πe".contains(char) {
        let normalized = char == "," ? "." : String(char)
        viewModel.appendCharacter(normalized)   // ← ТОТ ЖЕ ПУТЬ!
      }
    }

Цифры с клавиатуры → appendCharacter → та же логика isDigitOrDecimal → работает корректно. ← ВЕРНО!

Пример: пользователь нажимает "9", "8", "7" на физической клавиатуре:
  appendCharacter("9") → expression = "9" (без auto-eval)
  appendCharacter("8") → expression = "98" (без auto-eval)
  appendCharacter("7") → expression = "987" (без auto-eval) ← ИСПРАВЛЕНО!
```

### Сценарий 8: Оператор после результата "5" + "3" — РАБОТАЕТ ✓

```
Состояние после вычисления "=": expression = "", result = "5", hasResult = true

Нажатие "+":
  appendCharacter("+"):
    hasResult = true, isOperator("+") = true → ВХОДИМ во второй if-блок (строка 34) ✓
      res = "5"
      dec = Decimal(string: "5".replacingOccurrences(of: ",", with: ".")) = Decimal(5)
      expression = "5".description = "5"
      result = nil
    expression += "+" → expression = "5+"
    isDigitOrDecimal("+") = false → ВЫЗЫВАЕМ tryAutoEvaluate()

Внутри tryAutoEvaluate():
  isTrailingOperator("5+") = true (последний символ "+") → guard не проходит, ранний выход ← OK

ЭКРАН: mainText = "5+" (result nil, берётся expression) ← ВЕРНО!
```

### Сценарий 9: Константа π — РАБОТАЕТ ✓

```
Нажатие "π" на экране:
  CalculatorView.handleButtonPress (.pi) → CalculatorView.swift:148-149
    viewModel.appendCharacter("π")

Внутри appendCharacter("π"):
  hasResult = false (предположим, выражение было "3", но auto-eval не сработал при вводе "3")
  
  Если expression было "3" и result был nil:
    expression += "π" → expression = "3π"
    isDigitOrDecimal("π") = false (Character.isNumber для "π" = false) → ВЫЗЫВАЕМ tryAutoEvaluate()

  Если expression было "" и result был "5":
    hasResult = true, isOperator("π") = false → первый if-блок:
      expression = "", result = nil
    expression += "π" → expression = "π"
    isDigitOrDecimal("π") = false → ВЫЗЫВАЕМ tryAutoEvaluate()

  В любом случае π добавляется в выражение. ← ВЕРНО!
```

### Сценарий 10: Скобки "(2+3)" — РАБОТАЕТ ✓

```
Нажатие "(":
  CalculatorView.handleButtonPress (.openParen) → CalculatorView.swift:144-145
    viewModel.appendCharacter(label.inputValue)
    label.inputValue для .openParen = "(" (CalculatorButton.swift, строка 71)

Внутри appendCharacter("("):
  isDigitOrDecimal("(") = false → ВЫЗЫВАЕМ tryAutoEvaluate() ✓

Если expression было "5" и result был nil:
  expression += "(" → expression = "5("
  tryAutoEvaluate() вызовет engine.evaluate("5(") — это может вызвать ошибку парсинга,
  но она будет обработана в catch блоке tryAutoEvaluate (строка 210-211):
    errorMessage = error.localizedDescription

Это корректное поведение: пользователь продолжает ввод "(2+3)", и при нажатии "=" всё вычисляется. ← ВЕРНО!
```

### Сценарий 11: Backspace после ввода цифр "987" — РАБОТАЕТ ✓

```
expression = "987", result = nil (после исправления, auto-eval не сработал)

backspace():
  expression.removeLast() → expression = "98"
  tryAutoEvaluate() вызывается напрямую (строка 99, НЕ через appendCharacter) ✓

Внутри tryAutoEvaluate():
  engine.evaluate("98") → Decimal(98)
  result = formatter.format(Decimal(98)) → result = "98"

ЭКРАН: mainText = "98" ← ВЕРНО!
```

### Сценарий 12: Операторы %, скобки, константы — РАБОТАЕТ ✓

```
"%": isDigitOrDecimal("%") = false → tryAutoEvaluate() вызывается (как и раньше) ✓
"(": isDigitOrDecimal("(") = false → tryAutoEvaluate() вызывается (как и раньше) ✓
"π": isDigitOrDecimal("π") = false → tryAutoEvaluate() вызывается (как и раньше) ✓
"e": isDigitOrDecimal("e") = false → tryAutoEvaluate() вызывается (как и раньше) ✓
```

### Сценарий 13: useHistoryEntry — РАБОТАЕТ ✓

```
expression = "2+3" (из истории), tryAutoEvaluate() вызывается напрямую (не через appendCharacter)
→ result = "5" ← ВЕРНО!

Это не затрагивается изменением, т.к. tryAutoEvaluate() вызывается напрямую в useHistoryEntry
(CalculatorViewModel.swift, строка 193).
```

### Сценарий 14: insertFromClipboard — РАБОТАЕТ ✓

```
insertFromClipboard (CalculatorViewModel.swift, строки 165-179):
  Не вызывает appendCharacter — использует engine.evaluate напрямую (строка 172)
  → НЕ ЗАТРОНУТО ИЗМЕНЕНИЕМ ← ВЕРНО!
```

---

## 8. ЧТО НЕ ТРОГАЕТСЯ (все зависимости верифицированы)

| Элемент | Файл | Строки | Статус | Обоснование |
|---------|------|--------|--------|-------------|
| `CalculatorView.handleButtonPress` | CalculatorView.swift | 131-165 | Без изменений | Маршрутизация нажатий корректна, вызывает appendCharacter для цифр |
| `DisplayView.mainText` | DisplayView.swift | 58 | Без изменений | Логика приоритета result/expression корректна: `result ?? (expression.isEmpty ? "0" : expression)` |
| `CalculatorEngine.evaluate(_:)` | CalculatorEngine.swift | 23-41 | Без изменений | Движок работает правильно, вычисляет выражения |
| `backspace()` | CalculatorViewModel.swift | 89-103 | Без изменений | Вызывает tryAutoEvaluate напрямую (строка 99), не через appendCharacter |
| `evaluate()` | CalculatorViewModel.swift | 63-81 | Без изменений | Явная оценка по "=" работает независимо от appendCharacter |
| `tryAutoEvaluate()` | CalculatorViewModel.swift | 203-213 | Без изменений | Логика автооценки не изменена, только условие вызова из appendCharacter |
| `isTrailingOperator(_:)` | CalculatorViewModel.swift | 215-218 | Без изменений | Не изменён |
| `isOperator(_:)` | CalculatorViewModel.swift | 220-222 | Без изменений | Не изменён |
| `clearError()` | CalculatorViewModel.swift | 224-226 | Без изменений | Не изменён |
| `appendOperator(_:)` | CalculatorViewModel.swift | 48-61 | Без изменений | Не вызывает tryAutoEvaluate, не затронут |
| `clear()` | CalculatorViewModel.swift | 83-87 | Без изменений | Не затронут |
| `toggleSign()` | CalculatorViewModel.swift | 106-122 | Без изменений | Не затронут |
| Memory operations (MC, M+, M-, MR) | CalculatorViewModel.swift | 126-146 | Без изменений | Не затронуты |
| `handleKeyCommand(_:)` | CalculatorViewModel.swift | 148-161 | Без изменений | Вызывает appendCharacter для цифр — исправление применяется автоматически |
| `insertFromClipboard(_:)` | CalculatorViewModel.swift | 165-179 | Без изменений | Использует engine.evaluate напрямую, bypasses appendCharacter |
| `copyResult()` | CalculatorViewModel.swift | 181-185 | Без изменений | Не затронут |
| `useHistoryEntry(_:)` | CalculatorViewModel.swift | 189-194 | Без изменений | Вызывает tryAutoEvaluate напрямую, не через appendCharacter |
| `clearHistory()` | CalculatorViewModel.swift | 197-199 | Без изменений | Не затронут |
| `CalculatorButton` | CalculatorButton.swift | 1-203 | Без изменений | UI-компонент не затронут |
| `KeyHandlerNSView` | CalculatorApp.swift | 50-118 | Без изменений | Клавиатурный ввод идёт через appendCharacter, исправление применяется автоматически |
| `HistoryService` | HistoryService.swift | 1-44 | Без изменений | Не затронут (NSLock, thread-safe) |
| `NumberFormatterService` | NumberFormatterService.swift | 1-47 | Без изменений | Не затронут (locale en_US, точка как разделитель) |
| `ClipboardManager` | ClipboardManager.swift | 1-32 | Без изменений | Не затронут |
| `CalculatorColors` | CalculatorColors.swift | 1-46 | Без изменений | Не затронут |
| Юнит-тесты CalculatorEngineTests | Tests/Unit/CalculatorEngineTests.swift | 1-275 | Без изменений | Тестируют только движок (CalculatorEngine), не ViewModel |

---

## 9. ПОТЕНЦИАЛЬНЫЕ РИСКИ И ИХ УСТРАНЕНИЕ

### Риск 1: Auto-eval для выражений типа "2+3" больше не срабатывает мгновенно при вводе цифр

**Статус:** Не является риском. Пользователь видит выражение "2+3" и нажимает "=" для получения результата. Это стандартное поведение калькулятора (как в iOS Calculator, Windows Calculator и т.д.).

**Обоснование:** В текущем коде auto-eval срабатывает при вводе каждой цифры, что приводит к багу. После исправления auto-eval срабатывает только при нажатии оператора или других не-цифровых символов. Результат вычисляется по "=" — это ожидаемое поведение.

### Риск 2: Метод `isDigitOrDecimal` может некорректно обработать нестандартный ввод

**Статус:** Не является риском. В `handleButtonPress` (CalculatorView.swift, строки 131-165) в UI передаются только определённые `ButtonLabel` значения, и все они проходят через проверенные ветки switch:
- `.digit(let d)` → d = "0"-"9" (строка 152-153)
- `.decimalSeparator` → "." (строка 146-147)
- операторы → "+", "-", "*", "/", "%" (строка 143-145)
- `.percent` → "%" (строка 142)
- `.pi` → "π" (строка 148-149)
- `.eulerConst` → "e" (строка 150-151)
- скобки → "(", ")" (строка 144-145)

Все эти значения корректно обрабатываются `isDigitOrDecimal`:
| Значение | isDigitOrDecimal | Результат в appendCharacter |
|----------|------------------|---------------------------|
| "0"-"9" | true | ПРОПУСК auto-eval ✓ |
| "." | true | ПРОПУСК auto-eval ✓ |
| "+", "-", "*", "/", "%" | false | ВЫЗОВ auto-eval ✓ |
| "%" | false | ВЫЗОВ auto-eval ✓ |
| "π" | false | ВЫЗОВ auto-eval ✓ |
| "e" | false | ВЫЗОВ auto-eval ✓ |
| "(", ")" | false | ВЫЗОВ auto-eval ✓ |

### Риск 3: Изменение может сломать UI-тесты

**Статус:** Требуется проверка. В проекте есть UI-тесты (`Tests/UI/CalculatorUITests.swift`, 151 строка). Однако все тесты проверяют КОНЕЧНЫЙ результат (после нажатия "="), а не промежуточное состояние во время ввода:
- `testSimpleAddition` — нажимает "1", "5", "+", "1", "6", "=" → ожидает "31" ✓
- `testParenthesesCalculation` — нажимает "(", "1", "5", "+", ... → ожидает "155" ✓
- `testKeyboardInput` — вводит "1", "+", "2", "\r" (Enter) → ожидает "3" ✓

Ни один тест не проверяет промежуточное состояние экрана во время ввода цифр. Исправление НЕ сломает существующие UI-тесты, потому что конечный результат вычислений остаётся тем же самым.

**Юнит-тесты CalculatorEngineTests** (275 строк) тестируют только движок `CalculatorEngine`, а не ViewModel. Они НЕ затронуты изменением.

### Риск 4: Компиляция проекта

**Статус:** Низкий риск. Новый метод `isDigitOrDecimal` использует стандартные свойства Swift (`String.count`, `String.first`, `Character.isNumber`). Все эти API существуют в Foundation и доступны без дополнительных импортов (Foundation уже импортирован на строке 1).

---

## 10. ПОСЛЕДОВАТЕЛЬНОСТЬ ВЫПОЛНЕНИЯ (итоговый чеклист)

Выполняйте шаги строго по порядку:

### Шаг 1: Резервное копирование
```bash
cp /Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift /Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift.backup
```

### Шаг 2: Открыть файл для редактирования
Откройте `/Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift` в редакторе.

### Шаг 3: Добавить метод `isDigitOrDecimal` (ШАГ 1 из раздела 5)
Найдите строку с закрывающей скобкой класса `}` — это последняя строка файла (строка 227). Вставьте новый метод ПЕРЕД ней.

**Вставляемый код:**
```swift

    private func isDigitOrDecimal(_ char: String) -> Bool {
        return char == "." || (char.count == 1 && char.first?.isNumber == true)
    }
```

### Шаг 4: Заменить вызов `tryAutoEvaluate()` (ШАГ 2 из раздела 5)
Найдите строку 44 в методе `appendCharacter`. Она содержит ровно:
```swift
        tryAutoEvaluate()
```

Замените ЭТУ СТРОКУ на:
```swift
        if !isDigitOrDecimal(char) {
            tryAutoEvaluate()
        }
```

### Шаг 5: Сохранить файл

### Шаг 6: Проверка компиляции
Откройте проект в Xcode и убедитесь, что он компилируется без ошибок. Или выполните в терминале:
```bash
cd /Users/kgate/Work/GateCalc && swift build
```

Если используете скрипт сборки:
```bash
/Users/kgate/Work/GateCalc/build_app.sh
```

### Шаг 7: Проверка тестов (опционально, рекомендуется)
```bash
cd /Users/kgate/Work/GateCalc && swift test
```

---

## 11. ОЖИДАЕМЫЙ РЕЗУЛЬТАТ

После применения плана:

- ✓ Пользователь может набирать многозначные числа: "987", "1234567" и т.д.
- ✓ Цифры накапливаются в `expression` без преждевременной автооценки
- ✓ Автооценка срабатывает только при нажатии операторов (+, -, *, /, %), скобок, π, e
- ✓ Поведение "результат → новый ввод" сохраняется (первая цифра после "=" очищает выражение)
- ✓ Клавиатурный ввод цифр также исправлен (тот же путь через appendCharacter)
- ✓ Backspace, история, память — без изменений
- ✓ UI-тесты не ломаются (конечные результаты вычислений те же самые)

**Баг устранён архитектурно корректно и минимальным вмешательством.**

---

## 12. СПРАВКА: СТРУКТУРА ПРОЕКТА

Проект GateCalc — Swift Package Manager macOS-приложение на SwiftUI.

### 12.1 Файловая структура (только существующие файлы)

| Путь | Строки | Назначение |
|------|--------|------------|
| `Sources/ViewModels/CalculatorViewModel.swift` | 227 | Управление состоянием калькулятора — ЕДИНСТВЕННЫЙ файл для изменений |
| `Sources/Views/CalculatorView.swift` | 166 | UI-раскладка, сетка кнопок, маршрутизация нажатий |
| `Sources/Views/CalculatorButton.swift` | 203 | Компонент кнопки, enum ButtonLabel, enum CalcButtonType, struct ButtonSpec |
| `Sources/Views/DisplayView.swift` | 139 | Отображение выражения и результата |
| `Sources/App/CalculatorApp.swift` | 118 | Точка входа (@main), KeyHandlerNSView для клавиатуры |
| `Sources/CalculatorEngine/CalculatorEngine.swift` | 42 | Фасад движка: tokenize → parse → evaluate |
| `Sources/History/HistoryEntry.swift` | 29 | Модель записи истории (expression, result, timestamp) |
| `Sources/Services/HistoryService.swift` | 44 | Сервис истории (NSLock, thread-safe, maxEntries=50) |
| `Sources/Formatting/NumberFormatterService.swift` | 47 | Форматирование Decimal → String (locale en_US) |
| `Sources/Clipboard/ClipboardManager.swift` | 32 | Обёртка над NSPasteboard (NSLock синхронизация) |
| `Sources/Theme/CalculatorColors.swift` | 46 | Цветовая система |
| `Package.swift` | 59 | Конфигурация SPM |
| `build_app.sh` | 65 | Скрипт сборки в .app пакет |

### 12.2 Пустые папки (не содержат файлов)

- `Sources/Components/` — пустая
- `Sources/Extensions/` — пустая

Эти папки указаны в Package.swift как источники для target "CalculatorApp", но на данный момент пусты.

### 12.3 Тесты

| Файл | Строки | Назначение |
|------|--------|------------|
| `Tests/Unit/CalculatorEngineTests.swift` | 275 | Юнит-тесты движка (CalculatorEngine) — НЕ затронуты изменением |
| `Tests/UI/CalculatorUITests.swift` | 151 | UI-тесты полного калькулятора — НЕ сломаются (проверяют конечные результаты) |

### 12.4 Ключевые зависимости между классами

```
CalculatorViewModel
  ├── CalculatorEngine (движок вычислений)
  ├── HistoryService.shared (сервис истории)
  └── NumberFormatterService.shared (форматирование чисел)

CalculatorView
  └── CalculatorViewModel (@Bindable)
      └── CalculatorButton (onTap callback → handleButtonPress → appendCharacter)

KeyHandlerNSView
  └── CalculatorViewModel (@Bindable, weak reference)
      └── appendCharacter (для клавиатурного ввода)

DisplayView
  ├── expression (из viewModel.expression)
  ├── result (из viewModel.result)
  └── errorMessage (из viewModel.errorMessage)
```

---

## 13. ВОЗМОЖНЫЕ ВОПРОСЫ И ОТВЕТЫ

### Вопрос: Почему мы не исправляем баг в tryAutoEvaluate, а меняем место его вызова?

**Ответ:** Потому что проблема не в том, ЧТО делает `tryAutoEvaluate`, а в ТОМ, КОГДА он вызывается. Метод `tryAutoEvaluate` корректно вычисляет выражение и устанавливает результат. Проблема в том, что он вызывается после КАЖДОГО символа, включая цифры. Правильное решение — не вызывать его для цифр, а не менять логику самого метода.

### Вопрос: Почему мы добавляем новый метод `isDigitOrDecimal`, а не проверяем условие прямо в if?

**Ответ:** Потому что это улучшает читаемость кода. Строка `if !isDigitOrDecimal(char)` самодокументируется — сразу понятно, что мы пропускаем автооценку для цифр и десятичного разделителя. Альтернатива `if !(char == "." || (char.count == 1 && char.first?.isNumber == true))` менее читаема из-за двойного отрицания.

### Вопрос: Что если пользователь введёт "1." и остановится?

**Ответ:** Это корректное поведение. expression = "1.", result = nil. Пользователь может продолжить ввод "1.5". Если пользователь нажмёт "=" с выражением "1.", движок вычислит его как Decimal(1).

### Вопрос: Что если пользователь введёт двойную точку "1..5"?

**Ответ:** expression = "1..5", при нажатии "=" движок вернёт ошибку парсинга, которая будет показана пользователю через errorMessage. Это отдельная задача по валидации ввода, не связанная с текущим багом затирания цифр.

### Вопрос: Будет ли мерцание экрана при backspace после ввода цифр?

**Ответ:** После исправления, при backspace с "987" → "98", tryAutoEvaluate вызовется и вычислит "98". Это может вызвать визуальное обновление результата на экране. Однако это не баг — это ожидаемое поведение калькулятора (показ промежуточного результата). Если мерцание заметно, это можно оптимизировать отдельно в будущем.

### Вопрос: Почему в Package.swift указаны папки Components и Extensions, если они пусты?

**Ответ:** Это может быть подготовительная структура для будущих функций или результат рефакторинга. На данный момент эти папки пусты и не влияют на текущее исправление.

---

## 14. ФИНАЛЬНАЯ ПРОВЕРКА ПЕРЕД ЗАПУСКОМ

Перед тем как начать выполнение, убедитесь:

- [ ] Файл `CalculatorViewModel.swift` существует по пути `/Users/kgate/Work/GateCalc/Sources/ViewModels/CalculatorViewModel.swift`
- [ ] Резервная копия создана (`CalculatorViewModel.swift.backup`)
- [ ] Вы понимаете, что будете изменять ТОЛЬКО один файл: `CalculatorViewModel.swift`
- [ ] Вы понимаете, что будете делать ДВА изменения: добавить метод и заменить одну строку
- [ ] Вы знаете, как восстановить оригинальный файл (команда из Шага 1)

Если все пункты отмечены — начинайте выполнение с Шага 1 раздела 10.

---

**Конец плана.**
