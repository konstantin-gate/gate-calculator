# План реализации: Исправление бага memoryRecall

**Дата:** 2026-07-06  
**Автор:** MiMoCode  
**Проблема:** Кнопка MR затирает текущее выражение вместо дописывания значения из памяти

---

## Часть 1: Тезисный план (без примеров кода)

| # | Действие | Файл |
|---|---|---|
| 1 | Модифицировать метод `memoryRecall()` — добавить проверку: если `expression` непуст и заканчивается оператором (`+`, `-`, `*`, `/`) — **дописать** `memoryValue.description` к `expression`; иначе — **заменить** `expression` как раньше | `Sources/ViewModels/CalculatorViewModel.swift` |
| 2 | Добавить вспомогательный приватный метод `isTrailingOperator(_:)` уже существует (`:250`), убедиться что он покрывает все операторы | `Sources/ViewModels/CalculatorViewModel.swift` |
| 3 | Верифицировать, что MR-кнопка корректно отключена при пустой памяти (Enabled = `viewModel.hasMemory`) | `Sources/Views/CalculatorView.swift:63` |
| 4 | Проверить, что изменения не затрагивают `memoryClear()`, `memoryAdd()`, `memorySubtract()` — они остаются без изменений | `Sources/ViewModels/CalculatorViewModel.swift:162-174` |
| 5 | Проверить, что изменения не ломают сценарии: MR на пустом дисплее, MR после числа (без оператора), MR после "=", MR дважды подряд | Ручная верификация |

---

## Часть 2: Детализированный план

### Шаг 1. Проблема — что происходит и почему

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:176-181`

Текущая реализация `memoryRecall()`:
```swift
func memoryRecall() {
    expression = memoryValue.description
    result = nil
    resultDecimal = nil
    errorMessage = nil
}
```

**Верификация (метод read):** Метод расположен в `Sources/ViewModels/CalculatorViewModel.swift:176`. Сигнатура: `func memoryRecall()` — без параметров, без возвращаемого значения, видимость `internal`.

**Поведение:** Метод **всегда** выполняет `expression = memoryValue.description`, полностью заменяя текущее выражение. Это некорректно, когда пользователь уже начал вводить выражение (например, набрал "10+" и нажал MR).

**Ожидаемое поведение (по аналогии с Calculator.app macOS):**
- Если expression пуст — записать значение из памяти (текущее поведение)
- Если expression заканчивается оператором — **дописать** значение из памяти (правое слагаемое)
- Если expression — число без оператора — заменить его (текущее поведение)

### Шаг 2. Модификация метода `memoryRecall()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:176-181`

**Изменяемый код (строки 176-181):**

Старая версия:
```swift
func memoryRecall() {
    expression = memoryValue.description
    result = nil
    resultDecimal = nil
    errorMessage = nil
}
```

Новая версия:
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

**Верификация вызываемых методов и свойств:**

| Элемент | Существует | Сигнатура | Файл:строка |
|---|---|---|---|
| `clearError()` | Да | `private func clearError()` | `:259-261` |
| `expression` | Да | `var expression: String` | `:10` |
| `isTrailingOperator(_:)` | Да | `private func isTrailingOperator(_ expr: String) -> Bool` | `:250-253` |
| `result` | Да | `var result: String?` | `:11` |
| `resultDecimal` | Да | `internal var resultDecimal: Decimal?` | `:12` |
| `memoryValue` | Да | `private var memoryValue: Decimal` | `:37` |

**Верификация `isTrailingOperator` (строки 250-253):**
```swift
private func isTrailingOperator(_ expr: String) -> Bool {
    guard let last = expr.last else { return false }
    return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
}
```

Метод проверяет последний символ expression на соответствие одному из операторов. Покрывает все бинарные операторы (`+`, `-`, `*`, `/`) и `%`. Это корректно — при вводе оператора через `appendCharacter()` он добавляется как последний символ в expression (например, `"10+"`).

**Верификация:** Метод `isTrailingOperator` определён в `Sources/ViewModels/CalculatorViewModel.swift:250` и используется также в `tryAutoEvaluate()` (`:239`). Он **не** является новым — уже существует и протестирован.

### Шаг 3. Верификация — MR-кнопка отключена при пустой памяти

**Файл:** `Sources/Views/CalculatorView.swift:63`

```swift
ButtonSpec(label: .mR, type: .function, isEnabled: viewModel.hasMemory, ...)
```

**Верификация `hasMemory` (строка 52):**
```swift
var hasMemory: Bool { memoryValue != 0 }
```

Кнопка MR имеет `isEnabled: viewModel.hasMemory`. При `memoryValue == 0` кнопка отключена, `memoryRecall()` не вызывается. Это означает, что внутри `memoryRecall()` нам **не** нужно проверять `memoryValue != 0` — вызов гарантированно происходит только при ненулевой памяти.

### Шаг 4. Верификация — другие методы памяти не затронуты

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:162-174`

| Метод | Строки | Изменяется? |
|---|---|---|
| `memoryClear()` | 162-164 | Нет |
| `memoryAdd()` | 166-169 | Нет |
| `memorySubtract()` | 171-174 | Нет |

Все три метода остаются без изменений. Они не зависят от `memoryRecall()` и не используют `isTrailingOperator`.

### Шаг 5. Анализ сценариев после исправления

| Сценарий | Ввод | expression до MR | expression после MR | Результат |
|---|---|---|---|---|
| MR на пустом дисплее | MR | `""` | `"10"` | Запись числа из памяти |
| MR после оператора | 10, M+, +, MR | `"10+"` | `"10+10"` | Дописывание правого операнда |
| MR после числа (без оператора) | 10, M+, 5, MR | `"5"` | `"10"` | Замена числа |
| MR после = (resultDecimal) | 10, M+, +, 5, =, MR | `""` (resultDecimal=15) | `"10"` | Замена (expression пуст) |
| MR дважды подряд | 10, M+, +, MR, MR | `"10+10"` | `"10+10"` | Второй MR: expression не пуст, `isTrailingOperator("10+10")` → `false` (последний символ "0") → замена на "10" |
| MR после оператора, затем оператор | 10, M+, +, MR, * | `"10+10"` | `"10+10*"` | Корректно: дописали 10, потом добавили оператор |
| Память = 0 | MR | — | — | Кнопка отключена (`hasMemory == false`), метод не вызывается |

**Сценарий "MR дважды подряд":** При втором вызове `memoryRecall()` expression = `"10+10"`, `isTrailingOperator("10+10")` проверяет последний символ `"0"` → `false`. Выполняется замена `expression = "10"`. Это **корректное** поведение — повторный MR без ввода оператора заменяет выражение значением из памяти.

### Шаг 6. Анализ влияния на другие компоненты

| Компонент | Затронут? | Причина |
|---|---|---|
| `CalculatorView` | Нет | Вызывает `viewModel.memoryRecall()` без изменений |
| `KeyHandlerNSView` | Нет | Не вызывает `memoryRecall()` |
| `DisplayView` | Нет | Только отображает `expression`, `result`, `errorMessage` |
| `CalculatorEngine` | Нет | Не используется в `memoryRecall()` |
| `HistoryService` | Нет | Не вызывается в `memoryRecall()` |
| `ClipboardManager` | Нет | Не вызывается в `memoryRecall()` |
| `NumberFormatterService` | Нет | Не вызывается в `memoryRecall()` |

### Шаг 7. Чеклист соответствия правилам AGENTS.md

- [x] Нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()`
- [x] Нет force unwrap (`!`) — используется `guard let last` в `isTrailingOperator`
- [x] Все методы имеют объявленные типы параметров и возвращаемых значений
- [x] MARK-комментарий на русском языке (существующий `:160` — "Memory operations")
- [x] Идентификаторы на английском языке
- [x] Нет импортов SwiftUI в вычислительном движке (изменения в ViewModel, не в Engine)
- [x] Все исключения обрабатываются (нет новых throwing-вызовов)
- [x] Нет изменяющих Git-команд
- [x] Все утверждения о коде подтверждены ссылками на файл и строку

### Шаг 8. Чеклист самопроверки

- [x] Метод `isTrailingOperator` уже существует — не создаётся новый метод
- [x] Изменяется **один** метод в **одном** файле: `memoryRecall()` в `CalculatorViewModel.swift`
- [x] Не добавляются новые зависимости, не изменяется архитектура
- [x] Все вызываемые элементы верифицированы через `read`

---

## Итого

**Объём изменений:** 1 метод (`memoryRecall()`) в 1 файле (`CalculatorViewModel.swift`).  
**Риск регрессий:** Минимальный — метод memoryRecall() не вызывается из других компонентов, изменяется только логика добавления к expression.  
**Архитектурное соответствие:** Полное — изменение в ViewModel слое, не затрагивает Engine, Services, Views.
