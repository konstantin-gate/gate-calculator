# Финальный план исправления кнопок памяти (MC, MR, M+, M−)

**Дата:** 2026-07-06  
**Агент:** OrnithQ8  
**Статус:** Готов к реализации младшим разработчиком  
**Задача:** Исправить некорректную работу всех четырёх кнопок памяти в GateCalc

---

## 0. Справочная информация: верифицированные элементы кода

Перед началом работы необходимо убедиться, что все ссылки на код соответствуют фактическим файлам. Ниже приведена таблица всех элементов, которые будут использоваться или изменяться в этом плане. Каждый элемент верифицирован путём чтения исходного файла.

| Элемент | Файл | Строка(и) | Статус верификации |
|---|---|---|---|
| `CalculatorViewModel` — класс с `@MainActor @Observable` | `Sources/ViewModels/CalculatorViewModel.swift` | 6–8 | Подтверждено: строки 6-8 содержат `@MainActor`, `@Observable`, `final class CalculatorViewModel` |
| `expression: String = ""` | Там же | 10 | Подтверждено |
| `result: String? = nil` | Там же | 11 | Подтверждено |
| `resultDecimal: Decimal? = nil` (internal) | Там же | 12 | Подтверждено |
| `errorMessage: String? = nil` | Там же | 13 | Подтверждено |
| `engine: CalculatorEngine` (private let) | Там же | 15 | Подтверждено: `private let engine = CalculatorEngine()` |
| `historyService` (private let) | Там же | 16 | Подтверждено: `private let historyService = HistoryService.shared` |
| `formatter: NumberFormatterService` (private let) | Там же | 17 | Подтверждено: `private let formatter = NumberFormatterService.shared` |
| `hasResult: Bool { resultDecimal != nil }` | Там же | 19 | Подтверждено |
| `memoryValue: Decimal = 0` (private var) | Там же | 27 | Подтверждено: `private var memoryValue: Decimal = 0` |
| `appendCharacter(_:)` | Там же | 29–48 | Подтверждено |
| `evaluate()` | Там же | 66–85 | Подтверждено |
| `clear()` | Там же | 87–92 | Подтверждено |
| `backspace()` | Там же | 94–108 | Подтверждено |
| `toggleSign()` | Там же | 111–127 | Подтверждено |
| `memoryClear()` | Там же | 131–133 | Подтверждено: `memoryValue = 0` |
| `memoryAdd()` | Там же | 135–138 | Подтверждено: `guard let val = resultDecimal else { return }; memoryValue += val` |
| `memorySubtract()` | Там же | 140–143 | Подтверждено: `guard let val = resultDecimal else { return }; memoryValue -= val` |
| `memoryRecall()` | Там же | 145–149 | Подтверждено: устанавливает `expression`, `result = nil`, `errorMessage = nil` — НЕ сбрасывает `resultDecimal` |
| `tryAutoEvaluate()` | Там же | 207–218 | Подтверждено: вызывает `engine.evaluate(expression)`, устанавливает `result` и `resultDecimal` |
| `isOperator(_:)` (private) | Там же | 225–227 | Подтверждено: проверяет `+`, `-`, `*`, `/`, `%` |
| `isDigitOrDecimal(_:)` (private) | Там же | 233–235 | Подтверждено: проверяет `.` и цифры |
| `CalculatorEngine.evaluate(_:) throws -> Decimal` (public) | `Sources/CalculatorEngine/CalculatorEngine.swift` | 23 | Подтверждено: `public func evaluate(_ expression: String) throws -> Decimal` |
| `CalculatorEngine` — struct, Sendable | Там же | 10 | Подтверждено: `public struct CalculatorEngine: Sendable` |
| `NumberFormatterService.shared` (static let) | `Sources/Formatting/NumberFormatterService.swift` | 5 | Подтверждено: `public static let shared = NumberFormatterService()` |
| `NumberFormatterService.format(_:) -> String` (public) | Там же | 29 | Подтверждено: `public func format(_ value: Decimal) -> String` |
| `ButtonSpec` — struct, Identifiable | `Sources/Views/CalculatorButton.swift` | 105–110 | Подтверждено: содержит `id`, `label`, `type`, `isWide` |
| `CalculatorButton.spec: ButtonSpec` (let) | Там же | 116 | Подтверждено |
| `CalculatorButton.body` (var body) | Там же | 175–221 | Подтверждено: содержит `Button { onTap(spec.label) } label: { ... }` на строках 179–204 |
| `CalculatorView.viewModel: CalculatorViewModel` (@Bindable) | `Sources/Views/CalculatorView.swift` | 7 | Подтверждено: `@Bindable var viewModel: CalculatorViewModel` |
| Кнопки памяти в UI (строка 1 сетки) | Там же | 59–64 | Подтверждено: `buttonRow([ ButtonSpec(label: .mc, type: .function), ButtonSpec(label: .mPlus, type: .function), ButtonSpec(label: .mMinus, type: .function), ButtonSpec(label: .mR, type: .function) ])` |
| `handleButtonPress(_:)` — маппинг `.mPlus` → `viewModel.memoryAdd()` | Там же | 156–157 | Подтверждено |
| `handleButtonPress(_:)` — маппинг `.mR` → `viewModel.memoryRecall()` | Там же | 160–161 | Подтверждено |
| `DisplayView` — отображает `result ?? expression ?? "0"` | `Sources/Views/DisplayView.swift` | 58 | Подтверждено: `let mainText = result ?? (expression.isEmpty ? "0" : expression)` |

---

## 1. Диагностика: что именно сломано и почему

### 1.1. Проблема A: M+ и M− не работают, если не было нажатия "="

**Текущий код `memoryAdd()` (CalculatorViewModel.swift, строки 135–138):**
```swift
func memoryAdd() {
    guard let val = resultDecimal else { return }   // ← БЛОКИРУЕТ вызов
    memoryValue += val
}
```

**Текущий код `memorySubtract()` (CalculatorViewModel.swift, строки 140–143):**
```swift
func memorySubtract() {
    guard let val = resultDecimal else { return }   // ← БЛОКИРУЕТ вызов
    memoryValue -= val
}
```

**Как `resultDecimal` оказывается со значением:**
- В методе `evaluate()` (строки 66–85), строка 80: `resultDecimal = value` — после нажатия "="
- В методе `tryAutoEvaluate()` (строки 207–218), строка 214: `resultDecimal = value` — при автоматическом вычислении (например, после ввода второго числа: "15+16" → результат 31)

**Что происходит, когда пользователь ввёл число и нажал M+ без "=":**
1. Пользователь вводит `42` → `expression = "42"`, `resultDecimal = nil` (автосравнение не срабатывает на одном числе, см. `tryAutoEvaluate` строка 209: `!isTrailingOperator(expression)` — но для "42" нет оператора, и выражение не вычисляется автоматически)
2. Пользователь нажимает M+ → вызывается `memoryAdd()` → `guard let val = resultDecimal` → `resultDecimal == nil` → `return` → **метод молча ничего не делает**

**Что происходит, когда пользователь ввёл выражение и нажал M+ без "=":**
1. Пользователь вводит `15+16` → `tryAutoEvaluate()` вызывается при вводе "6" (не оператор) → вычисляет `15+16 = 31` → `resultDecimal = 31`, `result = "31"`
2. Пользователь нажимает M+ → `memoryAdd()` → `guard let val = resultDecimal` → `val = 31` → `memoryValue += 31` → **работает**

**Вывод:** M+ и M− работают только если `resultDecimal` не nil. Это означает, что нужно либо нажать "=", либо чтобы выражение было полностью введено и автоматически вычислено. Если пользователь ввёл одно число (например, `42`) и нажал M+ — ничего не происходит.

### 1.2. Проблема B: MR не сбрасывает resultDecimal, что ломает продолжение вычислений

**Текущий код `memoryRecall()` (CalculatorViewModel.swift, строки 145–149):**
```swift
func memoryRecall() {
    expression = memoryValue.description     // устанавливает expression значением из памяти
    result = nil                              // сбрасывает отображаемый результат
    errorMessage = nil                        // сбрасывает ошибку
    // resultDecimal НЕ сбрасывается! ← ОШИБКА
}
```

**Почему это критично:** Свойство `hasResult` (строка 19) вычисляется как `resultDecimal != nil`. Метод `appendCharacter()` (строки 29–48) полностью определяет своё поведение на основе `hasResult`.

**Трассировка ошибки (конкретный сценарий):**

Исходное состояние: пользователь вычислил `15 + 16 =` → результат 31.
- `resultDecimal = 31`, `expression = ""`

Пользователь нажимает M+:
- `memoryAdd()` → `guard let val = resultDecimal` (31) → `memoryValue += 31` → `memoryValue = 31`

Пользователь вычислил `10 + 5 =` → результат 15.
- `resultDecimal = 15`, `expression = ""`

Пользователь нажимает MR:
- `memoryRecall()` → `expression = "31"`, `result = nil`, `errorMessage = nil`
- **НО `resultDecimal` остаётся равным 15!**

Состояние после MR:
- `expression = "31"` (значение из памяти)
- `resultDecimal = 15` (устаревшее значение от предыдущего вычисления!)
- `hasResult = true` (потому что `15 != nil`)

Пользователь нажимает `+` (оператор):
- Вызывается `appendCharacter("+")` (строка 29)
- Проверяет: `hasResult && isOperator("+")` → `true && true` → ветка на строках 36–42
- Выполняет: `if let dec = resultDecimal { expression = dec.description }` → `expression = "15"`
- Затем: `result = nil; resultDecimal = nil`
- Затем: `expression += "+"` → `expression = "15+"`

**Ожидалось:** `expression = "31+"` (продолжение выражения из памяти)  
**Получено:** `expression = "15+"` (используется устаревшее resultDecimal)

Пользователь вводит `20 =`:
- Вычисляется `15 + 20 = 35`
- **Ожидалось:** `31 + 20 = 51`

**Трассировка ошибки — вариант с цифрой после MR:**

После MR состояние: `expression = "31"`, `resultDecimal = 15`, `hasResult = true`

Пользователь нажимает `2` (цифра):
- Вызывается `appendCharacter("2")`
- Проверяет: `hasResult && !isOperator("2")` → `true && true` → ветка на строках 32–35
- Выполняет: `expression = ""`, `result = nil`, `resultDecimal = nil`
- Затем: `expression += "2"` → `expression = "2"`

**Ожидалось:** `expression = "312"` (продолжение ввода числа из памяти)  
**Получено:** `expression = "2"` (выражение из памяти потеряно)

### 1.3. Проблема C: Нет визуальной индикации состояния памяти

Все четыре кнопки памяти (MC, M+, M−, MR) отображаются одинаково всегда. Стандартное поведение калькуляторов: MC и MR затемняются (становятся неактивными), когда память пуста (`memoryValue == 0`).

---

## 2. Архитектурное решение: три изменения

### Изменение 1: Добавить computed property `currentDisplayValue` (решение проблемы A)

**Зачем:** M+ и M− должны работать с «текущим значением на дисплее» — будь то результат вычисления (`resultDecimal`) или результат автоматического вычисления текущего выражения. Вычислительный движок уже доступен через `engine.evaluate()`, который является stateless (создаёт новые экземпляры Tokenizer/Parser/Evaluator при каждом вызове, см. CalculatorEngine.swift строки 29–40).

**Где:** `CalculatorViewModel.swift`, после строки 27 (`private var memoryValue: Decimal = 0`), перед строкой 29 (`func appendCharacter`).

**Код для вставки:**
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

**Пояснение построчно:**
- Строка 1–2: comment, описывающий назначение свойства
- Строка 3: `private var` — computed property, тип `Decimal?` (опциональный Decimal)
- Строка 4: `if let result = resultDecimal` — если есть результат вычисления, возвращаем его
- Строка 5: `return result` — возврат значения
- Строка 6: закрывающая скобка if-let
- Строка 7: `let trimmed = expression.trimmingCharacters(in: .whitespaces)` — убираем пробелы по краям выражения. Метод `trimmingCharacters(in:)` — стандартный метод String из Foundation
- Строка 8: `guard !trimmed.isEmpty else { return nil }` — если выражение пустое (после удаления пробелов), возвращаем nil
- Строка 9: `return try? engine.evaluate(trimmed)` — пытаемся вычислить выражение. `try?` преобразует любое thrown error в nil (engine.evaluate бросает CalculatorError, см. CalculatorEngine.swift строка 26: `throw CalculatorError.emptyExpression`)

**Верификация зависимостей:**
- `resultDecimal` — существует, строка 12 CalculatorViewModel.swift ✓
- `expression` — существует, строка 10 CalculatorViewModel.swift ✓
- `engine` — существует, строка 15 CalculatorViewModel.swift: `private let engine = CalculatorEngine()` ✓
- `engine.evaluate(_:)` — существует, CalculatorEngine.swift строка 23: `public func evaluate(_ expression: String) throws -> Decimal` ✓
- `try?` — стандартный Swift-оператор, преобразует throw в nil ✓

### Изменение 2: Добавить computed property `hasMemory` (решение проблемы C)

**Зачем:** UI нужен булевый флаг для определения, пуста ли память. Это свойство будет использовано в CalculatorView для передачи в кнопки MC и MR через `isEnabled`.

**Где:** `CalculatorViewModel.swift`, сразу после computed property `currentDisplayValue` (после закрывающей скобки блока currentDisplayValue), перед строкой 29 (`func appendCharacter`).

**Код для вставки:**
```swift
    /// Есть ли непустое значение в памяти (используется UI для визуальной индикации)
    var hasMemory: Bool { memoryValue != 0 }
```

**Пояснение:**
- `var hasMemory: Bool` — computed property (без тела в фигурных скобках, т.к. это однострочное выражение)
- `{ memoryValue != 0 }` — возвращает true, если memoryValue не равен нулю
- `memoryValue` — существует, строка 27: `private var memoryValue: Decimal = 0`
- Оператор `!=` для Decimal — стандартная операция сравнения в Swift ✓

**Важно:** Это свойство имеет уровень доступа `var` (public по умолчанию внутри модуля), а не `private`. Оно нужно из CalculatorView, который находится в том же модуле. `CalculatorViewModel` аннотирован как `@Observable` (строка 7), поэтому все `var` свойства автоматически становятся наблюдаемыми — UI будет обновляться при изменении `memoryValue`.

### Изменение 3: Исправить `memoryAdd()`, `memorySubtract()` и `memoryRecall()`

#### 3a. Исправить `memoryAdd()` (строки 135–138)

**Текущий код:**
```swift
    func memoryAdd() {
        guard let val = resultDecimal else { return }
        memoryValue += val
    }
```

**Новый код:**
```swift
    func memoryAdd() {
        guard let val = currentDisplayValue else { return }
        memoryValue += val
    }
```

**Что изменилось:** `resultDecimal` заменён на `currentDisplayValue`. Теперь M+ работает и когда есть результат вычисления, и когда есть невычисленное выражение на дисплее.

**Верификация:** `currentDisplayValue` — только что добавленное computed property (Изменение 1). `memoryValue` — существует, строка 27. Оператор `+=` для Decimal — стандартный ✓

#### 3b. Исправить `memorySubtract()` (строки 140–143)

**Текущий код:**
```swift
    func memorySubtract() {
        guard let val = resultDecimal else { return }
        memoryValue -= val
    }
```

**Новый код:**
```swift
    func memorySubtract() {
        guard let val = currentDisplayValue else { return }
        memoryValue -= val
    }
```

**Что изменилось:** `resultDecimal` заменён на `currentDisplayValue`. Аналогично memoryAdd.

**Верификация:** `currentDisplayValue` — только что добавленное computed property. `memoryValue` — существует, строка 27. Оператор `-=` для Decimal — стандартный ✓

#### 3c. Исправить `memoryRecall()` (строки 145–149)

**Текущий код:**
```swift
    func memoryRecall() {
        expression = memoryValue.description
        result = nil
        errorMessage = nil
    }
```

**Новый код:**
```swift
    func memoryRecall() {
        expression = memoryValue.description
        result = nil
        resultDecimal = nil
        errorMessage = nil
    }
```

**Что изменилось:** Добавлена строка `resultDecimal = nil` между `result = nil` и `errorMessage = nil`.

**Почему именно такой порядок:**
1. Сначала `expression = memoryValue.description` — устанавливаем выражение значением из памяти. Это «физическое» значение, которое будет показано на дисплее
2. Затем `result = nil` — сбрасываем отображаемый результат (форматированную строку). Результат был от предыдущего вычисления, он больше не актуален
3. Затем `resultDecimal = nil` — сбрасываем сырое Decimal-значение. Это КЛЮЧЕВОЕ исправление: теперь `hasResult` станет `false`, и `appendCharacter()` будет корректно обрабатывать дальнейший ввод
4. В конце `errorMessage = nil` — сбрасываем ошибку, если она была

**Верификация:**
- `expression` — существует, строка 10: `var expression: String = ""` ✓
- `memoryValue` — существует, строка 27: `private var memoryValue: Decimal = 0` ✓
- `memoryValue.description` — `Decimal` conforms to `CustomStringConvertible`, `.description` возвращает строковое представление (например, "31" для Decimal 31) ✓
- `result` — существует, строка 11: `var result: String? = nil` ✓
- `resultDecimal` — существует, строка 12: `internal var resultDecimal: Decimal? = nil` ✓
- `errorMessage` — существует, строка 13: `var errorMessage: String? = nil` ✓

**Поведение после исправления — трассировка сценария из раздела 1.2:**

После MR (память = 31):
- `expression = "31"`
- `result = nil`
- `resultDecimal = nil` ← НОВОЕ
- `errorMessage = nil`
- `hasResult = false` (потому что resultDecimal == nil)

Пользователь нажимает `+`:
- `appendCharacter("+")` → `hasResult && isOperator("+")` → `false && true` → false → ветка не срабатывает
- `expression += "+"` → `expression = "31+"` ✓ (корректно, продолжение выражения из памяти)

Пользователь нажимает `2`:
- `appendCharacter("2")` → `hasResult && !isOperator("2")` → `false && true` → false → ветка не срабатывает
- `expression += "2"` → `expression = "312"` ✓ (продолжение ввода числа)

Пользователь нажимает `0`, `=`, `=`:
- `expression = "3120"` → вычисляется... (это уже не наш сценарий, но логика корректна)

**Трассировка: MR → оператор → число → "=":**
1. После MR: `expression = "31"`, `resultDecimal = nil`, `hasResult = false`
2. Нажатие `+`: `expression = "31+"`, `hasResult = false`
3. Нажатие `2`: `expression = "31+2"`, `tryAutoEvaluate()` не срабатывает (нет полного выражения)
4. Нажатие `0`: `expression = "31+20"`, `tryAutoEvaluate()` → вычисляет 31+20=51 → `result = "51"`, `resultDecimal = 51`
5. Нажатие `=`: `evaluate()` → вычисляет "31+20" = 51 → `result = "51"` ✓

### Изменение 4: Добавить свойство `isEnabled` в `ButtonSpec` (решение проблемы C — UI-часть)

**Зачем:** Кнопки MC и MR должны быть визуально неактивны (затемнены), когда память пуста. Для этого в `ButtonSpec` нужно добавить булево свойство, которое будет передаваться в `CalculatorButton`.

**Где:** `Sources/Views/CalculatorButton.swift`, структура `ButtonSpec` (строки 105–110).

**Текущий код:**
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
}
```

**Новый код:**
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
}
```

**Что изменилось:** Добавлена строка `var isEnabled: Bool = true` после `var isWide: Bool = false`.

**Верификация:**
- `ButtonSpec` — struct, Identifiable, строки 105–110 CalculatorButton.swift ✓
- `id: UUID()` — генерируется при создании экземпляра ✓
- `label: ButtonLabel` — enum с case .mc, .mPlus, .mMinus, .mR и др. (строки 16–101) ✓
- `type: CalcButtonType` — enum с case .digit, .operator, .function (строки 5–12) ✓
- `isWide: Bool = false` — существующее свойство с дефолтным значением ✓
- Добавление свойства с дефолтным значением `true` не ломает существующие вызовы `ButtonSpec(...)`, т.к. все существующие инициализаторы используют именованные аргументы и новое свойство имеет значение по умолчанию ✓

### Изменение 5: Обновить CalculatorView — передать `hasMemory` в кнопки MC и MR

**Зачем:** UI должен передавать состояние памяти в кнопки, чтобы те знали, активны они или нет.

**Где:** `Sources/Views/CalculatorView.swift`, строки 59–64 (строка 1 сетки кнопок — память).

**Текущий код:**
```swift
            // Строка 1: память
            buttonRow([
                ButtonSpec(label: .mc,             type: .function),
                ButtonSpec(label: .mPlus,          type: .function),
                ButtonSpec(label: .mMinus,         type: .function),
                ButtonSpec(label: .mR,             type: .function),
            ])
```

**Новый код:**
```swift
            // Строка 1: память
            buttonRow([
                ButtonSpec(label: .mc,             type: .function, isEnabled: viewModel.hasMemory),
                ButtonSpec(label: .mPlus,          type: .function),
                ButtonSpec(label: .mMinus,         type: .function),
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory),
            ])
```

**Что изменилось:**
- Строка 60: добавлен именованный аргумент `isEnabled: viewModel.hasMemory` в `ButtonSpec(label: .mc, ...)`
- Строка 63: добавлен именованный аргумент `isEnabled: viewModel.hasMemory` в `ButtonSpec(label: .mR, ...)`
- M+ (строка 61) и M− (строка 62) остаются без `isEnabled` — они используют значение по умолчанию `true`, т.к. всегда активны (даже при пустой памяти M+ может записать число с дисплея в память)

**Верификация:**
- `viewModel` — существует, CalculatorView.swift строка 7: `@Bindable var viewModel: CalculatorViewModel` ✓
- `viewModel.hasMemory` — computed property, добавляемый в Изменении 2: `var hasMemory: Bool { memoryValue != 0 }` ✓
- `@Bindable` — протокол SwiftUI, делает свойства Observable доступными для привязки в View ✓
- `ButtonSpec(label:type:isWide:isEnabled:)` — инициализатор генерируется автоматически для struct с именованными полями. Все аргументы именованные, порядок не важен ✓
- `buttonRow(_:)` — существует, строки 112–127: принимает `[ButtonSpec]`, не зависит от `isEnabled` ✓

**Обоснование, почему M+ и M− всегда активны:** Даже когда память пуста (`memoryValue == 0`), кнопка M+ полезна — она записывает текущее значение с дисплея в память. Кнопка M− аналогично. Поэтому `isEnabled` для них не нужен (используется дефолт `true`).

### Изменение 6: Обновить CalculatorButton — применить `isEnabled` (решение проблемы C — визуальная часть)

Это изменение состоит из двух частей: визуальная индикация (opacity) и блокировка нажатия (guard).

#### 6a. Добавить `.opacity` для визуальной индикации

**Где:** `Sources/Views/CalculatorButton.swift`, внутри `body` (строки 175–221), после строки 220 (`.accessibilityIdentifier(...)`), перед закрывающей скобкой `}` на строке 221.

**Текущий код (концовка body, строки 217–221):**
```swift
        .accessibilityLabel(spec.label.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(spec.label.accessibilityDescription)
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
    }
```

**Новый код (концовка body, строки 217–222):**
```swift
        .accessibilityLabel(spec.label.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(spec.label.accessibilityDescription)
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
    }
```

**Что изменилось:** Добавлена строка `.opacity(spec.isEnabled ? 1.0 : 0.4)` после `.accessibilityIdentifier(...)`.

**Пояснение:**
- `.opacity(_:)` — стандартный SwiftUI-модификатор вида, принимает `Double` от 0.0 (полностью прозрачный) до 1.0 (полностью видимый)
- `spec.isEnabled ? 1.0 : 0.4` — если кнопка активна, opacity = 1.0 (полностью видна); если неактивна, opacity = 0.4 (затемнена на 60%)
- `spec` — свойство CalculatorButton, строка 116: `let spec: ButtonSpec` ✓
- `spec.isEnabled` — свойство ButtonSpec, добавляемое в Изменении 4 ✓

#### 6b. Добавить guard для блокировки нажатия неактивных кнопок

**Где:** `Sources/Views/CalculatorButton.swift`, строки 179–181 (closure `Button { ... } label: { ... }`).

**Текущий код:**
```swift
        Button {
            onTap(spec.label)
        } label: {
```

**Новый код:**
```swift
        Button {
            guard spec.isEnabled else { return }
            onTap(spec.label)
        } label: {
```

**Что изменилось:** Добавлена строка `guard spec.isEnabled else { return }` между `{` и `onTap(spec.label)`.

**Пояснение:**
- `Button { ... } label: { ... }` — SwiftUI-конструкция, где первый closure — action (выполняется при нажатии), второй — label (внешний вид кнопки)
- `guard spec.isEnabled else { return }` — если кнопка не активна (`isEnabled == false`), closure немедленно завершается без вызова `onTap`
- `onTap(spec.label)` — замыкание, переданное в CalculatorButton при создании (см. CalculatorView.swift строки 116–125: `CalculatorButton(spec:spec, ...) { label in handleButtonPress(label) }`)
- `guard` — стандартный Swift-оператор раннего выхода. `return` внутри closure завершает его выполнение ✓

**Важно:** `.opacity(0.4)` на строке 221 и `guard` на строке 180 работают вместе:
- `.opacity(0.4)` — визуальная индикация (пользователь видит, что кнопка неактивна)
- `guard` — логическая блокировка (пользователь не может нажать неактивную кнопку)

---

## 3. Пошаговый план реализации (порядок действий)

Выполнять строго по порядку. Каждый шаг должен быть завершён и скомпилирован перед переходом к следующему.

### Шаг 1: CalculatorViewModel — добавить `currentDisplayValue` и `hasMemory`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

**Контекст:** Открыть файл. Найти строку 27:
```swift
    private var memoryValue: Decimal = 0
```

Сразу после закрывающей скобки этой строки (после `0`), перед пустой строкой 28, и перед `func appendCharacter` на строке 29 — вставить следующий блок кода:

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

    /// Есть ли непустое значение в памяти (используется UI для визуальной индикации)
    var hasMemory: Bool { memoryValue != 0 }
```

**Проверка после вставки:** В файле между строкой 27 и строкой 29 (`func appendCharacter`) должны быть новые computed properties. Файл должен компилироваться без ошибок (но пока M+/M−/MR ещё не изменены, функциональность не нова).

### Шаг 2: CalculatorViewModel — исправить `memoryAdd()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

**Контекст:** Найти строки 135–138:
```swift
    func memoryAdd() {
        guard let val = resultDecimal else { return }
        memoryValue += val
    }
```

**Заменить** эти три строки (136–137) на:
```swift
    func memoryAdd() {
        guard let val = currentDisplayValue else { return }
        memoryValue += val
    }
```

**Что именно меняется:** В строке 136 `resultDecimal` заменяется на `currentDisplayValue`. Остальные строки (135, 138) остаются без изменений.

**Проверка:** `currentDisplayValue` определён в Шаге 1. `memoryValue += val` — оператор `+=` для Decimal корректен ✓

### Шаг 3: CalculatorViewModel — исправить `memorySubtract()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

**Контекст:** Найти строки 140–143:
```swift
    func memorySubtract() {
        guard let val = resultDecimal else { return }
        memoryValue -= val
    }
```

**Заменить** эти три строки (141–142) на:
```swift
    func memorySubtract() {
        guard let val = currentDisplayValue else { return }
        memoryValue -= val
    }
```

**Что именно меняется:** В строке 141 `resultDecimal` заменяется на `currentDisplayValue`. Остальные строки (140, 143) остаются без изменений.

**Проверка:** `currentDisplayValue` определён в Шаге 1. `memoryValue -= val` — оператор `-=` для Decimal корректен ✓

### Шаг 4: CalculatorViewModel — исправить `memoryRecall()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

**Контекст:** Найти строки 145–149:
```swift
    func memoryRecall() {
        expression = memoryValue.description
        result = nil
        errorMessage = nil
    }
```

**Заменить** эти четыре строки (146–148) на:
```swift
    func memoryRecall() {
        expression = memoryValue.description
        result = nil
        resultDecimal = nil
        errorMessage = nil
    }
```

**Что именно меняется:** Добавлена строка `resultDecimal = nil` между `result = nil` (старая строка 147) и `errorMessage = nil` (старая строка 148). Строки 145 и 149 (func signature и закрывающая скобка) остаются без изменений.

**Проверка:** `resultDecimal` — свойство строки 12, тип `Decimal?`, допустимо присвоение `nil` ✓

### Шаг 5: CalculatorButton — добавить `isEnabled` в ButtonSpec

**Файл:** `Sources/Views/CalculatorButton.swift`

**Контекст:** Найти строки 105–110:
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
}
```

**Заменить** эти строки (108–110) на:
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
}
```

**Что именно меняется:** Добавлена строка `var isEnabled: Bool = true` после строки 109 (`var isWide: Bool = false`).

**Проверка:** `ButtonSpec` — struct, все свойства имеют значения по умолчанию или генерируются автоматически ✓

### Шаг 6: CalculatorView — передать `hasMemory` в кнопки MC и MR

**Файл:** `Sources/Views/CalculatorView.swift`

**Контекст:** Найти строки 59–64:
```swift
            // Строка 1: память
            buttonRow([
                ButtonSpec(label: .mc,             type: .function),
                ButtonSpec(label: .mPlus,          type: .function),
                ButtonSpec(label: .mMinus,         type: .function),
                ButtonSpec(label: .mR,             type: .function),
            ])
```

**Заменить** эти строки (60–63) на:
```swift
            // Строка 1: память
            buttonRow([
                ButtonSpec(label: .mc,             type: .function, isEnabled: viewModel.hasMemory),
                ButtonSpec(label: .mPlus,          type: .function),
                ButtonSpec(label: .mMinus,         type: .function),
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory),
            ])
```

**Что именно меняется:**
- Строка 60: после `type: .function)` добавлено `, isEnabled: viewModel.hasMemory`
- Строка 63: после `type: .function)` добавлено `, isEnabled: viewModel.hasMemory`
- Строки 61 и 62 (mPlus, mMinus) остаются без изменений

**Проверка:** `viewModel.hasMemory` — computed property из Шага 1. `isEnabled:` — именованный аргумент, соответствующий свойству `var isEnabled: Bool = true` в ButtonSpec (Шаг 5) ✓

### Шаг 7: CalculatorButton — добавить `.opacity` для визуальной индикации

**Файл:** `Sources/Views/CalculatorButton.swift`

**Контекст:** Найти строки 217–221 (концовка body):
```swift
        .accessibilityLabel(spec.label.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(spec.label.accessibilityDescription)
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
    }
```

**Заменить** эти строки (220–221) на:
```swift
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
    }
```

**Что именно меняется:** После строки 220 (`accessibilityIdentifier(...)`) добавлена строка `.opacity(spec.isEnabled ? 1.0 : 0.4)`. Закрывающая скобка `}` на строке 221 остаётся на месте.

**Проверка:** `.opacity(_:)` — стандартный SwiftUI-модификатор. `spec.isEnabled` — свойство ButtonSpec из Шага 5 ✓

### Шаг 8: CalculatorButton — добавить guard для блокировки нажатия

**Файл:** `Sources/Views/CalculatorButton.swift`

**Контекст:** Найти строки 179–181:
```swift
        Button {
            onTap(spec.label)
        } label: {
```

**Заменить** эти строки (179–180) на:
```swift
        Button {
            guard spec.isEnabled else { return }
            onTap(spec.label)
        } label: {
```

**Что именно меняется:** Между `{` (строка 179) и `onTap(spec.label)` (старая строка 180) вставлена новая строка `guard spec.isEnabled else { return }`.

**Проверка:** `spec` — свойство CalculatorButton, строка 116. `spec.isEnabled` — свойство ButtonSpec из Шага 5 ✓

---

## 4. Итоговая таблица изменений по файлам

### Файл: `Sources/ViewModels/CalculatorViewModel.swift`

| Строка(и) | Тип изменения | Описание |
|---|---|---|
| После 27, перед 29 | Вставка (Шаг 1) | Добавлены `currentDisplayValue` и `hasMemory` |
| 136 | Замена (Шаг 2) | `resultDecimal` → `currentDisplayValue` в `memoryAdd()` |
| 141 | Замена (Шаг 3) | `resultDecimal` → `currentDisplayValue` в `memorySubtract()` |
| 147 (между) | Вставка (Шаг 4) | Добавлена строка `resultDecimal = nil` в `memoryRecall()` |

### Файл: `Sources/Views/CalculatorButton.swift`

| Строка(и) | Тип изменения | Описание |
|---|---|---|
| 109 (после) | Вставка (Шаг 5) | Добавлено `var isEnabled: Bool = true` в ButtonSpec |
| 220 (после) | Вставка (Шаг 7) | Добавлен `.opacity(spec.isEnabled ? 1.0 : 0.4)` в body |
| 179 (между) | Вставка (Шаг 8) | Добавлен `guard spec.isEnabled else { return }` в Button action |

### Файл: `Sources/Views/CalculatorView.swift`

| Строка(и) | Тип изменения | Описание |
|---|---|---|
| 60 | Замена (Шаг 6) | Добавлен `isEnabled: viewModel.hasMemory` в ButtonSpec для .mc |
| 63 | Замена (Шаг 6) | Добавлен `isEnabled: viewModel.hasMemory` в ButtonSpec для .mR |

---

## 5. Полный реестр верифицированных элементов

Все элементы, используемые в плане. Каждый подтверждён чтением исходного файла.

| Элемент | Файл | Строка | Подтверждено |
|---|---|---|---|
| `@MainActor` | CalculatorViewModel.swift | 6 | Да |
| `@Observable` | CalculatorViewModel.swift | 7 | Да |
| `final class CalculatorViewModel` | CalculatorViewModel.swift | 8 | Да |
| `var expression: String = ""` | CalculatorViewModel.swift | 10 | Да |
| `var result: String? = nil` | CalculatorViewModel.swift | 11 | Да |
| `internal var resultDecimal: Decimal? = nil` | CalculatorViewModel.swift | 12 | Да |
| `var errorMessage: String? = nil` | CalculatorViewModel.swift | 13 | Да |
| `private let engine = CalculatorEngine()` | CalculatorViewModel.swift | 15 | Да |
| `private let historyService = HistoryService.shared` | CalculatorViewModel.swift | 16 | Да |
| `private let formatter = NumberFormatterService.shared` | CalculatorViewModel.swift | 17 | Да |
| `var hasResult: Bool { resultDecimal != nil }` | CalculatorViewModel.swift | 19 | Да |
| `private var memoryValue: Decimal = 0` | CalculatorViewModel.swift | 27 | Да |
| `func appendCharacter(_ char: String)` | CalculatorViewModel.swift | 29 | Да |
| `func evaluate()` | CalculatorViewModel.swift | 66 | Да |
| `func clear()` | CalculatorViewModel.swift | 87 | Да |
| `func backspace()` | CalculatorViewModel.swift | 94 | Да |
| `func toggleSign()` | CalculatorViewModel.swift | 111 | Да |
| `func memoryClear()` | CalculatorViewModel.swift | 131 | Да |
| `func memoryAdd()` | CalculatorViewModel.swift | 135 | Да |
| `func memorySubtract()` | CalculatorViewModel.swift | 140 | Да |
| `func memoryRecall()` | CalculatorViewModel.swift | 145 | Да |
| `private func tryAutoEvaluate()` | CalculatorViewModel.swift | 207 | Да |
| `private func isOperator(_ char: String) -> Bool` | CalculatorViewModel.swift | 225 | Да |
| `private func isDigitOrDecimal(_ char: String) -> Bool` | CalculatorViewModel.swift | 233 | Да |
| `public func evaluate(_ expression: String) throws -> Decimal` | CalculatorEngine.swift | 23 | Да |
| `public struct CalculatorEngine: Sendable` | CalculatorEngine.swift | 10 | Да |
| `public static let shared = NumberFormatterService()` | NumberFormatterService.swift | 5 | Да |
| `public func format(_ value: Decimal) -> String` | NumberFormatterService.swift | 29 | Да |
| `enum CalcButtonType` | CalculatorButton.swift | 5 | Да |
| `enum ButtonLabel` | CalculatorButton.swift | 16 | Да |
| `case mc`, `.mPlus`, `.mMinus`, `.mR` | CalculatorButton.swift | 32–35 | Да |
| `var displayTitle: String` (computed) | CalculatorButton.swift | 39 | Да |
| `var inputValue: String` (computed) | CalculatorButton.swift | 64 | Да |
| `var accessibilityDescription: String` (computed) | CalculatorButton.swift | 80 | Да |
| `struct ButtonSpec: Identifiable` | CalculatorButton.swift | 105 | Да (будет расширена) |
| `struct CalculatorButton: View` | CalculatorButton.swift | 114 | Да |
| `let spec: ButtonSpec` | CalculatorButton.swift | 116 | Да |
| `var body: some View` | CalculatorButton.swift | 175 | Да |
| `Button { onTap(spec.label) } label: {` | CalculatorButton.swift | 179–181 | Да (будет изменено) |
| `.accessibilityIdentifier(...)` | CalculatorButton.swift | 220 | Да (будет добавлен opacity после) |
| `@Bindable var viewModel: CalculatorViewModel` | CalculatorView.swift | 7 | Да |
| `private var isAC: Bool` | CalculatorView.swift | 16 | Да |
| `var body: some View` | CalculatorView.swift | 20 | Да |
| `private var standardButtonGrid: some View` | CalculatorView.swift | 56 | Да |
| `buttonRow(...)` с кнопками памяти | CalculatorView.swift | 59–64 | Да (будет изменено) |
| `private func buttonRow(_ specs: [ButtonSpec]) -> some View` | CalculatorView.swift | 113 | Да |
| `private func handleButtonPress(_ label: ButtonLabel)` | CalculatorView.swift | 131 | Да |
| `case .mc: viewModel.memoryClear()` | CalculatorView.swift | 154–155 | Да |
| `case .mPlus: viewModel.memoryAdd()` | CalculatorView.swift | 156–157 | Да |
| `case .mMinus: viewModel.memorySubtract()` | CalculatorView.swift | 158–159 | Да |
| `case .mR: viewModel.memoryRecall()` | CalculatorView.swift | 160–161 | Да |
| `let mainText = result ?? (expression.isEmpty ? "0" : expression)` | DisplayView.swift | 58 | Да |
| `public final class ClipboardManager: @unchecked Sendable` | ClipboardManager.swift | 8 | Да (не изменяется, но существует) |
| `public final class HistoryService: @unchecked Sendable` | HistoryService.swift | 3 | Да (не изменяется, но существует) |
| `Decimal.description` (CustomStringConvertible) | Foundation.framework | — | Да: Decimal conforms to CustomStringConvertible, .description возвращает строку |
| `try?` (Swift operator) | Swift standard library | — | Да: преобразует throws в nil |
| `.opacity(_:)` (SwiftUI modifier) | SwiftUI framework | — | Да: принимает Double, применяет прозрачность |
| `guard ... else { return }` (Swift statement) | Swift language | — | Да: ранний выход из scope |
| `String.trimmingCharacters(in:)` (Foundation) | Foundation.framework | — | Да: стандартный метод String |
| `\.whitespaces` (CharacterSet) | Foundation.framework | — | Да: стандартная константаCharacterSet |

---

## 6. Что НЕ изменяется (и почему)

| Элемент | Файл | Причина отсутствия изменений |
|---|---|---|
| `memoryClear()` | CalculatorViewModel.swift, 131–133 | Корректно сбрасывает только `memoryValue = 0`, не влияя на вычисления |
| `appendCharacter(_:)` | CalculatorViewModel.swift, 29–48 | Логика корректна — она зависит от `hasResult`, который после исправления MR будет `false` |
| `appendOperator(_:)` | CalculatorViewModel.swift, 51–64 | Не вызывается из UI (комментарий строка 50), оставлен для совместимости |
| `evaluate()` | CalculatorViewModel.swift, 66–85 | Корректно вычисляет expression и устанавливает result/resultDecimal |
| `clear()` | CalculatorViewModel.swift, 87–92 | Корректно сбрасывает всё |
| `backspace()` | CalculatorViewModel.swift, 94–108 | Корректно обрабатывает удаление символов |
| `toggleSign()` | CalculatorViewModel.swift, 111–127 | Корректно инвертирует знак |
| `tryAutoEvaluate()` | CalculatorViewModel.swift, 207–218 | Корректно выполняет автовычисление |
| `handleKeyCommand(_:)` | CalculatorViewModel.swift, 151–164 | Не затрагивается изменениями памяти |
| `insertFromClipboard(_:)` | CalculatorViewModel.swift, 168–183 | Не затрагивается изменениями памяти |
| `copyResult()` | CalculatorViewModel.swift, 185–189 | Не затрагивается изменениями памяти |
| `useHistoryEntry(_:)` | CalculatorViewModel.swift, 193–198 | Не затрагивается изменениями памяти |
| `CalculatorColors` | — | Не изменяется, используется для фонов/текста кнопок |
| `AnyShape` | CalculatorButton.swift, 226–232 | Не изменяется |
| `DisplayView` | DisplayView.swift | Не изменяется — корректно отображает expression и result |
| `CalcButtonType` | CalculatorButton.swift, 5–12 | Не изменяется |
| `ButtonLabel` | CalculatorButton.swift, 16–101 | Не изменяется |

---

## 7. Проверка после реализации: трассировка всех сценариев

### Сценарий 1: M+ работает после ввода числа (без "=")

**Действия:**
1. Ввести `42` → `expression = "42"`, `resultDecimal = nil`, `hasResult = false`
2. Нажать M+ → вызывается `memoryAdd()`

**Выполнение memoryAdd():**
- `guard let val = currentDisplayValue else { return }`
- `currentDisplayValue`: `resultDecimal == nil` → переходим к выражению
- `trimmed = "42"`, не пустое
- `try? engine.evaluate("42")` → возвращает `Decimal(42)`
- `val = 42`, guard проходит
- `memoryValue += 42` → `memoryValue = 42`

**Результат:** Память = 42. ✓

### Сценарий 2: M+ работает после ввода выражения (без "=")

**Действия:**
1. Ввести `15+16` → `tryAutoEvaluate()` вычисляет 31 → `resultDecimal = 31`, `expression = "15+16"`
2. Нажать M+ → вызывается `memoryAdd()`

**Выполнение memoryAdd():**
- `guard let val = currentDisplayValue else { return }`
- `currentDisplayValue`: `resultDecimal == 31` (не nil) → возвращает 31
- `val = 31`, guard проходит
- `memoryValue += 31` → `memoryValue = 31`

**Результат:** Память = 31. ✓

### Сценарий 3: M− работает после ввода числа (без "=")

**Действия:**
1. Ввести `30` → `expression = "30"`, `resultDecimal = nil`
2. Нажать M− → вызывается `memorySubtract()`

**Выполнение memorySubtract():**
- `guard let val = currentDisplayValue else { return }`
- `currentDisplayValue`: `resultDecimal == nil` → `engine.evaluate("30")` → 30
- `val = 30`, guard проходит
- `memoryValue -= 30`

**Результат:** Из памяти вычтено 30. ✓

### Сценарий 4: M+ при пустом дисплее (ничего не происходит)

**Действия:**
1. Очистить калькулятор (expression = "", resultDecimal = nil)
2. Нажать M+ → вызывается `memoryAdd()`

**Выполнение memoryAdd():**
- `guard let val = currentDisplayValue else { return }`
- `currentDisplayValue`: `resultDecimal == nil` → `trimmed = ""` (пустое) → `return nil`
- `val` — nil, guard не проходит → `return`

**Результат:** Ничего не происходит. Память не изменяется. ✓

### Сценарий 5: MR → продолжение вычислений (исправлена проблема B)

**Действия:**
1. Вычислить `15 + 16 =` → результат 31, `resultDecimal = 31`, `expression = ""`
2. Нажать M+ → `memoryValue = 31`
3. Вычислить `10 + 5 =` → результат 15, `resultDecimal = 15`, `expression = ""`
4. Нажать MR → вызывается `memoryRecall()`

**Выполнение memoryRecall():**
- `expression = "31"` (memoryValue.description)
- `result = nil`
- `resultDecimal = nil` ← ИСПРАВЛЕНИЕ
- `errorMessage = nil`
- Состояние: `expression = "31"`, `resultDecimal = nil`, `hasResult = false`

5. Нажать `+` → вызывается `appendCharacter("+")`
- `hasResult && isOperator("+")` → `false && true` → false → ветка не срабатывает
- `expression += "+"` → `expression = "31+"` ✓

6. Ввести `20` → `expression = "31+20"`
- `tryAutoEvaluate()` → вычисляет 51 → `result = "51"`, `resultDecimal = 51`

7. Нажать `=` → `evaluate()` → вычисляет "31+20" = 51

**Результат:** `31 + 20 = 51`. ✓ (ранее было 35 из-за устаревшего resultDecimal)

### Сценарий 6: MR → нажатие цифры (исправлена проблема B, вариант с цифрой)

**Действия:**
1. Вычислить `10 + 5 =` → результат 15, `resultDecimal = 15`
2. Нажать M+ → `memoryValue = 15`
3. Вычислить `20 + 10 =` → результат 30, `resultDecimal = 30`
4. Нажать MR → `memoryRecall()`:
   - `expression = "15"`, `resultDecimal = nil`, `hasResult = false`
5. Нажать `2` → `appendCharacter("2")`
   - `hasResult && !isOperator("2")` → `false` → ветка не срабатывает
   - `expression += "2"` → `expression = "152"` ✓

**Результат:** `expression = "152"` (продолжение числа из памяти). ✓ (ранее было "2" — выражение терялось)

### Сценарий 7: MC затемнён при пустой памяти (визуальная индикация)

**Действия:**
1. Калькулятор только что запущен, `memoryValue = 0`
2. `hasMemory = false` (0 != 0 → false)
3. Кнопка MC: `ButtonSpec(..., isEnabled: false)`
4. CalculatorButton: `.opacity(0.4)` — затемнена
5. Нажатие MC: `guard spec.isEnabled else { return }` → блокируется

**Результат:** MC затемнён и не нажимается. ✓

### Сценарий 8: MR затемнён при пустой памяти (визуальная индикация)

**Действия:**
1. `memoryValue = 0`, `hasMemory = false`
2. Кнопка MR: `ButtonSpec(..., isEnabled: false)`
3. CalculatorButton: `.opacity(0.4)` — затемнена
4. Нажатие MR блокируется guard'ом

**Результат:** MR затемнён и не нажимается. ✓

### Сценарий 9: M+ и M− остаются активными при пустой памяти

**Действия:**
1. `memoryValue = 0`, `hasMemory = false`
2. Кнопка M+: `ButtonSpec(label: .mPlus, type: .function)` — без `isEnabled`, используется дефолт `true`
3. CalculatorButton: `.opacity(1.0)` — полностью видна
4. Нажатие M+ при введённом числе `42`: работает (см. Сценарий 1)

**Результат:** M+ и M− всегда активны. ✓

### Сценарий 10: MC → MR после заполнения памяти

**Действия:**
1. Ввести `42`, нажать M+ → `memoryValue = 42`
2. Нажать MC → `memoryClear()` → `memoryValue = 0`
3. Нажать MR → вызывается `memoryRecall()`:
   - `expression = "0"` (memoryValue.description, memoryValue = 0)
   - `result = nil`, `resultDecimal = nil`, `errorMessage = nil`

**Результат:** На дисплее "0". Память пуста. MC и MR затемнены. ✓

### Сценарий 11: Многократное M+ на одном числе

**Действия:**
1. Ввести `10`, нажать M+ → `memoryValue = 10`
2. Ввести `20`, нажать M+ → `memoryValue = 30`
3. Ввести `5`, нажать M+ → `memoryValue = 35`
4. Нажать MR → `expression = "35"`

**Результат:** Память суммируется корректно. ✓

### Сценарий 12: M+ → MR → "+" → число → "=" (полный рабочий сценарий)

**Действия:**
1. Ввести `100`, нажать M+ → `memoryValue = 100`
2. Ввести `30`, нажать M− → `memoryValue = 70`
3. Нажать MR → `expression = "70"`, `resultDecimal = nil`, `hasResult = false`
4. Нажать `+` → `expression = "70+"`
5. Ввести `25` → `tryAutoEvaluate()` вычисляет 70+25=95 → `result = "95"`, `resultDecimal = 95`
6. Нажать `=` → `evaluate()` → вычисляет "70+25" = 95

**Результат:** `70 + 25 = 95`. ✓

---

## 8. Проверка отсутствия неверифицированных элементов

Ниже таблица всех элементов, которые используются в коде плана. Каждый элемент либо существует в кодовой базе (подтверждено чтением файла), либо создаётся данным планом.

| Элемент | Происхождение | Подтверждено |
|---|---|---|
| `currentDisplayValue` (computed property) | Создаётся планом (Шаг 1) | Н/Д — новый элемент |
| `hasMemory` (computed property) | Создаётся планом (Шаг 1) | Н/Д — новый элемент |
| `isEnabled` (свойство ButtonSpec) | Создаётся планом (Шаг 5) | Н/Д — новый элемент |
| `resultDecimal` | Существующее, строка 12 CalculatorViewModel.swift | Да ✓ |
| `expression` | Существующее, строка 10 CalculatorViewModel.swift | Да ✓ |
| `result` | Существующее, строка 11 CalculatorViewModel.swift | Да ✓ |
| `errorMessage` | Существующее, строка 13 CalculatorViewModel.swift | Да ✓ |
| `memoryValue` | Существующее, строка 27 CalculatorViewModel.swift | Да ✓ |
| `hasResult` | Существующее, строка 19 CalculatorViewModel.swift | Да ✓ |
| `engine` | Существующее, строка 15 CalculatorViewModel.swift | Да ✓ |
| `engine.evaluate(_:)` | Существующее, CalculatorEngine.swift строка 23 | Да ✓ |
| `formatter` | Существующее, строка 17 CalculatorViewModel.swift | Да ✓ |
| `NumberFormatterService.shared` | Существующее, NumberFormatterService.swift строка 5 | Да ✓ |
| `NumberFormatterService.format(_:)` | Существующее, NumberFormatterService.swift строка 29 | Да ✓ |
| `ButtonSpec` | Существующий, CalculatorButton.swift строка 105 | Да ✓ |
| `CalculatorButton.spec` | Существующий, CalculatorButton.swift строка 116 | Да ✓ |
| `CalculatorButton.body` | Существующий, CalculatorButton.swift строка 175 | Да ✓ |
| `CalculatorView.viewModel` | Существующий, CalculatorView.swift строка 7 | Да ✓ |
| `viewModel.hasMemory` | Создаётся планом (свойство CalculatorViewModel) → используется в CalculatorView | Н/Д — новое, но корректное |
| `.opacity(_:)` | Стандартный SwiftUI-модификатор | Да ✓ |
| `guard ... else { return }` | Стандартный Swift-оператор | Да ✓ |
| `Decimal.description` | Standard library (CustomStringConvertible) | Да ✓ |
| `try?` | Стандартный Swift-оператор | Да ✓ |
| `String.trimmingCharacters(in:)` | Foundation (стандартный метод String) | Да ✓ |
| `.whitespaces` | Foundation (CharacterSet.whitespaces) | Да ✓ |

**Ни одного неверифицированного элемента.** Все существующие элементы подтверждены чтением файлов. Все новые элементы создаются данным планом и не зависят от несуществующих методов или переменных.

---

## 9. Возможные вопросы и ответы

**Вопрос:** Что если `engine.evaluate(trimmed)` в `currentDisplayValue` бросит ошибку?  
**Ответ:** Оператор `try?` преобразует любое thrown error в `nil`. Метод вернёт `nil`, и `guard let val = currentDisplayValue` в memoryAdd/memorySubtract не пройдёт — метод молча вернётся. Это корректное поведение: если выражение нельзя вычислить (например, "("), нет смысла добавлять его в память.

**Вопрос:** Что если `memoryValue` отрицательный?  
**Ответ:** `memoryValue.description` вернёт строку вида "-15". `hasMemory` вернёт `true` (−15 != 0). MR покажет "-15" на дисплее. MC и MR будут активны. Всё корректно.

**Вопрос:** Что если `memoryValue == 0`?  
**Ответ:** `hasMemory = false`, MC и MR затемнены. `memoryValue.description` вернёт "0". Если пользователь somehow вызовет MR (через клавиатуру или programmatic call), expression = "0", resultDecimal = nil. Корректно.

**Вопрос:** Не сломает ли добавление `isEnabled` в ButtonSpec существующие вызовы?  
**Ответ:** Нет. Все вызовы `ButtonSpec(...)` в CalculatorView.swift используют именованные аргументы. Добавление свойства с дефолтным значением `true` не требует изменений в существующих вызовах.

**Вопрос:** Почему `hasMemory` имеет уровень доступа `var` (public), а не `private`?  
**Ответ:** Потому что он используется в CalculatorView.swift, который находится в том же модуле. `var` без модификатора доступа — internal по умолчанию, что достаточно для доступа из того же модуля. `@Observable` работает с internal свойствами.

**Вопрос:** Почему в memoryRecall() `resultDecimal = nil` ставится ПОСЛЕ `result = nil`, а не ДО?  
**Ответ:** Порядок не имеет значения для корректности — все четыре присвоения независимы друг от друга. Но логически удобно сначала установить новые значения (expression), затем сбросить визуальное представление (result), затем внутреннее состояние (resultDecimal), и в конце ошибки (errorMessage).

**Вопрос:** Что будет, если пользователь нажмёт MR при `memoryValue = 0`?  
**Ответ:** `expression = "0"`, `resultDecimal = nil`, `hasResult = false`. На дисплее отобразится "0" (DisplayView.swift строка 58: `result ?? (expression.isEmpty ? "0" : expression)` — result nil, expression = "0", значит mainText = "0"). Кнопка MR затемнена (hasMemory = false), но если бы вызов произошёл — поведение корректно.

---

## 10. Порядок сборки и проверки

1. Выполнить Шаги 1–4 (изменения в CalculatorViewModel.swift)
2. Скомпилировать проект — убедиться, что нет ошибок компиляции
3. Выполнить Шаги 5–8 (изменения в CalculatorButton.swift и CalculatorView.swift)
4. Скомпилировать проект — убедиться, что нет ошибок компиляции
5. Запустить приложение
6. Провести ручное тестирование по чеклисту из раздела 7 (все 12 сценариев)

---

*План подготовлен агентом OrnithQ8, 6 июля 2026. Все утверждения верифицированы путём чтения исходных файлов.*
