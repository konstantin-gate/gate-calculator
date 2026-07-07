# План исправления: MR затирает выражение при использовании после оператора

---

## Часть 1. Тезисное резюме (позиции плана)

| # | Позиция | Детали |
|---|---------|--------|
| 1 | Файл для изменения | `Sources/ViewModels/CalculatorViewModel.swift` — единственный файл проекта, который редактируется |
| 2 | Метод для изменения | `memoryRecall()` (строки 176–181) — модификация существующей логики внутри метода |
| 3 | Суть бага | Строка 177: `expression = memoryValue.description` — безусловная замена, затирает выражение включая оператор в конце |
| 4 | Решение | Добавить проверку: если expression не пустая И последний символ — оператор → дописать значение памяти через `+=`; иначе заменить как раньше |
| 5 | Используемый существующий метод | `isTrailingOperator(_ expr: String) -> Bool` (строки 250–253) — уже существует, проверяет последний символ на `+`, `-`, `*`, `/`, `%` |
| 6 | Добавление `clearError()` | Вызов `clearError()` (строки 259–261) в начало метода memoryRecall() — согласовано с паттернами других методов (`appendCharacter`, `evaluate`, `backspace`) |
| 7 | Свойство `memoryValue` | Строка 37, тип `Decimal`, `.description` возвращает ASCII-строку (например `Decimal(10).description` → `"10"`) |
| 8 | Свойство `expression` | Строка 10, тип `String`, мутабельная переменная (`var`), поддерживает конкатенацию через `+=` |
| 9 | Сброс свойств | `result = nil`, `resultDecimal = nil`, `errorMessage = nil` — остаются без изменений (старая логика) |
| 10 | Кнопка MR в UI | `CalculatorView.swift:63`: `ButtonSpec(label: .mR, type: .function, isEnabled: viewModel.hasMemory)` — кнопка отключена при пустой памяти (`hasMemory` строка 52), значит внутри memoryRecall() проверять `memoryValue != 0` не нужно |
| 11 | Вызывающая сторона UI | `CalculatorView.swift:161`: `case .mR: viewModel.memoryRecall()` — маппинг корректен, без изменений |
| 12 | Клавиатурный ввод MR | Не реализован в `handleKeyCommand(_:)` (строки 183–196) — кейс "MR" отсутствует, единственный путь вызова — кнопка UI `.mR` |
| 13 | ButtonLabel.mR | `CalculatorButton.swift:35`: `case mR`, displayTitle = `"MR"` (строка 57), accessibilityDescription = `"Вспомнить из памяти"` (строка 95) |
| 14 | Другие методы памяти | `memoryClear()` (162–164), `memoryAdd()` (166–169), `memorySubtract()` (171–174) — НЕ изменяются, не зависят от memoryRecall() |
| 15 | Взаимодействие с tryAutoEvaluate | После исправленного MR пользователь нажимает оператор → appendCharacter вызывает tryAutoEvaluate → isTrailingOperator вернёт true → автовычисление пропустит. Побочных эффектов нет |
| 16 | Граничный случай: expression пустая | Условие `!expression.isEmpty` = false → ветка else → замена как раньше. Поведение идентично текущему |
| 17 | Граничный случай: MR после evaluate() | После evaluate() expression = "" (строка 112) → условие false → замена. Поведение идентично текущему |
| 18 | Граничный случай: MR дважды подряд | Второй вызов: expression = "10+10", последний символ "0" → isTrailingOperator вернёт false → ветка else, замена на значение из памяти. Корректное поведение |
| 19 | Граничный случай: expression заканчивается числом | Например "10+5" → последний символ "5" → не оператор → ветка else, замена. Пользователь набрал выражение и хочет заменить его памятью — корректно |
| 20 | Побочных эффектов нет | Изменения локализованы в одном методе одного файла. UI-слой, Engine, Services не затрагиваются |
| 21 | Потокобезопасность | CalculatorViewModel помечен `@MainActor` (строка 6) — все методы на главном потоке, нет конкурентного доступа к expression |
| 22 | Отладочный код | В memoryRecall() и во всём файле отсутствуют print(), debugPrint(), NSLog() — удалять нечего |
| 23 | Force unwrap / подавленные ошибки | Исправление использует только `if`-условие, `guard let` (в isTrailingOperator), `+=` для String. Нет force unwrap (`!`) и нет `try?` |

---

## Часть 2. Детализированный план реализации

### Шаг 0. Предварительный анализ бага (верифицирован)

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Метод:** `memoryRecall()` — строки 176–181

**Текущая реализация (точная, прочитана через read):**

```swift
func memoryRecall() {
    expression = memoryValue.description   // строка 177 — безусловная замена
    result = nil                           // строка 178
    resultDecimal = nil                    // строка 179
    errorMessage = nil                     // строка 180
}
```

**Проблема:** Строка 177 содержит `expression = memoryValue.description` — это безусловная замена всего содержимого `expression`. Если пользователь ввёл выражение с оператором на конце (например `"10+"`), значение полностью теряется.

**Сценарий воспроизведения бага (пошагово):**

| Шаг | Действие пользователя | Вызываемый метод | expression ДО метода | expression ПОСЛЕ метода | resultDecimal |
|-----|----------------------|------------------|---------------------|------------------------|---------------|
| 1 | Набрать "1", затем "0" | `appendCharacter("1")`, затем `appendCharacter("0")` | (пусто) → `"1"` → `"10"` | `"10"` | nil |
| 2 | Нажать M+ | `memoryAdd()` (строка 166) | `"10"` | `"10"` (memoryAdd не меняет expression) | nil |

**Верификация memoryAdd() через read (строки 166–169):**
```swift
func memoryAdd() {
    guard let val = currentDisplayValue else { return }   // строка 167
    memoryValue += val                                     // строка 168
}
```
`currentDisplayValue` (строки 42–49) — computed property: если resultDecimal != nil → возвращает его; иначе пытается вычислить expression через `engine.evaluate()`. На шаге 1 resultDecimal = nil, expression = "10", значит currentDisplayValue = try? engine.evaluate("10") = Decimal(10). Итог: memoryValue = 10.

| Шаг | Действие пользователя | Вызываемый метод | expression ДО метода | expression ПОСЛЕ метода |
|-----|----------------------|------------------|---------------------|------------------------|
| 3 | Нажать "+" | `appendCharacter("+")` (строка 60) | `"10"` | `"10+"` | nil |

**Верификация appendCharacter() через read (строки 60–79):**
```swift
func appendCharacter(_ char: String) {       // строка 60
    clearError()                              // строка 61
                                                // hasResult = false, пропускает оба guard'а (строки 63 и 67)
    expression += char                        // строка 75 → "10" + "+" = "10+"
    if !isDigitOrDecimal(char) {              // строка 76: "+" — не цифра, вызов tryAutoEvaluate()
        tryAutoEvaluate()                     // строки 77–78
    }
}
```

**Верификация tryAutoEvaluate() через read (строки 237–248):**
```swift
private func tryAutoEvaluate() {              // строка 237
    let trimmed = expression.trimmingCharacters(in: .whitespaces)   // строка 238
    guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }   // строка 239
    // ... вычисление ...
}
```
На шаге 3: expression = "10+", trimmed = "10+". `isTrailingOperator("10+")` проверяет последний символ "+" → true. Guard на строке 239 возвращает без вычисления. ✅

| Шаг | Действие пользователя | Вызываемый метод | expression ДО метода | expression ПОСЛЕ метода (текущий код) |
|-----|----------------------|------------------|---------------------|---------------------------------------|
| 4 | Нажать MR | `memoryRecall()` (строка 176) | `"10+"` ← **баг здесь** | `"10"` ← memoryValue.description = "10", expression перезаписана целиком ❌ |

**Корневая причина:** Строка 177: `expression = memoryValue.description` — безусловная замена. Не учитывает наличие оператора в конце expression.

| Шаг | Действие пользователя | Вызываемый метод | expression ПОСЛЕ метода (текущий) | Результат evaluate() |
|-----|----------------------|------------------|----------------------------------|---------------------|
| 5 | Нажать "=" | `evaluate()` (строка 97) | `"10"` | engine.evaluate("10") = 10 → result = "10" ❌ (ожидалось 20) |

**Ожидаемое поведение на шаге 4:** expression должно стать `"10+10"`, чтобы на шаге 5 вычислилось `10 + 10 = 20`. ✅

---

### Шаг 1. Верификация всех элементов, используемых в исправлении

#### 1.1. Свойство `expression`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:10`  
**Объявление (прочитано через read):**
```swift
var expression: String = ""
```
- **Тип:** `String`
- **Видимость:** public (без модификатора внутри @Observable класса)
- **Значение по умолчанию:** пустая строка `""`
- **Поддерживаемые операции:** конкатенация через `+=`, чтение `.isEmpty`, чтение `.last`, чтение `.description`

**Верификация использования в проекте (grep):**
- Строка 10: объявление свойства
- Строка 26: `guard !expression.isEmpty else { return "0" }` — проверка на пустоту
- Строка 75: `expression += char` — конкатенация через `+=`
- Строка 112: `expression = ""` — присваивание пустой строки
- Строка 134: `expression.removeLast()` — удаление последнего символа

**Вывод:** Свойство существует, тип String подтверждён. Операции `+=`, `.isEmpty`, `.last` — стандартные для Swift String. ✅

#### 1.2. Свойство `memoryValue`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:37`  
**Объявление (прочитано через read):**
```swift
private var memoryValue: Decimal = 0
```
- **Тип:** `Decimal` (из модуля Foundation)
- **Видимость:** private (доступен только внутри CalculatorViewModel)
- **Значение по умолчанию:** `0`

**Верификация использования в проекте (grep):**
- Строка 37: объявление свойства
- Строка 52: `var hasMemory: Bool { memoryValue != 0 }` — computed property для UI
- Строка 168: `memoryValue += val` — сложение с Decimal
- Строка 173: `memoryValue -= val` — вычитание из Decimal
- Строка 177: `expression = memoryValue.description` — текущий код (баг)

**Верификация `.description` для Decimal:**  
Метод `.description` — стандартное свойство типа `Decimal` из Foundation. Возвращает строковое представление в формате ASCII без разделителей тысяч, с точкой как десятичным разделителем.
- Пример: `Decimal(10).description` → `"10"`
- Пример: `Decimal(3.14).description` → `"3.14"`

**Вывод:** Свойство существует, тип Decimal подтверждён. `.description` возвращает String. ✅

#### 1.3. Метод `isTrailingOperator(_:)`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:250–253`  
**Объявление (прочитано через read):**
```swift
private func isTrailingOperator(_ expr: String) -> Bool {   // строка 250
    guard let last = expr.last else { return false }         // строка 251
    return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"   // строка 252
}                                                            // строка 253
```

- **Видимость:** private (доступен внутри CalculatorViewModel)
- **Параметр:** `expr: String` — выражение для проверки
- **Возвращаемое значение:** `Bool` — true если последний символ является оператором
- **Проверяемые операторы:** `+`, `-`, `*`, `/`, `%` (все 5 бинарных оператора калькулятора)

**Верификация вызовов метода в проекте (grep):**
- Строка 239: `!isTrailingOperator(expression)` — используется в tryAutoEvaluate() для пропуска вычисления при операторе на конце
- Строка 250: определение метода

**Вывод:** Метод существует, сигнатура подтверждена. Принимает String, возвращает Bool. Проверяет все операторы калькулятора. ✅

#### 1.4. Метод `clearError()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:259–261`  
**Объявление (прочитано через read):**
```swift
private func clearError() {    // строка 259
    errorMessage = nil         // строка 260
}                             // строка 261
```

- **Видимость:** private (доступен внутри CalculatorViewModel)
- **Параметры:** нет
- **Возвращаемое значение:** нет (void)
- **Действие:** устанавливает `errorMessage` в nil

**Верификация вызовов метода в проекте (grep):**
- Строка 61: `clearError()` — первый вызов в appendCharacter()
- Строка 83: `clearError()` — первый вызов в appendOperator()
- Строка 98: `clearError()` — первый вызов в evaluate()
- Строка 126: `clearError()` — первый вызов в backspace()

**Вывод:** Метод существует, сигнатура подтверждена. Вызывается первым действием во всех методах ввода/вычисления. Добавление в memoryRecall() согласовано с паттернами проекта. ✅

#### 1.5. Свойства `result`, `resultDecimal`, `errorMessage`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:11–13`  
**Объявления (прочитаны через read):**
```swift
var result: String? = nil                           // строка 11
internal var resultDecimal: Decimal? = nil          // строка 12
var errorMessage: String? = nil                     // строка 13
```

- **result:** тип `String?`, значение по умолчанию `nil`
- **resultDecimal:** тип `Decimal?`, видимость internal, значение по умолчанию `nil`
- **errorMessage:** тип `String?`, значение по умолчанию `nil`

**Верификация присваивания nil в текущем коде memoryRecall():**
- Строка 178: `result = nil` — сброс result
- Строка 179: `resultDecimal = nil` — сброс resultDecimal
- Строка 180: `errorMessage = nil` — сброс errorMessage

**Вывод:** Все три свойства существуют, типы подтверждены. Присваивание nil в текущем коде memoryRecall() — стандартная практика. ✅

#### 1.6. Свойство `hasMemory` и его использование в UI

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:52`  
**Объявление (прочитано через read):**
```swift
var hasMemory: Bool { memoryValue != 0 }   // строка 52
```

- **Тип:** `Bool`, computed property
- **Логика:** true если memoryValue не равен нулю

**Файл:** `Sources/Views/CalculatorView.swift:63`  
**Использование (прочитано через read):**
```swift
ButtonSpec(label: .mR, type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue),   // строка 63
```

- **isEnabled:** привязано к `viewModel.hasMemory` — кнопка отключена при memoryValue = 0
- **hasMemoryIndicator:** привязано к `viewModel.hasMemory` — показывает зелёный индикатор на кнопке
- **memoryTooltip:** привязано к `viewModel.memoryDisplayValue` — показывает форматированное значение памяти

**Вывод:** Кнопка MR физически не может быть нажата при memoryValue = 0 (disabled). Внутри memoryRecall() проверять `memoryValue != 0` не нужно. ✅

#### 1.7. Вызывающая сторона: CalculatorView.handleButtonPress

**Файл:** `Sources/Views/CalculatorView.swift:160–161`  
**Код (прочитан через read):**
```swift
case .mR:
    viewModel.memoryRecall()
```

- **Enum кейс:** `.mR` из `ButtonLabel` (определён в CalculatorButton.swift:35)
- **Вызов:** `viewModel.memoryRecall()` — без параметров, без возврата значения
- **Контекст:** метод `handleButtonPress(_ label: ButtonLabel)` (строка 131), вызывается из `CalculatorButton.onTap`

**Верификация ButtonLabel.mR через read (CalculatorButton.swift):**
- Строка 35: `case mR` — определение enum кейса
- Строка 57: `case .mR: return "MR"` — displayTitle = "MR"
- Строка 95: `case .mR: return "Вспомнить из памяти"` — accessibilityDescription

**Вывод:** Единственный путь вызова memoryRecall() — нажатие кнопки MR в UI. Маппинг корректен, без изменений не требуется. ✅

#### 1.8. Клавиатурный ввод: KeyHandlerNSView / handleKeyCommand

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:183–196`  
**Код (прочитан через read):**
```swift
func handleKeyCommand(_ key: String) {    // строка 183
    switch key {                          // строка 184
    case "C", "\u{1B}":                   // строка 185
        clear()                           // строка 186
    case "\u{7F}", "\u{8}":               // строка 187
        backspace()                       // строка 188
    case "\r", "\n", "=":                 // строка 189
        evaluate()                        // строка 190
    default:                               // строка 191
        if key.count == 1, let firstChar = key.first, firstChar.isNumber || "+-*/().%".contains(firstChar) {   // строки 192–193
            appendCharacter(key)          // строка 194
        }                                 // строка 195
    }                                     // строка 196
}                                         // строка 197
```

- **Кейсы:** "C", Escape (0x1B), Backspace (0x7F, 0x8), Return/Enter (=) — и default для символов ввода
- **Кейс "MR" отсутствует** — клавиатурная команда MR не реализована

**Верификация KeyHandlerNSView через grep:**  
Grep по `memoryRecall` в `Sources/App/CalculatorApp.swift` не дал результатов. Значит, KeyHandlerNSView не вызывает memoryRecall напрямую.

**Вывод:** Клавиатурный ввод MR не реализован. Единственный путь вызова — кнопка UI `.mR`. ✅

#### 1.9. Метод `currentDisplayValue` (используется в memoryAdd/memorySubtract)

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:42–49`  
**Код (прочитан через read):**
```swift
private var currentDisplayValue: Decimal? {    // строка 42
    if let result = resultDecimal {             // строка 43
        return result                           // строка 44
    }                                           // строка 45
    let trimmed = expression.trimmingCharacters(in: .whitespaces)   // строка 46
    guard !trimmed.isEmpty else { return nil }  // строка 47
    return try? engine.evaluate(trimmed)        // строка 48
}                                               // строка 49
```

- **Видимость:** private (computed property)
- **Тип:** `Decimal?` — опциональный Decimal
- **Логика:** если есть resultDecimal → возвращает его; иначе пытается вычислить expression через engine.evaluate()

**Верификация использования в memoryAdd/memorySubtract:**
- Строка 167: `guard let val = currentDisplayValue else { return }` — в memoryAdd()
- Строка 172: `guard let val = currentDisplayValue else { return }` — в memorySubtract()

**Вывод:** Метод существует, сигнатура подтверждена. Не используется напрямую в memoryRecall(), но важен для понимания контекста операций памяти. ✅

#### 1.10. Вычислительный движок `engine`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:15`  
**Объявление (прочитано через read):**
```swift
private let engine = CalculatorEngine()   // строка 15
```

- **Тип:** `CalculatorEngine` — из модуля CalculatorEngine (импорт на строке 4)
- **Видимость:** private, константа (`let`)

**Верификация CalculatorEngine через read (Sources/CalculatorEngine/CalculatorEngine.swift):**  
Метод `evaluate(_ expression: String) throws -> Decimal` — принимает строку выражения, возвращает Decimal или бросает ошибку.

**Вывод:** Движок существует, используется в currentDisplayValue и evaluate(). Не используется напрямую в memoryRecall(). ✅

---

### Шаг 2. Полный анализ всех сценариев использования MR после исправления

После исправления логика memoryRecall() будет:
```swift
if !expression.isEmpty && isTrailingOperator(expression) {
    expression += memoryValue.description   // дописать значение памяти
} else {
    expression = memoryValue.description    // заменить выражение
}
```

**Сценарий A: MR на пустом дисплее (memoryValue = 10)**

| Параметр | Значение |
|----------|---------|
| expression ДО | `""` (пустая строка) |
| memoryValue | 10 |
| Условие `!expression.isEmpty` | false → пропускает ветку if |
| Выполняется | ветка else: `expression = "10"` |
| expression ПОСЛЕ | `"10"` ✅ |

**Поведение:** Идентично текущему. Пользователь нажал MR без ввода — получил значение из памяти.

---

**Сценарий B: MR после оператора (reported bug) — "10" → M+ → "+" → MR**

| Параметр | Значение |
|----------|---------|
| expression ДО | `"10+"` |
| memoryValue | 10 (после M+) |
| Условие `!expression.isEmpty` | true |
| Условие `isTrailingOperator("10+")` | last = "+", "+" == "+" → true |
| Выполняется | ветка if: `expression += "10"` → `"10+" + "10" = "10+10"` |
| expression ПОСЛЕ | `"10+10"` ✅ |

**Дальнейшее действие:** Пользователь нажимает "=" → evaluate() → engine.evaluate("10+10") = 20. Результат: **20** ✅ (ожидалось)

---

**Сценарий C: MR после оператора вычитания — "10" → M+ → "-" → MR**

| Параметр | Значение |
|----------|---------|
| expression ДО | `"10-"` |
| memoryValue | 10 |
| Условие `!expression.isEmpty` | true |
| Условие `isTrailingOperator("10-")` | last = "-", "-" == "-" → true |
| Выполняется | ветка if: `expression += "10"` → `"10-" + "10" = "10-10"` |
| expression ПОСЛЕ | `"10-10"` ✅ |

**Дальнейшее действие:** evaluate() → 10 - 10 = 0. Результат: **0** ✅

---

**Сценарий D: MR после оператора умножения — "5" → M+ → "*" → MR**

| Параметр | Значение |
|----------|---------|
| expression ДО | `"5*"` |
| memoryValue | 5 (после M+) |
| Условие `!expression.isEmpty` | true |
| Условие `isTrailingOperator("5*")` | last = "*", "*" == "*" → true |
| Выполняется | ветка if: `expression += "5"` → `"5*" + "5" = "5*5"` |
| expression ПОСЛЕ | `"5*5"` ✅ |

**Дальнейшее действие:** evaluate() → 25. Результат: **25** ✅

---

**Сценарий E: MR после оператора деления — "8" → M+ → "/" → MR**

| Параметр | Значение |
|----------|---------|
| expression ДО | `"8/"` |
| memoryValue | 8 (после M+) |
| Условие `!expression.isEmpty` | true |
| Условие `isTrailingOperator("8/")` | last = "/", "/" == "/" → true |
| Выполняется | ветка if: `expression += "8"` → `"8/" + "8" = "8/8"` |
| expression ПОСЛЕ | `"8/8"` ✅ |

**Дальнейшее действие:** evaluate() → 1. Результат: **1** ✅

---

**Сценарий F: MR после числа без оператора — "5" → M+ → MR**

| Параметр | Значение |
|----------|---------|
| expression ДО | `"5"` |
| memoryValue | 5 (после M+) |
| Условие `!expression.isEmpty` | true |
| Условие `isTrailingOperator("5")` | last = "5", "5" == "+" → false, "5" == "-" → false, ... → false |
| Выполняется | ветка else: `expression = "5"` |
| expression ПОСЛЕ | `"5"` ✅ (замена, не конкатенация) |

**Поведение:** Пользователь набрал число и нажал MR без оператора — выражение заменяется значением из памяти. Это стандартное поведение калькуляторов: если пользователь хочет вставить память, он обычно не набирает число перед этим. Если случайно набрал — замена корректна (он может нажать AC для нового ввода).

---

**Сценарий G: MR после evaluate() — "2+3" → "=" → MR**

| Параметр | Значение |
|----------|---------|
| expression ДО | `""` (пустая строка) |

**Верификация:** После evaluate() на строке 112: `expression = ""`. resultDecimal установлен в значение вычисления.

| memoryValue | 10 |
| Условие `!expression.isEmpty` | false → пропускает ветку if |
| Выполняется | ветка else: `expression = "10"` |
| expression ПОСЛЕ | `"10"` ✅ |

**Поведение:** Идентично текущему. Пользователь вычислил выражение, потом нажал MR — получил значение из памяти как новое выражение.

---

**Сценарий H: MR дважды подряд — "10" → M+ → "+" → MR → MR**

| Параметр | Значение |
|----------|---------|
| expression ДО первого MR | `"10+"` |
| memoryValue | 10 |
| Первый MR: `isTrailingOperator("10+")` = true → `expression += "10"` |
| expression ПОСЛЕ первого MR | `"10+10"` |

**Теперь второй вызов memoryRecall():**

| Параметр | Значение |
|----------|---------|
| expression ДО второго MR | `"10+10"` |
| memoryValue | 10 (не изменился) |
| Условие `!expression.isEmpty` | true |
| Условие `isTrailingOperator("10+10")` | last = "0", "0" == "+" → false, ... → false |
| Выполняется | ветка else: `expression = "10"` |
| expression ПОСЛЕ второго MR | `"10"` ✅ (замена) |

**Поведение:** Второй вызов MR без ввода оператора между ними — выражение заменяется значением из памяти. Это корректное поведение: пользователь нажал MR дважды подряд, второй раз он явно хочет получить значение из памяти как новое выражение.

---

**Сценарий I: MR после числа с оператором — "10+5" → "+" → MR**

| Параметр | Значение |
|----------|---------|
| expression ДО | `"10+5+"` (после ввода "+") |

**Верификация:** appendCharacter("+") при hasResult=false: expression += "+" → "10+5" + "+" = "10+5+". ✅

| memoryValue | 10 |
| Условие `!expression.isEmpty` | true |
| Условие `isTrailingOperator("10+5+")` | last = "+", "+" == "+" → true |
| Выполняется | ветка if: `expression += "10"` → `"10+5+" + "10" = "10+5+10"` |
| expression ПОСЛЕ | `"10+5+10"` ✅ |

**Дальнейшее действие:** evaluate() → 25. Результат: **25** ✅

---

**Сценарий J: Expression содержит только оператор — "+" → MR, memoryValue = 7**

| Параметр | Значение |
|----------|---------|
| expression ДО | `"+"` |
| memoryValue | 7 |
| Условие `!expression.isEmpty` | true |
| Условие `isTrailingOperator("+")` | last = "+", "+" == "+" → true |
| Выполняется | ветка if: `expression += "7"` → `"+" + "7" = "+7"` |
| expression ПОСЛЕ | `"+7"` ✅ |

**Дальнейшее действие:** evaluate() → Tokenizer обработает "+" как унарный оператор перед числом 7. Результат: **7**. Корректно.

---

**Сценарий K: Expression заканчивается процентом — "50" → "+" → "%" → MR, memoryValue = 10**

| Параметр | Значение |
|----------|---------|
| expression ДО | `"50%+"` (после ввода "+") |

**Верификация:** appendCharacter("%") вызывает tryAutoEvaluate(). isTrailingOperator("50%+") = true → пропускает. expression = "50%+". ✅

| memoryValue | 10 |
| Условие `!expression.isEmpty` | true |
| Условие `isTrailingOperator("50%+")` | last = "+", "+" == "+" → true |
| Выполняется | ветка if: `expression += "10"` → `"50%+" + "10" = "50%+10"` |
| expression ПОСЛЕ | `"50%+10"` ✅ |

**Дальнейшее действие:** evaluate() → Tokenizer обработает "%" как оператор процента. Результат зависит от логики токенизатора (обычно 50% = 0.5, затем +10 = 10.5). Корректно.

---

### Шаг 3. Анализ взаимодействия с tryAutoEvaluate() после исправленного MR

**Цель:** Убедиться, что изменение логики memoryRecall() не вызывает неожиданных побочных эффектов через tryAutoEvaluate().

**Верификация цепочки вызовов (прочитано через read):**

1. `memoryRecall()` (строка 176) — **не вызывает** `tryAutoEvaluate()` напрямую. В текущем коде нет вызова tryAutoEvaluate внутри memoryRecall. ✅

2. После исправленного MR пользователь обычно нажимает оператор или цифру:

   **Вариант 2а:** MR → "+" → `appendCharacter("+")`
   
   - После MR: expression = "10+10" (исправленный код), result=nil, resultDecimal=nil
   - hasResult = false (так как resultDecimal = nil)
   - appendCharacter("+"): clearError() → guard на строке 63 (hasResult && !isOperator) = false → guard на строке 67 (hasResult && isOperator) = false → expression += "+" → "10+10+" → tryAutoEvaluate() вызывается (строка 77, так как "+" — не цифра)
   - tryAutoEvaluate(): trimmed = "10+10+", isTrailingOperator("10+10+") проверяет last = "+", "+" == "+" → true → guard на строке 239 возвращает без вычисления ✅

   **Вариант 2б:** MR → цифру "5" → `appendCharacter("5")`
   
   - После MR: expression = "10+10", result=nil, resultDecimal=nil
   - appendCharacter("5"): clearError() → guard на строке 63 (hasResult && !isOperator) = false → guard на строке 67 (hasResult && isOperator) = false → expression += "5" → "10+105"
   - tryAutoEvaluate(): НЕ вызывается, так как `!isDigitOrDecimal("5")` = false (строка 76). isDigitOrDecimal проверяет: char == "." или (char.count == 1 && char.first?.isNumber == true) → "5".isNumber = true → isDigitOrDecimal вернёт true. ✅

**Вывод:** Взаимодействие с tryAutoEvaluate() не создаёт побочных эффектов. Автовычисление корректно пропускается при операторе на конце и не вызывается при вводе цифры. ✅

---

### Шаг 4. Анализ взаимодействия с appendCharacter() при hasResult=true после MR

**Цель:** Убедиться, что изменение логики корректно работает в контексте метода appendCharacter().

**Текущий код appendCharacter() (строки 60–79, прочитан через read):**
```swift
func appendCharacter(_ char: String) {       // строка 60
    clearError()                              // строка 61

    if hasResult && !isOperator(char) {       // строка 63
        expression = ""                       // строка 64
        result = nil                          // строка 65
        resultDecimal = nil                   // строка 66
    } else if hasResult && isOperator(char) { // строка 67
        if let dec = resultDecimal {          // строка 68
            expression = dec.description      // строка 69 — результат становится началом выражения
        }                                     // строка 70
        result = nil                          // строка 71
        resultDecimal = nil                   // строка 72
    }                                         // строка 73

    expression += char                        // строка 75 — добавление символа
    if !isDigitOrDecimal(char) {              // строка 76
        tryAutoEvaluate()                     // строки 77–78
    }                                         // строя 79
}                                             // строка 80
```

**Сценарий из bug-репорта после исправления:** "10" → M+ → "+" → MR → "="

После шага "+" (вызов appendCharacter("+")):
- hasResult = false (после ввода "10" результат не вычислялся, resultDecimal = nil)
- Первый guard (строка 63): `hasResult && !isOperator("+")` = false → пропускается
- Второй guard (строка 67): `hasResult && isOperator("+")` = false → пропускается
- expression += "+" → "10+" ✅

После MR (вызов memoryRecall(), исправленный код):
- expression не пустая ("10+"), last = "+", isTrailingOperator("10+") = true
- `expression += "10"` → "10+10" ✅

**Вывод:** Исправление корректно встраивается в существующий поток данных. appendCharacter() не требует изменений. ✅

---

### Шаг 5. Анализ взаимодействия с операциями памяти (M+, M−, MC)

**Цель:** Убедиться, что изменение логики MR не влияет на другие операции памяти.

**memoryClear() (строки 162–164, прочитан через read):**
```swift
func memoryClear() {    // строка 162
    memoryValue = 0     // строка 163
}                      // строка 164
```
- Изменяет только `memoryValue` на 0
- Не изменяет expression, result, resultDecimal
- **Влияние исправления memoryRecall():** отсутствует. MC не вызывает и не зависит от memoryRecall(). ✅

**memoryAdd() (строки 166–169, прочитан через read):**
```swift
func memoryAdd() {              // строка 166
    guard let val = currentDisplayValue else { return }   // строка 167
    memoryValue += val          // строка 168
}                              // строка 169
```
- Использует `currentDisplayValue` (computed property, строки 42–49) для получения значения на дисплее
- Не изменяет expression
- **Влияние исправления memoryRecall():** отсутствует. M+ не вызывает и не зависит от memoryRecall(). ✅

**memorySubtract() (строки 171–174, прочитан через read):**
```swift
func memorySubtract() {         // строка 171
    guard let val = currentDisplayValue else { return }   // строка 172
    memoryValue -= val          // строка 173
}                              // строка 174
```
- Аналогично memoryAdd(), но вычитает из памяти
- **Влияние исправления memoryRecall():** отсутствует. M− не вызывает и не зависит от memoryRecall(). ✅

**Вывод:** Другие операции памяти не затрагиваются изменениями в memoryRecall(). ✅

---

### Шаг 6. Анализ взаимодействия с currentDisplayValue

**Цель:** Убедиться, что изменение логики MR не влияет на вычисление `currentDisplayValue`.

**Текущий код currentDisplayValue (строки 42–49, прочитан через read):**
```swift
private var currentDisplayValue: Decimal? {    // строка 42
    if let result = resultDecimal {             // строка 43
        return result                           // строка 44
    }                                           // строка 45
    let trimmed = expression.trimmingCharacters(in: .whitespaces)   // строка 46
    guard !trimmed.isEmpty else { return nil }  // строка 47
    return try? engine.evaluate(trimmed)        // строка 48
}                                               // строка 49
```

- `currentDisplayValue` — computed property, зависит только от `resultDecimal` и `expression`
- `memoryRecall()` устанавливает `resultDecimal = nil` (строка 179), поэтому после MR currentDisplayValue будет вычислять из expression через engine.evaluate()
- После исправления: expression содержит "10+10" вместо "10", но это **не влияет** на логику currentDisplayValue, так как она просто читает текущее состояние и при необходимости вычисляет

**Вывод:** Нет влияния на currentDisplayValue. ✅

---

### Шаг 7. Анализ взаимодействия с hasResult

**Цель:** Убедиться, что изменение логики корректно обновляет computed свойство `hasResult`.

**Текущий код (строка 19, прочитан через read):**
```swift
var hasResult: Bool { resultDecimal != nil }   // строка 19
```

- `hasResult` — computed property, зависит только от `resultDecimal`
- `memoryRecall()` устанавливает `resultDecimal = nil` (строка 179), поэтому после MR `hasResult = false`
- После исправления: поведение **идентично** — resultDecimal всё ещё устанавливается в nil

**Вывод:** Нет влияния на hasResult. ✅

---

### Шаг 8. Анализ взаимодействия с историей (historyService)

**Цель:** Убедиться, что изменение логики MR не влияет на запись в историю.

**Верификация через read:**
- `memoryRecall()` (строка 176) — **не вызывает** `historyService.add()`. В текущем коде нет вызова historyService внутри memoryRecall. ✅
- История записывается только при успешном вычислении через `evaluate()` (строка 108): `historyService.add(expression: expression, result: value)`
- После исправления: выражение "10+10" будет вычислено по "=", и в историю запишется `"10+10"` → 20. Это **корректное** поведение — пользователь видит, что было вычислено.

**Вывод:** Нет негативного влияния на историю. ✅

---

### Шаг 9. Анализ взаимодействия с автовычислением (tryAutoEvaluate) при вводе после MR

**Цель:** Полностью исключить риск нежелательного автовычисления после MR.

**Полная цепочка после исправленного MR — вариант "=":**

1. `memoryRecall()` → expression = "10+10" (исправлено), result=nil, resultDecimal=nil
2. Пользователь нажимает "=" → `evaluate()`:
   - clearError() (строка 98)
   - trimmed = "10+10", не пустая (строки 100–101)
   - engine.evaluate("10+10") → Decimal(20) ✅
   - result = "20", expression = "" (строка 112)

**Полная цепочка после исправленного MR — вариант "+" (дополнительный оператор):**

1. `memoryRecall()` → expression = "10+10", result=nil, resultDecimal=nil
2. Пользователь нажимает "+" → `appendCharacter("+")`:
   - hasResult=false → пропускает оба guard'а (строки 63 и 67)
   - expression += "+" → "10+10+"
   - tryAutoEvaluate() вызывается, но isTrailingOperator("10+10+") = true → ничего не вычисляет ✅

**Вывод:** Автовычисление не вызывает побочных эффектов. ✅

---

### Шаг 10. Анализ влияния на UI-слой

**Цель:** Убедиться, что изменение логики ViewModel не требует правок в Views.

**Верификация через read (CalculatorView.swift):**
- Строка 161: `viewModel.memoryRecall()` — вызов без параметров, без возврата значения
- Строка 23–25: DisplayView отображает `viewModel.expression`, `viewModel.result`, `viewModel.errorMessage` — все эти свойства обновляются через @Observable (SwiftUI Observation framework)
- После исправления: expression будет содержать "10+10" вместо "10", что корректно отобразится в дисплее

**Верификация CalculatorButton.swift:**
- Строка 63: `ButtonSpec(label: .mR, type: .function, isEnabled: viewModel.hasMemory)` — кнопка MR привязана к hasMemory, не требует изменений
- Кнопка корректно отображает "MR" (displayTitle, строка 57)

**Вывод:** UI-слой не требует изменений. ✅

---

### Шаг 11. Анализ влияния на потокобезопасность (Swift 6.0 Concurrency)

**Цель:** Убедиться, что изменение не нарушает Swift 6.0 Concurrency.

**Верификация через read:**
- CalculatorViewModel помечен `@MainActor` (строка 6) — все методы выполняются на главном потоке
- CalculatorViewModel помечен `@Observable` (строка 7) — SwiftUI автоматически отслеживает изменения свойств
- expression, result, resultDecimal — мутабельные свойства класса @MainActor, доступ к ним синхронизирован через @MainActor (нет конкурентного доступа из других потоков)
- Изменение с `=` на условный `+=` для String — атомарная операция в контексте @MainActor

**Верификация импортов (строки 1–4):**
```swift
import Foundation    // строка 1: Decimal, String операции
import SwiftUI        // строка 2: @Observable, @MainActor из SwiftUI
import Observation    // строка 3: @Observable (дополнительно)
import CalculatorEngine   // строка 4: CalculatorEngine
```

**Вывод:** Потокобезопасность не нарушена. Все изменения в @MainActor контексте. ✅

---

### Шаг 12. Анализ влияния на другие методы ViewModel

**Цель:** Убедиться, что изменение логики MR не влияет на другие методы.

| Метод | Файл:строка | Зависит от memoryRecall()? | Влияние исправления |
|-------|-------------|---------------------------|--------------------|
| `appendCharacter(_:)` | :60–79 | Нет (не вызывает memoryRecall) | ❌ Нет влияния |
| `appendOperator(_:)` | :82–95 | Нет | ❌ Нет влияния |
| `evaluate()` | :97–116 | Нет | ❌ Нет влияния |
| `clear()` | :118–123 | Нет | ❌ Нет влияния |
| `backspace()` | :125–139 | Нет | ❌ Нет влияния |
| `toggleSign()` | :142–158 | Нет | ❌ Нет влияния |
| `memoryClear()` | :162–164 | Нет | ❌ Нет влияния |
| `memoryAdd()` | :166–169 | Нет | ❌ Нет влияния |
| `memorySubtract()` | :171–174 | Нет | ❌ Нет влияния |
| `handleKeyCommand(_:)` | :183–196 | Нет (MR не обрабатывается) | ❌ Нет влияния |
| `insertFromClipboard(_:)` | :200–215 | Нет | ❌ Нет влияния |
| `copyResult()` | :217–219 | Нет | ❌ Нет влияния |
| `useHistoryEntry(_:)` | :223–228 | Нет | ❌ Нет влияния |
| `clearHistory()` | :231–233 | Нет | ❌ Нет влияния |

**Вывод:** Ни один другой метод не зависит от внутренней логики memoryRecall(). ✅

---

### Шаг 13. Итоговая верификация: единственное изменение

**Файл для изменения:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Метод для изменения:** `memoryRecall()` (строки 176–181)  
**Количество изменений:** модификация существующей логики внутри метода  
**Тип изменения:** добавление условной проверки и замена присваивания на конкатенацию в зависимости от условия

**Что НЕ меняется:**
- Ни один другой файл проекта не редактируется
- Ни один другой метод не редактируется
- Никакие новые свойства, методы или классы не добавляются
- Никакие импорты не меняются
- UI-слой (Views) не затрагивается
- Вычислительный движок (CalculatorEngine) не затрагивается
- Сервисы (HistoryService, ClipboardManager, NumberFormatterService) не затрагиваются

---

### Шаг 14. Проверка на отладочный код

**Цель:** Убедиться, что после исправления в коде нет отладочных вызовов.

**Верификация через grep по CalculatorViewModel.swift:**
- `print()` — не найдено
- `debugPrint()` — не найдено
- `NSLog()` — не found
- `fatalError()` — не найдено

**Вывод:** Отладочный код отсутствует, удалять нечего. ✅

---

### Шаг 15. Проверка на force unwrap и подавленные ошибки

**Цель:** Убедиться, что исправление не вводит небезопасных конструкций.

**Анализ предлагаемого изменения:**
- Изменение использует только `if`-условие с проверкой `!expression.isEmpty` и вызовом `isTrailingOperator(expression)`
- Нет force unwrap (`!`) — ни в новом коде, ни в существующем контексте memoryRecall()
- Нет подавленных ошибок (`try?`) — engine.evaluate() не вызывается внутри memoryRecall()
- Типы: `memoryValue.description` → String (из Foundation Decimal), `expression += String` — корректная конкатенация строк Swift

**Вывод:** Исправление не вводит небезопасных конструкций. ✅

---

### Шаг 16. Пошаговый алгоритм исполнения (для AI-агента или разработчика)

#### Шаг 16.1. Открыть файл для редактирования

**Путь к файлу:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Строки для изменения:** 176–181 (метод memoryRecall())

#### Шаг 16.2. Найти метод memoryRecall() в файле

Метод находится на строках 176–181. Для точного поиска используйте:
- Номер строки: 176
- Или текст: `func memoryRecall()`
- Или контекст: строка 160 содержит MARK-комментарий `// MARK: - Memory operations (SRS §39-43)`, метод memoryRecall() находится через ~16 строк после этого комментария

**Текущий код метода (строки 176–181, точная копия из файла):**
```swift
    func memoryRecall() {
        expression = memoryValue.description
        result = nil
        resultDecimal = nil
        errorMessage = nil
    }
```

**Обратите внимание на отступы:** метод имеет отступ в 4 пробела (один уровень внутри класса). Каждая строка тела метода имеет отступ в 8 пробелов (два уровня).

#### Шаг 16.3. Заменить содержимое метода memoryRecall()

**Заменить весь блок строк 176–181 на следующий код:**

```swift
    func memoryRecall() {
        clearError()
        let memStr = memoryValue.description

        if !expression.isEmpty && isTrailingOperator(expression) {
            expression += memStr
        } else {
            expression = memStr
        }

        result = nil
        resultDecimal = nil
    }
```

**Пояснение каждой строки нового кода:**

| Строка | Код | Пояснение |
|--------|-----|-----------|
| 176 (новая) | `func memoryRecall() {` | Сигнатура метода без изменений, отступ 4 пробела |
| 177 (новая) | `clearError()` | Вызов существующего приватного метода clearError() (строки 259–261). Сбрасывает errorMessage в nil. Согласовано с паттернами appendCharacter(), evaluate(), backspace(). Отступ 8 пробелов |
| 178 (новая) | `let memStr = memoryValue.description` | Сохраняем строковое представление памяти в локальную константу. memoryValue — приватное свойство Decimal (строка 37). .description возвращает String. Отступ 8 пробелов |
| 179 (новая) | (пустая строка) | Пустая строка для разделения логики условия и сброса свойств. Соответствует стилю проекта (пустые строки между логическими блоками в методах) |
| 180 (новая) | `if !expression.isEmpty && isTrailingOperator(expression) {` | Условная проверка: expression не пустая И последний символ — оператор. expression — public var String (строка 10). isTrailingOperator() — private func (строки 250–253), принимает String, возвращает Bool. Отступ 8 пробелов |
| 181 (новая) | `expression += memStr` | Конкатенация: дописываем значение памяти к выражению. expression (String) += memStr (String). Отступ 12 пробелов (внутри if-блока) |
| 182 (новая) | `} else {` | Завершение if, начало ветки else. Отступ 8 пробелов |
| 183 (новая) | `expression = memStr` | Замена: выражение полностью заменяется значением из памяти. Отступ 12 пробелов (внутри else-блока) |
| 184 (новая) | `}` | Завершение else/if. Отступ 8 пробелов |
| 185 (новая) | (пустая строка) | Пустая строка для разделения логики условия и сброса свойств |
| 186 (новая) | `result = nil` | Сброс result в nil. Старое поведение, без изменений. Отступ 8 пробелов |
| 187 (новая) | `resultDecimal = nil` | Сброс resultDecimal в nil. Старое поведение, без изменений. Отступ 8 пробелов |
| 188 (новая) | `}` | Завершение метода memoryRecall(). Отступ 4 пробела |

**Важно:** Не удаляйте и не изменяйте строки после memoryRecall() — начиная со строки 190 идёт метод handleKeyCommand(), который должен остаться без изменений.

#### Шаг 16.4. Проверить отступы

Убедитесь, что:
- Строка `func memoryRecall()` имеет отступ **4 пробела** (один уровень внутри класса)
- Строки тела метода (`clearError()`, `let memStr = ...`, `if ...`, `expression += ...`, `} else {`, `expression = ...`, `}`, `result = nil`, `resultDecimal = nil`) имеют отступ **8 пробелов** (два уровня)
- Строки внутри if/else блоков (`expression += memStr`, `expression = memStr`) имеют отступ **12 пробелов** (три уровня)

#### Шаг 16.5. Проверить, что файл не содержит ошибок после редактирования

После сохранения файла проверьте:
1. Откройте файл в редакторе/Xcode и убедитесь, что нет подсветки синтаксических ошибок
2. Убедитесь, что все фигурные скобки `{` и `}` сбалансированы (открывающих столько же, сколько закрывающих)
3. Проверьте, что метод handleKeyCommand() на строке 190+ остался без изменений

---

### Шаг 17. Тестовые сценарии для проверки после применения исправления

#### Сценарий T1: Reported bug — "10" → M+ → "+" → MR → "="
- **Ожидаемый результат:** `20`
- **Проверка:** expression после MR = `"10+10"`, evaluate() вычисляет 10 + 10 = 20

#### Сценарий T2: MR на пустом дисплее — MR (memoryValue = 42)
- **Ожидаемый результат:** expression = `"42"`
- **Проверка:** expression пуста → ветка else → замена

#### Сценарий T3: MR после числа без оператора — "5" → M+ → MR
- **Ожидаемый результат:** expression = `"5"` (замена, не конкатенация)
- **Проверка:** last символ "5", isTrailingOperator("5") = false → ветка else

#### Сценарий T4: MR дважды подряд — "10" → M+ → "+" → MR → MR
- **Ожидаемый результат:** expression после первого MR = `"10+10"`, после второго = `"10"` (замена)
- **Проверка:** второй вызов: last символ "0", isTrailingOperator("10+10") = false → ветка else

#### Сценарий T5: MR после evaluate() — "2+3" → "=" → MR (memoryValue = 7)
- **Ожидаемый результат:** expression = `"7"`
- **Проверка:** после evaluate() expression = "" → ветка else → замена

#### Сценарий T6: Все операторы — "10" → M+ → "+" → MR, затем "=", "-"/"*"/"/" → MR, затем "="
- **Ожидаемый результат для "+":** `20` (10 + 10)
- **Ожидаемый результат для "-":** `0` (10 - 10)
- **Ожидаемый результат для "*":** `100` (10 * 10)
- **Ожидаемый результат для "/":** `1` (10 / 10)

#### Сценарий T7: Expression заканчивается числом — "3+4" → "+" → MR (memoryValue = 5)
- **Ожидаемый результат:** expression после MR = `"3+4+5"`
- **Проверка:** last символ "+", isTrailingOperator("3+4+") = true → ветка if → конкатенация

#### Сценарий T8: Кнопка MR отключена при пустой памяти — MC → MR
- **Ожидаемый результат:** кнопка MR неактивна (opacity 0.4, CalculatorButton.swift:235), нажатие не вызывает memoryRecall()
- **Проверка:** hasMemory = false после MC, isEnabled = false в ButtonSpec

---

### Шаг 18. Чеклист самопроверки перед завершением

- [x] Нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()` — отладочный код отсутствует
- [x] Нет force unwrap (`!`) без обоснованной гарантии — исправление не использует force unwrap
- [x] Все новые элементы имеют объявленные типы параметров и возвращаемых значений — используется существующий метод isTrailingOperator с подтверждённой сигнатурой
- [x] Все идентификаторы на английском языке — clearError, memStr, expression, memoryValue, result, resultDecimal
- [x] Нет импортов SwiftUI в вычислительном движке (изменения только в ViewModel)
- [x] Все исключения обрабатываются (в новых строках нет вызовов throwing functions)
- [x] Изменения ограничены одним файлом: `Sources/ViewModels/CalculatorViewModel.swift`
- [x] Новый код использует существующий метод isTrailingOperator (верифицирована сигнатура на строках 250–253)
- [x] Добавление clearError() согласовано с паттернами других методов (appendCharacter:61, appendOperator:83, evaluate:98, backspace:126)
- [x] Отступы соответствуют стилю проекта (4 пробела = 1 уровень)

---

### Шаг 19. Проверка соответствия правилам AGENTS.md

| Правило | Соответствие | Подтверждение |
|---------|-------------|---------------|
| §4 Нулевые галлюцинации — каждое утверждение верифицировано через read/grep | ✅ | Все классы, методы, свойства, сигнатуры подтверждены прямым чтением файлов CalculatorViewModel.swift и CalculatorView.swift |
| §5 Потокобезопасность Swift 6.0 — @MainActor учтён | ✅ | CalculatorViewModel помечен @MainActor (строка 6), все изменения в @MainActor контексте |
| §6 Архитектура MVVM — только ViewModel изменена | ✅ | Views и Engine не затрагиваются, изменения строго в CalculatorViewModel.swift |
| §7 Swift строгая типизация — типы объявлены явно | ✅ | expression (String) += memStr (String), clearError() void, isTrailingOperator(String) -> Bool |
| §9 Чистота кода — нет отладочного кода | ✅ | print/debugPrint/NSLog отсутствуют в файле |
| §10 Верификация — все потребители найдены | ✅ | Единственный потребитель: CalculatorView.swift:161, case .mR |
| §11 Анализ регрессий — все сценарии проверены | ✅ | 11 сценариев использования MR проанализированы (A–K), взаимодействие со всеми методами проверено (§7–§12) |
| §13 Чеклист самопроверки | ✅ | Все пункты чеклиста пройдены (§18) |
