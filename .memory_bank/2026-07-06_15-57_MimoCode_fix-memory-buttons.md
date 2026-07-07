# План исправления кнопок памяти (MC, MR, M+, M−)

**Дата:** 2026-07-06  
**Агент:** MimoCode  
**Статус:** Готов к реализации  

---

## 1. Диагноз: что именно сломано

### 1.1. M+ и M− не работают до нажатия "="

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`, строки 135–142

```swift
func memoryAdd() {
    guard let val = resultDecimal else { return }  // ← ВОТ ТУТ ПРОБЛЕМА
    memoryValue += val
}
```

`resultDecimal` устанавливается **только** при вызове `evaluate()` (строка 80) или `tryAutoEvaluate()` (строка 214). Если пользователь ввёл число и нажал M+ **без нажатия =**, `resultDecimal == nil` → `guard` срабатывает → метод молча ничего не делает.

**Сценарий:** Ввёл `42`, нажал M+ — ничего не происходит. Ввёл `15+16`, нажал M+ — тоже ничего. Это и есть «не работают вовсе».

### 1.2. MR не настраивает состояние для продолжения вычислений

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`, строки 145–149

```swift
func memoryRecall() {
    expression = memoryValue.description
    result = nil          // ← result == nil
    errorMessage = nil
    // resultDecimal НЕ устанавливается!
}
```

После MR: `expression = "5"`, `result = nil`, `resultDecimal = nil`. Свойство `hasResult` (строка 19) возвращает `false`, потому что `resultDecimal == nil`.

**Сценарий:** MR (память=5), затем нажатие цифры `3`:
- `appendCharacter("3")` → `hasResult == false` → просто дописывает `3` в expression → `expression = "53"` → **неправильно**, должно стать `"3"`.

### 1.3. Нет визуальной индикации состояния памяти

Все четыре кнопки памяти отображаются одинаково всегда. Стандартное поведение калькуляторов: MC и MR затемняются, когда память пуста (memoryValue == 0).

---

## 2. Архитектурно верное решение

### 2.1. Принцип: память работает с «текущим отображаемым значением»

Текущее отображаемое значение — это либо `resultDecimal` (после вычисления), либо результат автоматического вычисления текущего выражения. Вычислительный движок уже доступен через `engine.evaluate()`, поэтому M+/M− должны сами вычислять выражение при необходимости.

### 2.2. Добавить computed property `currentDisplayValue`

Новое приватное свойство в `CalculatorViewModel`:

```swift
/// Текущее значение на дисплее для операций памяти.
/// Если есть resultDecimal — возвращает его.
/// Если есть выражение — пытается вычислить.
private var currentDisplayValue: Decimal? {
    if let result = resultDecimal {
        return result
    }
    let trimmed = expression.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    return try? engine.evaluate(trimmed)
}
```

**Верификация:** `CalculatorEngine.evaluate(_:)` объявлен как `public func evaluate(_ expression: String) throws -> Decimal` (файл `Sources/CalculatorEngine/CalculatorEngine.swift`, строка 7). Доступен из `CalculatorViewModel`, который импортирует `CalculatorEngine` (строка 4). Метод создаёт новые экземпляры Tokenizer/Parser/Evaluator при каждом вызове — stateless, потокобезопасен.

### 2.3. Исправить `memoryAdd()` и `memorySubtract()`

```swift
func memoryAdd() {
    guard let val = currentDisplayValue else { return }
    memoryValue += val
}

func memorySubtract() {
    guard let val = currentDisplayValue else { return }
    memoryValue -= val
}
```

**Верификация:** `currentDisplayValue` использует `resultDecimal` (свойство `CalculatorViewModel`, строка 12) и `engine` (строка 15). Оба существуют и доступны.

### 2.4. Исправить `memoryRecall()`

MR должен установить **и** `expression`, **и** `resultDecimal`/`result`, чтобы `hasResult` был `true` — тогда следующая цифра начнёт новое число, а оператор продолжит с recalled значением.

```swift
func memoryRecall() {
    expression = memoryValue.description
    result = formatter.format(memoryValue)
    resultDecimal = memoryValue
    errorMessage = nil
}
```

**Верификация:** `formatter` — это `NumberFormatterService.shared` (строка 17). Метод `format(_ value: Decimal) -> String` объявлен в `Sources/Formatting/NumberFormatterService.swift`. `memoryValue` — `Decimal` (строка 27).

**Трассировка сценария после исправления:**
1. MR (память=5): `expression="5"`, `result="5"`, `resultDecimal=5`, `hasResult=true`
2. Нажатие `3`: `appendCharacter("3")` → `hasResult==true` и `!isOperator("3")` → `expression=""`, `result=nil`, `resultDecimal=nil` → `expression += "3"` → `expression="3"` ✓
3. Нажатие `+`: `appendCharacter("+")` → `hasResult==false` → `expression += "+"` → `"3+"` ✓
4. Нажатие `5`: `appendCharacter("5")` → `expression="3+5"` → `tryAutoEvaluate` → `result="8"`, `resultDecimal=8` ✓
5. Нажатие `=`: `evaluate()` → `engine.evaluate("3+5")` = 8 → `result="8"` ✓

### 2.5. Добавить `hasMemory` для UI

Новое свойство:

```swift
var hasMemory: Bool { memoryValue != 0 }
```

**Верификация:** `memoryValue` — приватное свойство типа `Decimal` (строка 27). Computed property `hasMemory` будет доступна из View, потому что `CalculatorViewModel` — `@Observable` (строка 7), и все `var` свойства автоматически становятся наблюдаемыми.

---

## 3. Пошаговый план реализации

### Шаг 1. CalculatorViewModel — добавить `currentDisplayValue` и `hasMemory`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

**Место вставки:** После строки 27 (`private var memoryValue: Decimal = 0`), перед строкой 29 (`func appendCharacter`).

**Вставить:**

```swift
/// Значение, которое сейчас отображается на дисплее (для операций памяти)
private var currentDisplayValue: Decimal? {
    if let result = resultDecimal {
        return result
    }
    let trimmed = expression.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    return try? engine.evaluate(trimmed)
}

/// Есть ли непустое значение в памяти
var hasMemory: Bool { memoryValue != 0 }
```

### Шаг 2. CalculatorViewModel — исправить `memoryAdd()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

**Заменить** строки 135–138:
```swift
func memoryAdd() {
    guard let val = resultDecimal else { return }
    memoryValue += val
}
```

**Новой версией:**
```swift
func memoryAdd() {
    guard let val = currentDisplayValue else { return }
    memoryValue += val
}
```

### Шаг 3. CalculatorViewModel — исправить `memorySubtract()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

**Заменить** строки 140–143:
```swift
func memorySubtract() {
    guard let val = resultDecimal else { return }
    memoryValue -= val
}
```

**Новой версией:**
```swift
func memorySubtract() {
    guard let val = currentDisplayValue else { return }
    memoryValue -= val
}
```

### Шаг 4. CalculatorViewModel — исправить `memoryRecall()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

**Заменить** строки 145–149:
```swift
func memoryRecall() {
    expression = memoryValue.description
    result = nil
    errorMessage = nil
}
```

**Новой версией:**
```swift
func memoryRecall() {
    expression = memoryValue.description
    result = formatter.format(memoryValue)
    resultDecimal = memoryValue
    errorMessage = nil
}
```

### Шаг 5. CalculatorView — передать `hasMemory` в кнопки

**Файл:** `Sources/Views/CalculatorView.swift`

**5a.** В строке 59–64 (строка памяти кнопок) — изменить сигнатуру `ButtonSpec`, добавив параметр `isEnabled`:

Нет, `ButtonSpec` — это просто структура данных. Лучше добавить свойство `isEnabled` в `ButtonSpec`.

**Файл:** `Sources/Views/CalculatorButton.swift`, строка 105–110:

**Заменить:**
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false
}
```

**Новой версией:**
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false
    var isEnabled: Bool = true
}
```

**Верификация:** `ButtonSpec` используется в `CalculatorView.swift` (строки 59–106) и в `CalculatorButton.swift` (строка 116). Добавление свойства с дефолтным значением `true` не ломает существующие вызовы.

### Шаг 6. CalculatorView — передать `hasMemory` в memory кнопки

**Файл:** `Sources/Views/CalculatorView.swift`

**Заменить** строки 58–64:
```swift
// Строка 1: память
buttonRow([
    ButtonSpec(label: .mc,             type: .function),
    ButtonSpec(label: .mPlus,          type: .function),
    ButtonSpec(label: .mMinus,         type: .function),
    ButtonSpec(label: .mR,             type: .function),
])
```

**Новой версией:**
```swift
// Строка 1: память
buttonRow([
    ButtonSpec(label: .mc,             type: .function, isEnabled: viewModel.hasMemory),
    ButtonSpec(label: .mPlus,          type: .function),
    ButtonSpec(label: .mMinus,         type: .function),
    ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory),
])
```

**Обоснование:** MC и MR затемняются когда память пуста. M+ и M− всегда активны — даже при пустой памяти M+ с числом на дисплее запишет его.

### Шаг 7. CalculatorButton — применить `isEnabled`

**Файл:** `Sources/Views/CalculatorButton.swift`

**7a.** В структуре `CalculatorButton` (строка 114) добавить использование `isEnabled` в opacity:

Внутри `body` (после строки 191, перед закрывающей скобкой body), добавить `.opacity`:

```swift
.accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
.opacity(spec.isEnabled ? 1.0 : 0.4)
```

**Верификация:** `spec` доступен как свойство `CalculatorButton` (строка 116). `.opacity()` — стандартный SwiftUI-модификатор.

**7b.** В обработчике `Button` (строка 156) блокировать нажатие при `!isEnabled`:

**Заменить** строки 156–158:
```swift
Button {
    onTap(spec.label)
} label: {
```

**Новой версией:**
```swift
Button {
    guard spec.isEnabled else { return }
    onTap(spec.label)
} label: {
```

---

## 4. Итоговый файл `CalculatorViewModel.swift` — что меняется

| Строка (оригинал) | Что меняется |
|---|---|
| После 27 | Вставка `currentDisplayValue` (computed) и `hasMemory` (computed) |
| 136 | `resultDecimal` → `currentDisplayValue` в `memoryAdd()` |
| 141 | `resultDecimal` → `currentDisplayValue` в `memorySubtract()` |
| 145–149 | `memoryRecall()` — добавлены `result = formatter.format(memoryValue)` и `resultDecimal = memoryValue` |

## 5. Итоговый файл `CalculatorButton.swift` — что меняется

| Строка (оригинал) | Что меняется |
|---|---|
| 105–110 | `ButtonSpec` — добавлено свойство `isEnabled: Bool = true` |
| 157 | В `Button.action` — добавлен `guard spec.isEnabled else { return }` |
| После 191 | Добавлен `.opacity(spec.isEnabled ? 1.0 : 0.4)` |

## 6. Итоговый файл `CalculatorView.swift` — что меняется

| Строка (оригинал) | Что меняется |
|---|---|
| 60 | `.mc` — добавлен `isEnabled: viewModel.hasMemory` |
| 63 | `.mR` — добавлен `isEnabled: viewModel.hasMemory` |

---

## 7. Проверка отсутствия неверифицированных элементов

| Элемент | Файл | Статус |
|---|---|---|
| `currentDisplayValue` | Добавляется в ViewModel (новый computed property) | Создаётся нами |
| `hasMemory` | Добавляется в ViewModel (новый computed property) | Создаётся нами |
| `resultDecimal` | ViewModel, строка 12 | Существует ✓ |
| `engine` | ViewModel, строка 15 | Существует ✓ |
| `formatter` | ViewModel, строка 17 | Существует ✓ |
| `memoryValue` | ViewModel, строка 27 | Существует ✓ |
| `expression` | ViewModel, строка 10 | Существует ✓ |
| `result` | ViewModel, строка 11 | Существует ✓ |
| `errorMessage` | ViewModel, строка 13 | Существует ✓ |
| `NumberFormatterService.format(_:)` | `NumberFormatterService.swift` | Существует ✓ |
| `CalculatorEngine.evaluate(_:)` | `CalculatorEngine.swift` | Существует ✓ |
| `ButtonSpec` | `CalculatorButton.swift`, строка 105 | Существует ✓ |
| `ButtonSpec.isEnabled` | Добавляется в ButtonSpec | Создаётся нами |
| `CalculatorButton.spec` | `CalculatorButton.swift`, строка 116 | Существует ✓ |
| `viewModel.hasMemory` | Добавляется в ViewModel | Создаётся нами |

---

## 8. Тестирование (ручные сценарии)

| № | Сценарий | Ожидаемый результат |
|---|---|---|
| 1 | Ввести `42`, нажать M+, нажать MC, нажать MR | Дисплей: `0` |
| 2 | Ввести `42`, нажать M+, нажать MR | Дисплей: `42` как результат |
| 3 | Ввести `42`, нажать M+, ввести `8`, нажать M+, нажать MR | Дисплей: `50` |
| 4 | Ввести `100`, нажать M+, ввести `30`, нажать M−, нажать MR | Дисплей: `70` |
| 5 | Ввести `15+16`, нажать M+ (без =), нажать MR | Дисплей: `31` (M+ вычислил выражение) |
| 6 | Нажать MR (память=5), затем нажать `3` | Дисплей: `3` (а не `53`) |
| 7 | Нажать MR (память=5), затем нажать `+`, затем `5`, затем `=` | Дисплей: `10` |
| 8 | Пустая память — MC и MR затемнены (opacity 0.4) | Визуально видно |
| 9 | M+ при пустом выражении и нет результата | Ничего не происходит (guard срабатывает) |
| 10 | Многократное нажатие M+ на одном числе | Память суммируется корректно |

---

*План создан на основе анализа всех исходных файлов, задействованных в цепочке памяти. Все утверждения верифифицированы по коду.*
