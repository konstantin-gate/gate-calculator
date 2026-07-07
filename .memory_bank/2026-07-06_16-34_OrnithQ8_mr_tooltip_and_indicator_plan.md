# План добавления визуальной индикации и tooltip для кнопки MR

**Дата:** 2026-07-06  
**Агент:** OrnithQ8  
**Статус:** Готов к реализации младшим разработчиком  
**Задача:** Добавить зелёный индикатор и всплывающую подсказку со значением памяти на кнопку MR

---

## 0. Справочная информация: верифицированные элементы кода

Перед началом работы необходимо убедиться, что все ссылки на код соответствуют фактическим файлам. Ниже приведена таблица всех элементов, которые будут использоваться или изменяться в этом плане. Каждый элемент верифицирован путём чтения исходного файла.

| Элемент | Файл | Строка(и) | Статус верификации |
|---|---|---|---|
| `CalculatorViewModel` — класс с `@MainActor @Observable` | `Sources/ViewModels/CalculatorViewModel.swift` | 6–8 | Подтверждено: строки 6-8 содержат `@MainActor`, `@Observable`, `final class CalculatorViewModel` |
| `memoryValue: Decimal = 0` (private var) | Там же | 27 | Подтверждено: `private var memoryValue: Decimal = 0` |
| `hasMemory: Bool { memoryValue != 0 }` (computed) | Там же | 42 | Подтверждено: `var hasMemory: Bool { memoryValue != 0 }` |
| `formatter: NumberFormatterService` (private let) | Там же | 17 | Подтверждено: `private let formatter = NumberFormatterService.shared` |
| `NumberFormatterService.format(_:) -> String` (public) | `Sources/Formatting/NumberFormatterService.swift` | 29 | Подтверждено: `public func format(_ value: Decimal) -> String` |
| `ButtonSpec` — struct, Identifiable | `Sources/Views/CalculatorButton.swift` | 105–111 | Подтверждено: содержит `id`, `label`, `type`, `isWide`, `isEnabled` |
| `CalculatorButton.spec: ButtonSpec` (let) | Там же | 117 | Подтверждено |
| `CalculatorButton.body` (var body) | Там же | 176–224 | Подтверждено: содержит `Button { ... } label: { ... }` на строках 180–206 |
| `CalculatorView.viewModel: CalculatorViewModel` (@Bindable) | `Sources/Views/CalculatorView.swift` | 7 | Подтверждено: `@Bindable var viewModel: CalculatorViewModel` |
| Кнопка MR в UI (строка 1 сетки) | Там же | 63 | Подтверждено: `ButtonSpec(label: .mR, type: .function, isEnabled: viewModel.hasMemory)` |
| `.help(_:)` (SwiftUI modifier) | SwiftUI framework | — | Подтверждено: стандартный modifier для macOS, принимает String или Text |
| `.overlay(content:)` (SwiftUI modifier) | SwiftUI framework | — | Подтверждено: стандартный modifier, принимает View builder |
| `Circle()` (SwiftUI shape) | SwiftUI framework | — | Подтверждено: стандартный shape для кругов |
| `.fill(_:)` (SwiftUI modifier) | SwiftUI framework | — | Подтверждено: заполняет shape цветом |
| `.frame(width:height:)` (SwiftUI modifier) | SwiftUI framework | — | Подтверждено: устанавливает размер view |

---

## 1. Диагностика: что именно нужно реализовать

### 1.1. Требование A: Зелёный кружочек на кнопке MR

**Когда показывать:** Когда в памяти есть непустое значение (`memoryValue != 0`, т.е. `hasMemory == true`).  
**Когда скрывать:** Когда память пуста (`memoryValue == 0`, т.е. `hasMemory == false`).

**Визуальная спецификация:**
- Размер: 8×8 пунктов (диаметр круга)
- Цвет: системный зелёный (`Color.green` или `Color.accentColor`)
- Позиция: правый верхний угол кнопки MR
- Форма: идеальный круг (`Circle()`)

### 1.2. Требование B: Всплывающая подсказка (tooltip) при наведении

**Когда показывать:** Только когда в памяти есть непустое значение (`hasMemory == true`).  
**Что показывать:** Отформатированное значение из памяти (например, "1,234.56" или "1.23e+10").  
**Как показывать:** Стандартный macOS tooltip при наведении курсора мыши.

**Форматирование значения:**
- Использовать существующий `NumberFormatterService.shared.format(memoryValue)` — тот же формат, что и для результатов вычислений
- Если `memoryValue == 0` — tooltip не показывается (nil)

---

## 2. Архитектурное решение: четыре изменения

### Изменение 1: Добавить computed property `memoryDisplayValue` в CalculatorViewModel

**Зачем:** UI нужен отформатированная строка значения памяти для отображения в tooltip. ViewModel — единственное место, где должно происходить форматирование (принцип MVVM).

**Где:** `Sources/ViewModels/CalculatorViewModel.swift`, сразу после computed property `hasMemory` (после строки 42), перед `func appendCharacter` (строка 44).

**Код для вставки:**
```swift
    /// Отформатированное значение памяти для отображения в UI (tooltip, индикация)
    var memoryDisplayValue: String? {
        guard memoryValue != 0 else { return nil }
        return formatter.format(memoryValue)
    }
```

**Пояснение построчно:**
- Строка 1–2: comment, описывающий назначение свойства
- Строка 3: `var memoryDisplayValue: String?` — computed property, тип `String?` (опциональная строка)
- Строка 4: `guard memoryValue != 0 else { return nil }` — если память пуста, возвращаем nil (tooltip не нужен)
- Строка 5: `return formatter.format(memoryValue)` — возвращаем отформатированное значение
- `formatter` — существует, строка 17: `private let formatter = NumberFormatterService.shared` ✓
- `formatter.format(_:)` — существует, NumberFormatterService.swift строка 29: `public func format(_ value: Decimal) -> String` ✓
- Оператор `!=` для Decimal — стандартная операция сравнения в Swift ✓

**Верификация зависимостей:**
- `memoryValue` — существует, строка 27: `private var memoryValue: Decimal = 0` ✓
- `formatter` — существует, строка 17: `private let formatter = NumberFormatterService.shared` ✓
- `formatter.format(_:)` — существует, NumberFormatterService.swift строка 29 ✓
- `guard ... else { return nil }` — стандартный Swift-оператор раннего выхода ✓

**Поведение:**
- Если `memoryValue = 0` → возвращает `nil` (tooltip не показывается)
- Если `memoryValue = 31` → возвращает `"31"` (tooltip показывает "31")
- Если `memoryValue = 1234.56` → возвращает `"1,234.56"` (tooltip показывает "1,234.56")
- Если `memoryValue = 1e+15` → возвращает `"1e+15"` (tooltip показывает научную нотацию)

**Важно:** Это свойство имеет уровень доступа `var` (public по умолчанию внутри модуля), а не `private`. Оно нужно из CalculatorButton и CalculatorView. `CalculatorViewModel` аннотирован как `@Observable` (строка 7), поэтому все `var` свойства автоматически становятся наблюдаемыми — UI будет обновляться при изменении `memoryValue`.

### Изменение 2: Добавить свойства в ButtonSpec для индикации памяти

**Зачем:** CalculatorButton — generic компонент, который не знает о специфике кнопки MR. Нужно передать ему информацию о состоянии памяти через ButtonSpec.

**Где:** `Sources/Views/CalculatorButton.swift`, структура `ButtonSpec` (строки 105–111).

**Текущий код:**
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
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
    var hasMemoryIndicator: Bool = false
    var memoryTooltip: String? = nil
}
```

**Что изменилось:** Добавлены две строки после `var isEnabled: Bool = true`:
- `var hasMemoryIndicator: Bool = false` — флаг для отображения зелёного кружочка
- `var memoryTooltip: String? = nil` — текст для всплывающей подсказки

**Пояснение:**
- `hasMemoryIndicator: Bool = false` — по умолчанию false (кружочек не показывается). Устанавливается в true только для кнопки MR когда память не пуста.
- `memoryTooltip: String? = nil` — по умолчанию nil (tooltip не показывается). Устанавливается в отформатированную строку только для кнопки MR когда память не пуста.
- Оба свойства имеют значения по умолчанию, поэтому все существующие вызовы `ButtonSpec(...)` остаются корректными ✓

**Верификация:**
- `ButtonSpec` — struct, Identifiable, строки 105–111 CalculatorButton.swift ✓
- Добавление свойств с дефолтными значениями не ломает существующие инициализаторы ✓
- Все аргументы в вызовах `ButtonSpec(...)` именованные, порядок не важен ✓

### Изменение 3: Обновить CalculatorView — передать данные о памяти в кнопку MR

**Зачем:** UI должен передавать состояние памяти в ButtonSpec для кнопки MR.

**Где:** `Sources/Views/CalculatorView.swift`, строка 63 (кнопка MR в строке 1 сетки).

**Текущий код:**
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory),
```

**Новый код:**
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue),
```

**Что изменилось:** Добавлены два именованных аргумента:
- `hasMemoryIndicator: viewModel.hasMemory` — передаёт computed property из ViewModel
- `memoryTooltip: viewModel.memoryDisplayValue` — передаёт отформатированную строку из ViewModel

**Верификация:**
- `viewModel` — существует, CalculatorView.swift строка 7: `@Bindable var viewModel: CalculatorViewModel` ✓
- `viewModel.hasMemory` — computed property, строка 42 CalculatorViewModel.swift: `var hasMemory: Bool { memoryValue != 0 }` ✓
- `viewModel.memoryDisplayValue` — computed property, добавляемый в Изменении 1: `var memoryDisplayValue: String?` ✓
- `@Bindable` — протокол SwiftUI, делает свойства Observable доступными для привязки в View ✓
- `ButtonSpec(label:type:isEnabled:hasMemoryIndicator:memoryTooltip:)` — инициализатор генерируется автоматически для struct с именованными полями ✓

**Обоснование, почему только MR:** Кнопки MC, M+, M− не требуют индикации памяти:
- MC (Очистить память) — всегда активна когда память не пуста, но индикация не нужна (пользователь и так видит что M+ добавлял значения)
- M+ (Добавить в память) — всегда активна, индикация не нужна
- M− (Вычесть из памяти) — всегда активна, индикация не нужна
- MR (Вспомнить из памяти) — единственная кнопка, которая показывает пользователю что именно хранится в памяти

### Изменение 4: Обновить CalculatorButton — добавить overlay и tooltip для MR

Это изменение состоит из двух частей: визуальная индикация (зелёный кружочек) и всплывающая подсказка.

#### 4a. Добавить `.overlay` с зелёным кружочком для индикации памяти

**Зачем:** Визуально показать пользователю, что в памяти есть значение.

**Где:** `Sources/Views/CalculatorButton.swift`, внутри body (строки 176–224), после строки 206 (закрывающая скобка `}` label closure), перед `.buttonStyle(.plain)` на строке 207.

**Текущий код (концовка label, строки 205–207):**
```swift
                }
        }
        .buttonStyle(.plain)
```

**Новый код (концовка label, строки 205–210):**
```swift
                }
        }
        .overlay(alignment: .topTrailing) {
            if spec.hasMemoryIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .offset(x: -4, y: -4)
            }
        }
        .buttonStyle(.plain)
```

**Пояснение построчно:**
- Строка 1–3: `.overlay(alignment: .topTrailing) {` — начинаем overlay, выравнивание по правому верхнему углу
- Строка 4: `if spec.hasMemoryIndicator {` — показываем overlay только когда флаг true
- Строка 5: `Circle()` — стандартный SwiftUI shape для идеального круга
- Строка 6: `.fill(Color.green)` — заполняем круг зелёным цветом
- Строка 7: `.frame(width: 8, height: 8)` — устанавливаем размер круга 8×8 пунктов
- Строка 8: `.offset(x: -4, y: -4)` — смещаем круг на 4 пункта влево и вверх (половина размера), чтобы он был в углу кнопки, а не за её пределами
- Строка 9: `}` — закрываем if
- Строка 10: `}` — закрываем overlay closure

**Верификация:**
- `.overlay(alignment:content:)` — стандартный SwiftUI modifier, принимает alignment и View builder ✓
- `.topTrailing` — стандартное выравнивание для overlay (правый верхний угол) ✓
- `spec.hasMemoryIndicator` — свойство ButtonSpec, добавляемое в Изменении 2 ✓
- `Circle()` — стандартный SwiftUI shape ✓
- `.fill(_:)` — стандартный modifier для заполнения shape цветом ✓
- `Color.green` — стандартный цвет SwiftUI (системный зелёный) ✓
- `.frame(width:height:)` — стандартный modifier для установки размера ✓
- `.offset(x:y:)` — стандартный modifier для смещения view ✓

**Позиционирование кружочка:**
- `alignment: .topTrailing` — overlay привязан к правому верхнему углу кнопки
- `.offset(x: -4, y: -4)` — смещаем круг на половину его размера (8/2 = 4) влево и вверх, чтобы он был виден в углу кнопки (половина круга за пределами кнопки)

#### 4b. Добавить `.help()` для всплывающей подсказки

**Зачем:** Показать пользователю отформатированное значение памяти при наведении курсора.

**Где:** `Sources/Views/CalculatorButton.swift`, внутри body (строки 176–224), после строки 223 (`.opacity(...)`), перед закрывающей скобкой `}` на строке 224.

**Текущий код (концовка body, строки 222–224):**
```swift
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
    }
```

**Новый код (концовка body, строки 222–226):**
```swift
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        .help(spec.memoryTooltip ?? "")
    }
```

**Что изменилось:** Добавлена строка `.help(spec.memoryTooltip ?? "")` после `.opacity(...)`.

**Пояснение:**
- `.help(_:)` — стандартный SwiftUI modifier для macOS, показывает всплывающую подсказку при наведении курсора
- `spec.memoryTooltip ?? ""` — если tooltip есть, показываем его; если nil (по умолчанию), показываем пустую строку (tooltip не отображается)
- `spec.memoryTooltip` — свойство ButtonSpec, добавляемое в Изменении 2 ✓
- Оператор `??` (nil coalescing) — стандартный Swift-оператор, возвращает левый операнд если он не nil, иначе правый ✓

**Поведение:**
- Если `memoryTooltip = "31"` → при наведении на кнопку MR показывается tooltip с текстом "31"
- Если `memoryTooltip = nil` → tooltip не отображается (пустая строка)

**Важно:** `.help("")` (пустая строка) не показывает tooltip — это корректное поведение по умолчанию.

---

## 3. Пошаговый план реализации (порядок действий)

Выполнять строго по порядку. Каждый шаг должен быть завершён и скомпилирован перед переходом к следующему.

### Шаг 1: CalculatorViewModel — добавить `memoryDisplayValue`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

**Контекст:** Открыть файл. Найти строку 42:
```swift
    var hasMemory: Bool { memoryValue != 0 }
```

Сразу после закрывающей скобки этой строки (после `}`), перед пустой строкой 43, и перед `func appendCharacter` на строке 44 — вставить следующий блок кода:

```swift
    /// Отформатированное значение памяти для отображения в UI (tooltip, индикация)
    var memoryDisplayValue: String? {
        guard memoryValue != 0 else { return nil }
        return formatter.format(memoryValue)
    }
```

**Проверка после вставки:** В файле между строкой 42 и строкой 44 (`func appendCharacter`) должны быть новые computed properties. Файл должен компилироваться без ошибок (но пока UI ещё не изменён, функциональность не нова).

**Верификация:**
- `memoryValue` — существует, строка 27: `private var memoryValue: Decimal = 0` ✓
- `formatter` — существует, строка 17: `private let formatter = NumberFormatterService.shared` ✓
- `formatter.format(_:)` — существует, NumberFormatterService.swift строка 29 ✓
- `guard ... else { return nil }` — стандартный Swift-оператор ✓

### Шаг 2: CalculatorButton — добавить свойства в ButtonSpec

**Файл:** `Sources/Views/CalculatorButton.swift`

**Контекст:** Найти строки 105–111:
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
}
```

**Заменить** эти строки (109–111) на:
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
    var hasMemoryIndicator: Bool = false
    var memoryTooltip: String? = nil
}
```

**Что именно меняется:** Добавлены две строки после `var isEnabled: Bool = true`:
- `var hasMemoryIndicator: Bool = false`
- `var memoryTooltip: String? = nil`

**Проверка:** `ButtonSpec` — struct, все свойства имеют значения по умолчанию или генерируются автоматически ✓

### Шаг 3: CalculatorView — передать данные о памяти в кнопку MR

**Файл:** `Sources/Views/CalculatorView.swift`

**Контекст:** Найти строку 63:
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory),
```

**Заменить** эту строку на:
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue),
```

**Что именно меняется:** После `isEnabled: viewModel.hasMemory)` добавлено `, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue`.

**Проверка:**
- `viewModel.hasMemory` — computed property, строка 42 CalculatorViewModel.swift ✓
- `viewModel.memoryDisplayValue` — computed property, добавляемый в Шаге 1 ✓
- `ButtonSpec(label:type:isEnabled:hasMemoryIndicator:memoryTooltip:)` — инициализатор генерируется автоматически ✓

### Шаг 4: CalculatorButton — добавить overlay с зелёным кружочком

**Файл:** `Sources/Views/CalculatorButton.swift`

**Контекст:** Найти строки 205–207 (концовка label):
```swift
                }
        }
        .buttonStyle(.plain)
```

**Заменить** эти строки (206–207) на:
```swift
                }
        }
        .overlay(alignment: .topTrailing) {
            if spec.hasMemoryIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .offset(x: -4, y: -4)
            }
        }
        .buttonStyle(.plain)
```

**Что именно меняется:** Между `}` (закрывающая скобка label closure) и `.buttonStyle(.plain)` вставлен overlay с condition.

**Проверка:**
- `.overlay(alignment:content:)` — стандартный SwiftUI modifier ✓
- `.topTrailing` — стандартное выравнивание ✓
- `spec.hasMemoryIndicator` — свойство ButtonSpec, добавляемое в Шаге 2 ✓
- `Circle()` — стандартный SwiftUI shape ✓
- `.fill(Color.green)` — стандартный modifier ✓
- `Color.green` — стандартный цвет SwiftUI ✓
- `.frame(width:height:)` — стандартный modifier ✓
- `.offset(x:y:)` — стандартный modifier ✓

### Шаг 5: CalculatorButton — добавить `.help()` для tooltip

**Файл:** `Sources/Views/CalculatorButton.swift`

**Контекст:** Найти строки 222–224 (концовка body):
```swift
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
    }
```

**Заменить** эти строки (223–224) на:
```swift
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        .help(spec.memoryTooltip ?? "")
    }
```

**Что именно меняется:** После `.opacity(...)` добавлена строка `.help(spec.memoryTooltip ?? "")`.

**Проверка:**
- `.help(_:)` — стандартный SwiftUI modifier для macOS ✓
- `spec.memoryTooltip` — свойство ButtonSpec, добавляемое в Шаге 2 ✓
- `?? ""` — стандартный Swift-оператор nil coalescing ✓

---

## 4. Итоговая таблица изменений по файлам

### Файл: `Sources/ViewModels/CalculatorViewModel.swift`

| Строка(и) | Тип изменения | Описание |
|---|---|---|
| После 42, перед 44 | Вставка (Шаг 1) | Добавлен `memoryDisplayValue: String?` computed property |

### Файл: `Sources/Views/CalculatorButton.swift`

| Строка(и) | Тип изменения | Описание |
|---|---|---|
| 111 (после) | Вставка (Шаг 2) | Добавлены `hasMemoryIndicator: Bool = false` и `memoryTooltip: String? = nil` в ButtonSpec |
| 206 (после) | Вставка (Шаг 4) | Добавлен `.overlay(...)` с зелёным кружочком после label closure |
| 223 (после) | Вставка (Шаг 5) | Добавлен `.help(spec.memoryTooltip ?? "")` в body |

### Файл: `Sources/Views/CalculatorView.swift`

| Строка(и) | Тип изменения | Описание |
|---|---|---|
| 63 | Замена (Шаг 3) | Добавлены `hasMemoryIndicator: viewModel.hasMemory` и `memoryTooltip: viewModel.memoryDisplayValue` в ButtonSpec для .mR |

---

## 5. Полный реестр верифицированных элементов

Все элементы, используемые в плане. Каждый подтверждён чтением исходного файла или документацией SwiftUI.

| Элемент | Файл/Фреймворк | Строка | Подтверждено |
|---|---|---|---|
| `@MainActor` | CalculatorViewModel.swift | 6 | Да |
| `@Observable` | CalculatorViewModel.swift | 7 | Да |
| `final class CalculatorViewModel` | CalculatorViewModel.swift | 8 | Да |
| `private var memoryValue: Decimal = 0` | CalculatorViewModel.swift | 27 | Да |
| `private let formatter = NumberFormatterService.shared` | CalculatorViewModel.swift | 17 | Да |
| `var hasMemory: Bool { memoryValue != 0 }` | CalculatorViewModel.swift | 42 | Да |
| `public func format(_ value: Decimal) -> String` | NumberFormatterService.swift | 29 | Да |
| `struct ButtonSpec: Identifiable` | CalculatorButton.swift | 105 | Да (будет расширена) |
| `var isEnabled: Bool = true` | CalculatorButton.swift | 110 | Да (будет расширена) |
| `let spec: ButtonSpec` | CalculatorButton.swift | 117 | Да |
| `var body: some View` | CalculatorButton.swift | 176 | Да |
| `Button { ... } label: { ... }` | CalculatorButton.swift | 180–206 | Да (будет добавлен overlay) |
| `.opacity(spec.isEnabled ? 1.0 : 0.4)` | CalculatorButton.swift | 223 | Да (будет добавлен help после) |
| `@Bindable var viewModel: CalculatorViewModel` | CalculatorView.swift | 7 | Да |
| `ButtonSpec(label: .mR, ...)` | CalculatorView.swift | 63 | Да (будет расширена) |
| `.overlay(alignment:content:)` | SwiftUI framework | — | Да: стандартный modifier, принимает alignment и View builder |
| `.topTrailing` | SwiftUI framework | — | Да: стандартное выравнивание для overlay |
| `Circle()` | SwiftUI framework | — | Да: стандартный shape для идеальных кругов |
| `.fill(_:)` | SwiftUI framework | — | Да: стандартный modifier для заполнения shape цветом |
| `Color.green` | SwiftUI framework | — | Да: стандартный системный зелёный цвет |
| `.frame(width:height:)` | SwiftUI framework | — | Да: стандартный modifier для установки размера |
| `.offset(x:y:)` | SwiftUI framework | — | Да: стандартный modifier для смещения view |
| `.help(_:)` | SwiftUI framework | — | Да: стандартный modifier для macOS tooltip, принимает String или Text |
| `??` (nil coalescing) | Swift standard library | — | Да: стандартный оператор, возвращает левый операнд если не nil, иначе правый |
| `guard ... else { return }` | Swift language | — | Да: стандартный оператор раннего выхода |
| `Decimal !=` (сравнение) | Foundation.framework | — | Да: Decimal conforms to Equatable, оператор != корректен |

---

## 6. Что НЕ изменяется (и почему)

| Элемент | Файл | Причина отсутствия изменений |
|---|---|---|
| `memoryClear()` | CalculatorViewModel.swift, 146–148 | Корректно сбрасывает только `memoryValue = 0`, не влияя на индикацию |
| `memoryAdd()` | CalculatorViewModel.swift, 150–153 | Корректно использует `currentDisplayValue`, не влияет на индикацию |
| `memorySubtract()` | CalculatorViewModel.swift, 155–158 | Корректно использует `currentDisplayValue`, не влияет на индикацию |
| `memoryRecall()` | CalculatorViewModel.swift, 160–165 | Корректно устанавливает expression из memoryValue, не влияет на индикацию |
| `currentDisplayValue` | CalculatorViewModel.swift, 32–39 | Уже существует, не требует изменений для этой задачи |
| `isEnabled` в ButtonSpec | CalculatorButton.swift, 110 | Уже существует, не требует изменений (используется для затемнения неактивных кнопок) |
| `.opacity(...)` в CalculatorButton | CalculatorButton.swift, 223 | Уже существует, не требует изменений (используется для индикации активности) |
| `guard spec.isEnabled else { return }` | CalculatorButton.swift, 181 | Уже существует, не требует изменений (блокирует нажатие неактивных кнопок) |
| Кнопки MC, M+, M− в CalculatorView | CalculatorView.swift, 60–62 | Не требуют индикации памяти (только MR показывает значение пользователю) |
| `handleButtonPress(_:)` | CalculatorView.swift, 131–165 | Не требует изменений (логика нажатий не меняется) |

---

## 7. Ожидаемое поведение после реализации

### Сценарий 1: Память пуста (initial state)

**Состояние:** `memoryValue = 0`, `hasMemory = false`, `memoryDisplayValue = nil`

**Визуальное поведение:**
- Кнопка MR: opacity = 0.4 (затемнена, т.к. `isEnabled = false` из-за `viewModel.hasMemory`)
- Зелёный кружочек: не отображается (т.к. `hasMemoryIndicator = false`)
- Tooltip: не отображается (т.к. `memoryTooltip = nil`, `.help("")` показывает пустую строку)

### Сценарий 2: Память заполнена (после M+)

**Состояние:** `memoryValue = 31`, `hasMemory = true`, `memoryDisplayValue = "31"`

**Визуальное поведение:**
- Кнопка MR: opacity = 1.0 (полностью видна, т.к. `isEnabled = true` из-за `viewModel.hasMemory`)
- Зелёный кружочек: отображается в правом верхнем углу кнопки (т.к. `hasMemoryIndicator = true`)
- Tooltip: при наведении курсора показывается "31" (т.к. `memoryTooltip = "31"`)

### Сценарий 3: Память очищена (после MC)

**Состояние:** `memoryValue = 0`, `hasMemory = false`, `memoryDisplayValue = nil`

**Визуальное поведение:**
- Возвращается к состоянию сценария 1 (кружочек исчезает, tooltip исчезает, кнопка затемняется)

### Сценарий 4: Большое значение в памяти (после M+ с большим числом)

**Состояние:** `memoryValue = 1234567.89`, `hasMemory = true`, `memoryDisplayValue = "1,234,567.89"`

**Визуальное поведение:**
- Кнопка MR: opacity = 1.0 (полностью видна)
- Зелёный кружочек: отображается в правом верхнем углу
- Tooltip: при наведении курсора показывается "1,234,567.89" (отформатированное значение)

### Сценарий 5: Научная нотация в памяти (после M+ с очень большим числом)

**Состояние:** `memoryValue = 1e+15`, `hasMemory = true`, `memoryDisplayValue = "1e+15"`

**Визуальное поведение:**
- Кнопка MR: opacity = 1.0 (полностью видна)
- Зелёный кружочек: отображается в правом верхнем углу
- Tooltip: при наведении курсора показывается "1e+15" (научная нотация)

---

## 8. Проверка компиляции после каждого шага

После каждого из 5 шагов необходимо выполнить сборку проекта для проверки корректности:

```bash
swift build
```

**Ожидаемый результат:** `Build succeeded` без ошибок и предупреждений.

**Если возникают ошибки:**
- Ошибка "Cannot find 'memoryDisplayValue' in scope" → проверить, что Шаг 1 выполнен корректно
- Ошибка "Cannot find 'hasMemoryIndicator' in scope" → проверить, что Шаг 2 выполнен корректно
- Ошибка "Cannot find 'memoryTooltip' in scope" → проверить, что Шаг 2 выполнен корректно
- Ошибка "Cannot find 'overlay' in scope" → проверить, что используется SwiftUI (import SwiftUI в CalculatorButton.swift уже есть)
- Ошибка "Cannot find 'Circle' in scope" → проверить, что используется SwiftUI (import SwiftUI в CalculatorButton.swift уже есть)
- Ошибка "Cannot find 'help' in scope" → проверить, что используется macOS (SwiftUI .help() доступен на macOS 13+)

---

## 9. Тестирование после реализации

После завершения всех шагов необходимо проверить следующее:

### Ручное тестирование

1. **Запустить приложение** и убедиться, что:
   - Кнопка MR изначально затемнена (opacity = 0.4)
   - Зелёный кружочек не отображается
   - При наведении на MR tooltip не показывается

2. **Нажать M+** (после вычисления любого выражения):
   - Кнопка MR становится полностью видимой (opacity = 1.0)
   - Появляется зелёный кружочек в правом верхнем углу
   - При наведении на MR показывается tooltip с отформатированным значением

3. **Нажать MC:**
   - Кнопка MR снова затемняется (opacity = 0.4)
   - Зелёный кружочек исчезает
   - Tooltip исчезает

4. **Нажать M+ с большим числом** (например, 1234567.89):
   - Tooltip показывает "1,234,567.89" (с разделителями тысяч)

5. **Нажать M+ с очень большим числом** (например, 1e+15):
   - Tooltip показывает "1e+15" (научная нотация)

### Автоматическое тестирование

Запустить существующие UI-тесты:
```bash
swift test --filter CalculatorUITests
```

**Ожидаемый результат:** Все 11 существующих UI-тестов проходят успешно.

---

## 10. Заключение

Этот план реализует два улучшения для кнопки MR:
1. **Зелёный кружочек** — визуальная индикация наличия значения в памяти
2. **Всплывающая подсказка** — отображение отформатированного значения при наведении курсора

Решение архитектурно корректно, т.к.:
- Форматирование значения происходит в ViewModel (принцип MVVM)
- UI получает только готовые данные для отображения
- CalculatorButton остаётся переиспользуемым компонентом (данные передаются через ButtonSpec)
- Все изменения минимальны и локализованы (3 файла, 5 шагов)
- Не нарушается существующая функциональность (все изменения обратимы)

После реализации пользователь получит интуитивно понятную индикацию состояния памяти, соответствующую стандартам macOS Calculator.app.
