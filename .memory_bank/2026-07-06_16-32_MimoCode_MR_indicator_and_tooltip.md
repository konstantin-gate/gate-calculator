# План: индикатор памяти и тултип на кнопке MR

**Дата:** 2026-07-06  
**Агент:** MimoCode  
**Статус:** Готов к реализации  
**Задача:** Добавить зелёный индикатор на кнопку MR при наличии значения в памяти + тултип при наведении

---

## 0. Верификация элементов кода

Все элементы, на которые ссылается план, подтверждены чтением актуальных исходников.

| Элемент | Файл | Строка | Статус |
|---|---|---|---|
| `private var memoryValue: Decimal = 0` | CalculatorViewModel.swift | 27 | Подтверждено |
| `var hasMemory: Bool { memoryValue != 0 }` | CalculatorViewModel.swift | 42 | Подтверждено |
| `private let formatter = NumberFormatterService.shared` | CalculatorViewModel.swift | 17 | Подтверждено |
| `struct ButtonSpec: Identifiable` | CalculatorButton.swift | 105 | Подтверждено |
| `var isEnabled: Bool = true` (в ButtonSpec) | CalculatorButton.swift | 110 | Подтверждено |
| `struct CalculatorButton: View` | CalculatorButton.swift | 115 | Подтверждено |
| `let spec: ButtonSpec` | CalculatorButton.swift | 117 | Подтверждено |
| `var body: some View` (CalculatorButton) | CalculatorButton.swift | 176 | Подтверждено |
| `.opacity(spec.isEnabled ? 1.0 : 0.4)` (последний модификатор) | CalculatorButton.swift | 223 | Подтверждено |
| `ButtonSpec(label: .mR, type: .function, isEnabled: viewModel.hasMemory)` | CalculatorView.swift | 63 | Подтверждено |
| `@Bindable var viewModel: CalculatorViewModel` | CalculatorView.swift | 7 | Подтверждено |
| `NumberFormatterService.shared.format(_:) -> String` | NumberFormatterService.swift | 29 | Подтверждено |
| `ButtonLabel.mR` (case enum) | CalculatorButton.swift | 35 | Подтверждено |
| `ButtonLabel.mR.displayTitle == "MR"` | CalculatorButton.swift | 57 | Подтверждено |

---

## 1. Суть задачи

Добавить два визуальных элемента на кнопку MR:

1. **Зелёный кружочек** в правом нижнем углу — появляется когда `memoryValue != 0`, исчезает когда `memoryValue == 0`
2. **Тултип при наведении** — показывает хранимое значение памяти (например, "Память: 31")

Оба элемента привязаны к одному условию: `viewModel.hasMemory`.

---

## 2. Архитектурное решение

### 2.1. Вычислить строковое представление памяти в ViewModel

**Проблема:** `memoryValue` — private свойство типа `Decimal`. UI-слой не может получить его значение напрямую. Нужен computed property, возвращающий отформатированную строку.

**Решение:** Добавить `memoryDisplayValue: String` в `CalculatorViewModel`.

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Куда:** После строки 42 (`var hasMemory: Bool { memoryValue != 0 }`), перед пустой строкой 43, перед `func appendCharacter` на строке 44.

**Код:**
```swift
    /// Отформатированное значение памяти для отображения в тултипе
    var memoryDisplayValue: String {
        formatter.format(memoryValue)
    }
```

**Верификация зависимостей:**
- `formatter` — существует, строка 17: `private let formatter = NumberFormatterService.shared` ✓
- `memoryValue` — существует, строка 27: `private var memoryValue: Decimal = 0` ✓
- `formatter.format(_:)` — публичный метод NumberFormatterService, принимает `Decimal`, возвращает `String` ✓
- Свойство `var` (не private) — доступно из CalculatorView в том же модуле ✓

### 2.2. Добавить свойства в ButtonSpec

**Проблема:** `ButtonSpec` не имеет параметров для индикатора и тултипа. `CalculatorButton` — generic-компонент, не знающий о памяти.

**Решение:** Расширить `ButtonSpec` двумя новыми свойствами с дефолтными значениями.

**Файл:** `Sources/Views/CalculatorButton.swift`  
**Куда:** В структуру `ButtonSpec` (строки 105-111), после строки 110 (`var isEnabled: Bool = true`), перед закрывающей скобкой `}` на строке 111.

**Код:**
```swift
    var showsIndicator: Bool = false    // зелёный кружочек в правом нижнем углу
    var tooltip: String? = nil          // текст тултипа при наведении
```

**Верификация:**
- Оба свойства имеют значения по умолчанию → существующие вызовы `ButtonSpec(label:type:)` без этих аргументов продолжат работать ✓
- `showsIndicator: Bool` — простой тип ✓
- `tooltip: String?` — опциональная строка, nil означает «без тултипа» ✓

### 2.3. Отобразить зелёный кружочек в CalculatorButton

**Решение:** Добавить `.overlay(alignment: .bottomTrailing)` на `Button`-вид (после `.opacity()`), рисующий маленький `Circle()` при `spec.showsIndicator == true`.

**Файл:** `Sources/Views/CalculatorButton.swift`  
**Куда:** После строки 223 (`.opacity(spec.isEnabled ? 1.0 : 0.4)`), перед закрывающей скобкой `}` на строке 224.

**Код:**
```swift
        .overlay(alignment: .bottomTrailing) {
            if spec.showsIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
```

**Пояснение:**
- `.overlay(alignment: .bottomTrailing)` — размещает содержимое в правом нижнем углу родительского вида
- `Circle()` — круглая форма кружочка
- `.fill(Color.green)` — зелёная заливка (адаптируется к светлой/тёмной теме)
- `.frame(width: 8, height: 8)` — размер 8×8 points (компактный, не перекрывает текст "MR")
- `.padding(6)` — отступ 6 points от правого и нижнего краёв кнопки
- `.accessibilityHidden(true)` — VoiceOver игнорирует кружочек (чисто визуальный элемент)

**Почему overlay на Button, а не внутри label:**
Контент label проходит через `.clipShape(RoundedRectangle(...))` — если положить кружок внутрь, его обрежет. Размещение на `Button`-виде (вне label closure) гарантирует, что кружок не будет обрезан.

**Верификация:**
- `.overlay(alignment:)` — стандартный SwiftUI-модификатор, доступен с macOS 12 ✓
- `Color.green` — системный цвет, адаптируется к теме ✓
- `.accessibilityHidden(true)` — стандартный SwiftUI-модификатор ✓

### 2.4. Добавить тултип в CalculatorButton

**Решение:** Применить `.help(spec.tooltip ?? "")` на `Button`-вид.

**Файл:** `Sources/Views/CalculatorButton.swift`  
**Куда:** После добавленного `.overlay(...)` (из п. 2.3), перед закрывающей скобкой `}` на строке 224.

**Код:**
```swift
        .help(spec.tooltip ?? "")
```

**Пояснение:**
- `.help(_:)` — стандартный macOS SwiftUI-модификатор, показывает всплывающую подсказку при наведении курсора
- `spec.tooltip ?? ""` — если tooltip == nil, передаётся пустая строка (пустой тултип не отображается)
- Не конфликтует с `.accessibilityHint()` — это независимые механизмы

**Верификация:**
- `.help(_:)` — доступен на macOS 12+, платформа проекта macOS 14 ✓
- `spec.tooltip` — свойство ButtonSpec из п. 2.2 ✓

### 2.5. Передать параметры в кнопку MR

**Решение:** В `CalculatorView` добавить `showsIndicator` и `tooltip` в `ButtonSpec` для кнопки MR.

**Файл:** `Sources/Views/CalculatorView.swift`  
**Куда:** Строка 63, заменить создание ButtonSpec для .mR.

**Текущий код (строка 63):**
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory),
```

**Новый код:**
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, showsIndicator: viewModel.hasMemory, tooltip: viewModel.hasMemory ? NSLocalizedString("memory.tooltip", comment: "") + viewModel.memoryDisplayValue : nil),
```

**Верификация:**
- `viewModel.hasMemory` — computed property из CalculatorViewModel, строка 42 ✓
- `viewModel.memoryDisplayValue` — computed property из п. 2.1 ✓
- `NSLocalizedString("memory.tooltip", comment: "")` — локализованный ключ (добавляется в п. 2.6) ✓
- `showsIndicator:` — именованный аргумент ButtonSpec из п. 2.2 ✓
- `tooltip:` — именованный аргумент ButtonSpec из п. 2.2 ✓

### 2.6. Добавить локализацию

**Файл:** `Sources/Localization/en.lproj/Localizable.strings`  
**Добавить строку:**
```
"memory.tooltip" = "Memory: ";
```

**Файл:** `Sources/Localization/ru.lproj/Localizable.strings`  
**Добавить строку:**
```
"memory.tooltip" = "Память: ";
```

**Верификация:**
- Файлы локализации существуют (подтверждено документацией, раздел 7.2) ✓
- Формат `"key" = "value";` — стандартный формат .strings ✓
- Пробел после двоеточия — для читаемости ("Память: 31", а не "Память:31") ✓

---

## 3. Пошаговый план реализации

### Шаг 1: CalculatorViewModel — добавить `memoryDisplayValue`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

Найти строку 42:
```swift
    var hasMemory: Bool { memoryValue != 0 }
```

После неё (между строкой 42 и строкой 44 `func appendCharacter`) вставить:

```swift

    /// Отформатированное значение памяти для отображения в тултипе
    var memoryDisplayValue: String {
        formatter.format(memoryValue)
    }
```

**Проверка:** Файл компилируется. Новое свойство доступно из CalculatorView.

---

### Шаг 2: CalculatorButton — добавить свойства в ButtonSpec

**Файл:** `Sources/Views/CalculatorButton.swift`

Найти строки 105-111:
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
}
```

Заменить на:
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
    var showsIndicator: Bool = false    // зелёный кружочек в правом нижнем углу
    var tooltip: String? = nil          // текст тултипа при наведении
}
```

**Проверка:** Все существующие `ButtonSpec(label:type:)` вызовы продолжают работать (новые свойства имеют дефолты).

---

### Шаг 3: CalculatorButton — добавить overlay и help в body

**Файл:** `Sources/Views/CalculatorButton.swift`

Найти строки 223-224 (конец body):
```swift
        .opacity(spec.isEnabled ? 1.0 : 0.4)
    }
```

Заменить на:
```swift
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        .overlay(alignment: .bottomTrailing) {
            if spec.showsIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .help(spec.tooltip ?? "")
    }
```

**Проверка:** Кружочек отображается только когда `showsIndicator == true`. Тултип отображается только когда `tooltip != nil`.

---

### Шаг 4: CalculatorView — передать параметры в кнопку MR

**Файл:** `Sources/Views/CalculatorView.swift`

Найти строку 63:
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory),
```

Заменить на:
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, showsIndicator: viewModel.hasMemory, tooltip: viewModel.hasMemory ? NSLocalizedString("memory.tooltip", comment: "") + viewModel.memoryDisplayValue : nil),
```

**Проверка:** Кнопка MR получает индикатор и тултип только когда память непуста.

---

### Шаг 5: Локализация — добавить ключ `memory.tooltip`

**Файл:** `Sources/Localization/en.lproj/Localizable.strings`

Добавить в конец файла:
```
"memory.tooltip" = "Memory: ";
```

**Файл:** `Sources/Localization/ru.lproj/Localizable.strings`

Добавить в конец файла:
```
"memory.tooltip" = "Память: ";
```

**Проверка:** Ключ доступен через `NSLocalizedString("memory.tooltip", comment: "")`.

---

## 4. Итоговая таблица изменений

### `Sources/ViewModels/CalculatorViewModel.swift`

| Строка | Тип | Описание |
|---|---|---|
| После 42 | Вставка | Добавлен `memoryDisplayValue: String` computed property |

### `Sources/Views/CalculatorButton.swift`

| Строка | Тип | Описание |
|---|---|---|
| 110 (после) | Вставка | Добавлены `showsIndicator: Bool = false` и `tooltip: String? = nil` в ButtonSpec |
| 223 (после) | Замена | Добавлен `.overlay(...)` с зелёным кружком и `.help(...)` для тултипа |

### `Sources/Views/CalculatorView.swift`

| Строка | Тип | Описание |
|---|---|---|
| 63 | Замена | Добавлены `showsIndicator:` и `tooltip:` в ButtonSpec для .mR |

### `Sources/Localization/en.lproj/Localizable.strings`

| Тип | Описание |
|---|---|
| Добавление | Новая строка `"memory.tooltip" = "Memory: ";` |

### `Sources/Localization/ru.lproj/Localizable.strings`

| Тип | Описание |
|---|---|
| Добавление | Новая строка `"memory.tooltip" = "Память: ";` |

---

## 5. Что НЕ изменяется

| Элемент | Почему |
|---|---|
| `memoryValue` (private var) | Инкапсуляция сохраняется; UI получает данные через computed properties |
| `hasMemory` (computed) | Уже существует и корректно работает |
| `memoryClear()`, `memoryAdd()`, `memorySubtract()`, `memoryRecall()` | Логика памяти не затронута |
| Кнопки MC, M+, M− | Индикатор и тултип — только для MR по заданию |
| `CalculatorButton.body` структура | Добавлены модификаторы в конец цепочки, существующий код не меняется |
| `ButtonLabel` enum | Не расширяется — индикатор управляется через ButtonSpec |

---

## 6. Сценарии проверки

| Сценарий | Ожидаемое поведение |
|---|---|
| Память пуста (memoryValue == 0) | Кнопка MR затемнена (opacity 0.4), кружка нет, тултипа нет |
| Пользователь нажал M+ (записал число) | Кнопка MR активна (opacity 1.0), зелёный кружок виден, тултип "Память: <значение>" |
| Пользователь нажал MC | Кружок исчезает, тултип исчезает, кнопка MR затемняется |
| Пользователь навёл курсор на MR (память есть) | Появляется тултип "Память: <значение>" |
| Пользователь навёл курсор на MR (память пуста) | Тултип не появляется |
| Пользователь нажал MR | Значение из памяти вставляется в expression (существующее поведение), кружок остаётся |
| Пользователь сделал M− до нуля (memoryValue == 0) | Кружок исчезает, кнопка MR затемняется |

---

*План создан на основе анализа актуальных исходников проекта GateCalc, 6 июля 2026.*
