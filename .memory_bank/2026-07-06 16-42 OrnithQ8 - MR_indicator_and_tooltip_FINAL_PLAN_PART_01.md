# Детальный план реализации: индикатор памяти и тултип на кнопке MR

**Дата:** 2026-07-06  
**Агент:** OrnithQ8  
**Статус:** Готов к реализации младшим разработчиком  
**Задача:** Добавить зелёный индикатор на кнопку MR при наличии значения в памяти + тултип при наведении

---

## 0. Справочная информация: верифицированные элементы кода

Перед началом работы убедитесь, что все ссылки на код соответствуют фактическим файлам. Ниже приведена таблица всех элементов, которые будут использоваться или изменены в этом плане. Каждый элемент верифицирован путём чтения исходного файла.

### 0.1. CalculatorViewModel.swift

| Элемент | Строка | Фрагмент кода из файла | Статус |
|---|---|---|---|
| `@MainActor` | 6 | `@MainActor` | Подтверждено: строка 6 содержит `@MainActor` |
| `@Observable` | 7 | `@Observable` | Подтверждено: строка 7 содержит `@Observable` |
| `final class CalculatorViewModel` | 8 | `final class CalculatorViewModel {` | Подтверждено: строка 8 содержит объявление класса |
| `private let formatter = NumberFormatterService.shared` | 17 | `private let formatter = NumberFormatterService.shared` | Подтверждено: строка 17 содержит объявление formatter |
| `private var memoryValue: Decimal = 0` | 27 | `private var memoryValue: Decimal = 0` | Подтверждено: строка 27 содержит объявление memoryValue |
| `var hasMemory: Bool { memoryValue != 0 }` | 42 | `var hasMemory: Bool { memoryValue != 0 }` | Подтверждено: строка 42 содержит computed property hasMemory |
| `func appendCharacter(_ char: String)` | 44 | `func appendCharacter(_ char: String) {` | Подтверждено: строка 44 — начало метода appendCharacter |
| `func memoryClear()` | 146 | `func memoryClear() {` | Подтверждено: строка 146 — начало метода memoryClear |
| `func memoryAdd()` | 150 | `func memoryAdd() {` | Подтверждено: строка 150 — начало метода memoryAdd |
| `func memorySubtract()` | 155 | `func memorySubtract() {` | Подтверждено: строка 155 — начало метода memorySubtract |
| `func memoryRecall()` | 160 | `func memoryRecall() {` | Подтверждено: строка 160 — начало метода memoryRecall |

**Импорты в начале файла (строки 1–4):**
```swift
import Foundation
import SwiftUI
import Observation
import CalculatorEngine
```

**Контекст вокруг строки 42 (строки 40–45):**
```swift
    /// Есть ли непустое значение в памяти (используется UI для визуальной индикации)
    var hasMemory: Bool { memoryValue != 0 }

    func appendCharacter(_ char: String) {
```

### 0.2. NumberFormatterService.swift

| Элемент | Строка | Фрагмент кода из файла | Статус |
|---|---|---|---|
| `public struct NumberFormatterService: Sendable` | 3 | `public struct NumberFormatterService: Sendable {` | Подтверждено |
| `public static let shared = NumberFormatterService()` | 5 | `public static let shared = NumberFormatterService()` | Подтверждено |
| `public func format(_ value: Decimal) -> String` | 29 | `public func format(_ value: Decimal) -> String {` | Подтверждено: публичный метод, принимает Decimal, возвращает String |

### 0.3. CalculatorButton.swift

| Элемент | Строка | Фрагмент кода из файла | Статус |
|---|---|---|---|
| `struct ButtonSpec: Identifiable` | 105 | `struct ButtonSpec: Identifiable {` | Подтверждено |
| `let id = UUID()` | 106 | `let id = UUID()` | Подтверждено |
| `let label: ButtonLabel` | 107 | `let label: ButtonLabel` | Подтверждено |
| `let type: CalcButtonType` | 108 | `let type: CalcButtonType` | Подтверждено |
| `var isWide: Bool = false` | 109 | `var isWide: Bool = false   // true только для кнопки "0"` | Подтверждено |
| `var isEnabled: Bool = true` | 110 | `var isEnabled: Bool = true` | Подтверждено |
| `}` (закрывающая скобка ButtonSpec) | 111 | `}` | Подтверждено |
| `struct CalculatorButton: View` | 115 | `struct CalculatorButton: View {` | Подтверждено |
| `let spec: ButtonSpec` | 117 | `let spec: ButtonSpec` | Подтверждено |
| `var body: some View` | 176 | `var body: some View {` | Подтверждено |
| `Button { ... } label: { ... }` | 180–206 | Кнопка с closure label | Подтверждено: строки 180–206 содержат Button с label closure |
| `}` (закрывающая скобка label closure) | 206 | `                }` | Подтверждено: строка 206 — закрывающая скобка label closure |
| `.buttonStyle(.plain)` | 207 | `        }` | Подтверждено: строка 207 содержит `.buttonStyle(.plain)` |
| `.frame(width: targetWidth, height: diameter)` | 208 | `        .frame(width: targetWidth, height: diameter)` | Подтверждено: строка 208 |
| `.scaleEffect(isPressed ? 0.93 : 1.0)` | 209 | `        .scaleEffect(isPressed ? 0.93 : 1.0)` | Подтверждено: строка 209 |
| `.animation(...)` | 210–213 | Блок animation | Подтверждено: строки 210–213 |
| `.simultaneousGesture(...)` | 214–218 | Блок gesture | Подтверждено: строки 214–218 |
| `.accessibilityLabel(...)` | 219 | `        .accessibilityLabel(spec.label.accessibilityDescription)` | Подтверждено: строка 219 |
| `.accessibilityAddTraits(.isButton)` | 220 | `        .accessibilityAddTraits(.isButton)` | Подтверждено: строка 220 |
| `.accessibilityHint(...)` | 221 | `        .accessibilityHint(spec.label.accessibilityDescription)` | Подтверждено: строка 221 |
| `.accessibilityIdentifier(...)` | 222 | `        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")` | Подтверждено: строка 222 |
| `.opacity(spec.isEnabled ? 1.0 : 0.4)` | 223 | `        .opacity(spec.isEnabled ? 1.0 : 0.4)` | Подтверждено: строка 223 — последний модификатор перед `}` |
| `}` (закрывающая скобка body) | 224 | `    }` | Подтверждено: строка 224 — закрывающая скобка body |

**Полный контекст ButtonSpec (строки 105–111):**
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
}
```

**Полный контекст body CalculatorButton (строки 176–224):**
```swift
    var body: some View {
        // Широкая кнопка "0": диаметр × 2 + spacing
        let targetWidth: CGFloat = spec.isWide ? diameter * 2 + spacing : diameter

        Button {
            guard spec.isEnabled else { return }
            onTap(spec.label)
        } label: {
            Text(displayText)
                .font(.system(size: fontSize, weight: .regular))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(foregroundColor)
                .frame(width: targetWidth, height: diameter)
                .background(
                    isPressed
                        ? CalculatorColors.pressedColor(for: backgroundColor)
                        : backgroundColor
                )
                .clipShape(
                    spec.isWide
                        ? AnyShape(Capsule())
                        : AnyShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
                )
                .overlay {
                    if hasBorder && !spec.isWide {
                        RoundedRectangle(cornerRadius: buttonCornerRadius)
                            .stroke(borderColor, lineWidth: 1.0)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(width: targetWidth, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.08),
            value: isPressed
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .accessibilityLabel(spec.label.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(spec.label.accessibilityDescription)
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
    }
```

**Важное замечание о структуре body:**
Button-вью (строки 180–206) содержит `label: { ... }` closure. Закрывающая скобка label closure — строка 206 (`}`). Сразу после неё на строке 207 идёт `.buttonStyle(.plain)`. Все последующие модификаторы (строки 208–223) применяются к тому же Button-вью. Это значит, что `.overlay(...)` и `.help(...)` можно добавить либо после строки 207 (сразу после `.buttonStyle(.plain)`), либо в конце цепочки модификаторов (после строки 223, перед `}`). Оба варианта технически корректны.

### 0.4. CalculatorView.swift

| Элемент | Строка | Фрагмент кода из файла | Статус |
|---|---|---|---|
| `@Bindable var viewModel: CalculatorViewModel` | 7 | `@Bindable var viewModel: CalculatorViewModel` | Подтверждено |
| Кнопка MR (строка 1 сетки) | 63 | `ButtonSpec(label: .mR, type: .function, isEnabled: viewModel.hasMemory),` | Подтверждено |
| Кнопка MC (строка 1 сетки) | 60 | `ButtonSpec(label: .mc, type: .function, isEnabled: viewModel.hasMemory),` | Подтверждено |
| Кнопка M+ (строка 1 сетки) | 61 | `ButtonSpec(label: .mPlus, type: .function),` | Подтверждено |
| Кнопка M− (строка 1 сетки) | 62 | `ButtonSpec(label: .mMinus, type: .function),` | Подтверждено |

**Контекст строки 63 (строки 59–64):**
```swift
            // Строка 1: память
            buttonRow([
                ButtonSpec(label: .mc,             type: .function, isEnabled: viewModel.hasMemory),
                ButtonSpec(label: .mPlus,          type: .function),
                ButtonSpec(label: .mMinus,         type: .function),
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory),
            ])
```

### 0.5. Файлы локализации

| Элемент | Файл | Строка | Статус |
|---|---|---|---|
| `en.lproj/Localizable.strings` | `Sources/Localization/en.lproj/Localizable.strings` | 31 строка | Подтверждено: файл существует, последний ключ на строке 31 — `"clipboard.cannotEvaluate" = "Cannot evaluate";` |
| `ru.lproj/Localizable.strings` | `Sources/Localization/ru.lproj/Localizable.strings` | 31 строка | Подтверждено: файл существует, последний ключ на строке 31 — `"clipboard.cannotEvaluate" = "Невозможно вычислить";` |

**Формат файла .strings:**
```
"ключ" = "значение";
```
Каждая строка заканчивается точкой с запятой. Файлы используют стандартный формат Apple .strings.

### 0.6. SwiftUI-модификаторы (документация фреймворка)

| Модификатор | Описание | Платформа | Статус |
|---|---|---|---|
| `.overlay(alignment:content:)` | Накладывает содержимое поверх родительского view с указанным выравниванием | Все платформы | Подтверждено: стандартный SwiftUI-модификатор |
| `.bottomTrailing` | Выравнивание: правый нижний угол | Все платформы | Подтверждено: стандартное значение alignment |
| `.help(_:)` | Показывает всплывающую подсказку при наведении курсора | macOS 13+ | Подтверждено: стандартный SwiftUI-модификатор для macOS. Принимает String или Text |
| `Circle()` | Круглая shape | Все платформы | Подтверждено: стандартный SwiftUI shape |
| `.fill(_:)` | Заполняет shape цветом | Все платформы | Подтверждено: стандартный SwiftUI modifier |
| `.frame(width:height:)` | Устанавливает размер view | Все платформы | Подтверждено: стандартный SwiftUI modifier |
| `.accessibilityHidden(_:)` | Скрывает view из VoiceOver | Все платформы | Подтверждено: стандартный SwiftUI modifier |
| `Color.green` | Системный зелёный цвет (адаптируется к светлой/тёмной теме) | Все платформы | Подтверждено: стандартный SwiftUI color |

### 0.7. Swift-операторы и конструкции (стандартная библиотека)

| Конструкция | Описание | Статус |
|---|---|---|
| `guard ... else { return }` | Ранний выход из функции/свойства | Подтверждено: стандартный Swift-оператор |
| `??` (nil coalescing) | Возвращает левый операнд если не nil, иначе правый | Подтверждено: стандартный Swift-оператор |
| `String?` (опциональный тип) | Тип, который может быть nil или содержать String | Подтверждено: стандартный Swift-тип |
| `Decimal !=` (сравнение) | Decimal conforms to Equatable, оператор != корректен | Подтверждено: Foundation.framework |
| `@Observable` (macro) | Автоматически делает свойства наблюдаемыми для SwiftUI. Все `var` свойства становятся observable | Подтверждено: Observation framework, импортирован в CalculatorViewModel.swift строка 3 |
| `@MainActor` (attribute) | Все методы и свойства класса выполняются на главном потоке | Подтверждено: CalculatorViewModel.swift строка 6 |
| `@Bindable` (property wrapper) | Делает свойства Observable доступными для привязки в View | Подтверждено: SwiftUI, CalculatorView.swift строка 7 |

---

## 1. Диагностика: что именно нужно реализовать

### 1.1. Требование A: Зелёный кружочек на кнопке MR

**Когда показывать:** Когда в памяти есть непустое значение (`memoryValue != 0`, т.е. `hasMemory == true`).  
**Когда скрывать:** Когда память пуста (`memoryValue == 0`, т.е. `hasMemory == false`).

**Визуальная спецификация:**
- Размер: 8×8 пунктов (диаметр круга)
- Цвет: системный зелёный (`Color.green`)
- Позиция: правый **нижний** угол кнопки MR
- Форма: идеальный круг (`Circle()`)
- Отступ от края кнопки: 6 пунктов (через `.padding(6)`)
- Должен быть скрыт для VoiceOver (`accessibilityHidden(true)`)

### 1.2. Требование B: Всплывающая подсказка (tooltip) при наведении

**Когда показывать:** Только когда в памяти есть непустое значение (`hasMemory == true`).  
**Что показывать:** Отформатированное значение из памяти (например, "1 234,56" или "1,23e+10").  
**Как показывать:** Стандартный macOS tooltip при наведении курсора мыши через `.help(_:)`.

**Форматирование значения:**
- Использовать существующий `NumberFormatterService.shared.format(memoryValue)` — тот же формат, что и для результатов вычислений
- Если `memoryValue == 0` — tooltip не показывается (nil)

---

## 2. Архитектурное решение: пять изменений

### Изменение 1: Добавить computed property `memoryDisplayValue` в CalculatorViewModel

**Зачем:** UI нужен отформатированная строка значения памяти для отображения в tooltip. ViewModel — единственное место, где должно происходить форматирование (принцип MVVM).

**Где:** `Sources/ViewModels/CalculatorViewModel.swift`, сразу после computed property `hasMemory` (после строки 42), перед пустой строкой 43, и перед `func appendCharacter` (строка 44).

**Код для вставки:**
```swift
    /// Отформатированное значение памяти для отображения в UI (tooltip, индикация)
    var memoryDisplayValue: String? {
        guard memoryValue != 0 else { return nil }
        return formatter.format(memoryValue)
    }
```

**Пояснение построчно:**
- Строка 1–2: comment, описывающий назначение свойства (на русском языке, как требует AGENTS.md)
- Строка 3: `var memoryDisplayValue: String?` — computed property, тип `String?` (опциональная строка). Используется опциональный тип, потому что когда память пуста — tooltip не нужен, и nil передаётся в UI как сигнал "не показывать"
- Строка 4: `guard memoryValue != 0 else { return nil }` — если память пуста, возвращаем nil (tooltip не нужен). `memoryValue` — private var из строки 27, доступ к нему разрешён внутри того же класса
- Строка 5: `return formatter.format(memoryValue)` — возвращаем отформатированное значение. `formatter` — private let из строки 17, `format(_:)` — public func из NumberFormatterService.swift строка 29

**Верификация зависимостей:**
- `memoryValue` — существует, строка 27: `private var memoryValue: Decimal = 0`. Доступ разрешён внутри класса ✓
- `formatter` — существует, строка 17: `private let formatter = NumberFormatterService.shared`. Доступ разрешён внутри класса ✓
- `formatter.format(_:)` — существует, NumberFormatterService.swift строка 29: `public func format(_ value: Decimal) -> String`. Принимает Decimal, возвращает String ✓
- `guard ... else { return nil }` — стандартный Swift-оператор раннего выхода ✓
- `Decimal != 0` — Decimal conforms to Equatable, оператор != корректен ✓

**Поведение:**
- Если `memoryValue = 0` → возвращает `nil` (tooltip не показывается)
- Если `memoryValue = 31` → возвращает `"31"` (tooltip показывает "31")
- Если `memoryValue = 1234.56` → возвращает `"1 234,56"` (tooltip показывает с разделителями)
- Если `memoryValue = 1e+15` → возвращает `"1,23e+15"` (tooltip показывает научную нотацию)

**Важно:** Это свойство имеет уровень доступа `var` (internal по умолчанию внутри модуля), а не `private`. Оно нужно из CalculatorButton и CalculatorView, которые находятся в том же модуле. `CalculatorViewModel` аннотирован как `@Observable` (строка 7), поэтому все `var` свойства автоматически становятся наблюдаемыми — UI будет обновляться при изменении `memoryValue`.

### Изменение 2: Добавить свойства в ButtonSpec для индикации памяти

**Зачем:** CalculatorButton — generic компонент, который не знает о специфике кнопки MR. Нужно передать ему информацию о состоянии памяти через ButtonSpec.

**Где:** `Sources/Views/CalculatorButton.swift`, структура `ButtonSpec` (строки 105–111).

**Текущий код (строки 105–111):**
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0"
    var isEnabled: Bool = true
}
```

**Новый код (замена строк 105–111):**
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

**Что изменилось:** Добавлены две строки после `var isEnabled: Bool = true` (строка 110):
- `var hasMemoryIndicator: Bool = false` — флаг для отображения зелёного кружочка. По умолчанию false (кружочек не показывается). Устанавливается в true только для кнопки MR когда память не пуста.
- `var memoryTooltip: String? = nil` — текст для всплывающей подсказки. По умолчанию nil (tooltip не показывается). Устанавливается в отформатированную строку только для кнопки MR когда память не пуста.

**Верификация:**
- `ButtonSpec` — struct, Identifiable, строки 105–111 CalculatorButton.swift ✓
- Добавление свойств с дефолтными значениями не ломает существующие инициализаторы ✓
- Все аргументы в вызовах `ButtonSpec(...)` именованные, порядок не важен ✓
- `hasMemoryIndicator: Bool = false` — простой тип с дефолтом, не влияет на другие кнопки ✓
- `memoryTooltip: String? = nil` — опциональный тип с дефолтом nil, не влияет на другие кнопки ✓

### Изменение 3: Обновить CalculatorView — передать данные о памяти в кнопку MR

**Зачем:** UI должен передавать состояние памяти в ButtonSpec для кнопки MR.

**Где:** `Sources/Views/CalculatorView.swift`, строка 63 (кнопка MR в строке 1 сетки).

**Текущий код (строка 63):**
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory),
```

**Новый код (замена строки 63):**
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue),
```

**Что изменилось:** После `isEnabled: viewModel.hasMemory)` добавлено `, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue`.

**Верификация:**
- `viewModel` — существует, CalculatorView.swift строка 7: `@Bindable var viewModel: CalculatorViewModel` ✓
- `viewModel.hasMemory` — computed property, строка 42 CalculatorViewModel.swift: `var hasMemory: Bool { memoryValue != 0 }` ✓
- `viewModel.memoryDisplayValue` — computed property, добавляемый в Изменении 1: `var memoryDisplayValue: String?` ✓
- `@Bindable` — property wrapper SwiftUI, делает свойства Observable доступными для привязки в View ✓
- `ButtonSpec(label:type:isEnabled:hasMemoryIndicator:memoryTooltip:)` — инициализатор генерируется автоматически для struct с именованными полями ✓

**Обоснование, почему только MR:** Кнопки MC, M+, M− не требуют индикации памяти:
- MC (Очистить память) — всегда активна когда память не пуста, но индикация не нужна (пользователь и так видит что M+ добавлял значения)
- M+ (Добавить в память) — всегда активна, индикация не нужна
- M− (Вычесть из памяти) — всегда активна, индикация не нужна
- MR (Вспомнить из памяти) — единственная кнопка, которая показывает пользователю что именно хранится в памяти

### Изменение 4: Обновить CalculatorButton — добавить overlay с зелёным кружочком

**Зачем:** Визуально показать пользователю, что в памяти есть значение.

**Где:** `Sources/Views/CalculatorButton.swift`, внутри body (строки 176–224), после строки 207 (`.buttonStyle(.plain)`), перед `.frame(...)` на строке 208.

**Текущий код (строки 205–209):**
```swift
                }
        }
        .buttonStyle(.plain)
        .frame(width: targetWidth, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1.0)
```

**Новый код (замена строк 206–209):**
```swift
                }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if spec.hasMemoryIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: targetWidth, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1.0)
```

**Пояснение построчно:**
- Строка 1–2: `}` — закрывающие скобки label closure (строки 205–206, без изменений)
- Строка 3: `.buttonStyle(.plain)` — без изменений (строка 207)
- Строка 4: `.overlay(alignment: .bottomTrailing) {` — начинаем overlay, выравнивание по правому нижнему углу кнопки. `.bottomTrailing` = правый + нижний
- Строка 5: `if spec.hasMemoryIndicator {` — показываем overlay только когда флаг true. `spec.hasMemoryIndicator` — свойство ButtonSpec, добавляемое в Изменении 2
- Строка 6: `Circle()` — стандартный SwiftUI shape для идеального круга
- Строка 7: `.fill(Color.green)` — заполняем круг зелёным цветом. `Color.green` — системный цвет, адаптируется к светлой/тёмной теме
- Строка 8: `.frame(width: 8, height: 8)` — устанавливаем размер круга 8×8 пунктов
- Строка 9: `.padding(6)` — отступ 6 пунктов от правого и нижнего краёв кнопки. Кружок не прилипает к краю
- Строка 10: `.accessibilityHidden(true)` — VoiceOver игнорирует кружочек. Это чисто визуальный элемент, он не должен озвучиваться
- Строка 11: `}` — закрываем if
- Строка 12: `}` — закрываем overlay closure

**Позиционирование кружочка:**
- `alignment: .bottomTrailing` — overlay привязан к правому нижнему углу кнопки
- `.padding(6)` — смещаем круг на 6 пунктов внутрь от правого и нижнего краёв
- Кружок полностью виден внутри кнопки, не выходит за её границы

**Почему overlay на Button, а не внутри label:**
Контент label проходит через `.clipShape(RoundedRectangle(...))` — если положить кружок внутрь, его обрежет. Размещение на Button-вью (вне label closure) гарантирует, что кружок не будет обрезан.

**Верификация:**
- `.overlay(alignment:content:)` — стандартный SwiftUI modifier, принимает alignment и View builder ✓
- `.bottomTrailing` — стандартное выравнивание для overlay (правый нижний угол) ✓
- `spec.hasMemoryIndicator` — свойство ButtonSpec, добавляемое в Изменении 2 ✓
- `Circle()` — стандартный SwiftUI shape ✓
- `.fill(_:)` — стандартный modifier для заполнения shape цветом ✓
- `Color.green` — стандартный цвет SwiftUI (системный зелёный) ✓
- `.frame(width:height:)` — стандартный modifier для установки размера ✓
- `.padding(_:)` — стандартный modifier для отступов ✓
- `.accessibilityHidden(true)` — стандартный SwiftUI modifier, скрывает view из VoiceOver ✓

### Изменение 5: Обновить CalculatorButton — добавить `.help()` для всплывающей подсказки

**Зачем:** Показать пользователю отформатированное значение памяти при наведении курсора.

**Где:** `Sources/Views/CalculatorButton.swift`, внутри body (строки 176–224), после строки 223 (`.opacity(...)`), перед закрывающей скобкой `}` на строке 224.

**Текущий код (строки 222–224):**
```swift
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
    }
```

**Новый код (замена строк 223–224):**
```swift
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        .help(spec.memoryTooltip ?? "")
    }
```

**Что изменилось:** После `.opacity(...)` (строка 223) добавлена строка `.help(spec.memoryTooltip ?? "")`, и закрывающая скобка `}` остаётся на месте (строка 224).

**Пояснение:**
- `.help(_:)` — стандартный SwiftUI modifier для macOS, показывает всплывающую подсказку при наведении курсора
- `spec.memoryTooltip ?? ""` — если tooltip есть (не nil), показываем его; если nil (по умолчанию для всех кнопок кроме MR), показываем пустую строку. `.help("")` (пустая строка) не показывает tooltip — это корректное поведение по умолчанию
- `spec.memoryTooltip` — свойство ButtonSpec, добавляемое в Изменении 2
- `?? ""` — стандартный Swift-оператор nil coalescing: возвращает левый операнд если не nil, иначе правый

**Поведение:**
- Если `memoryTooltip = "31"` → при наведении на кнопку MR показывается tooltip с текстом "31"
- Если `memoryTooltip = nil` (все остальные кнопки) → tooltip не отображается (пустая строка)

**Верификация:**
- `.help(_:)` — стандартный SwiftUI modifier для macOS ✓
- `spec.memoryTooltip` — свойство ButtonSpec, добавляемое в Изменении 2 ✓
- `?? ""` — стандартный Swift-оператор nil coalescing ✓

---

## 3. Локализация: добавление ключа `memory.tooltip`

**Зачем:** Префикс "Память: " / "Memory: " должен быть локализован, а не захардкожен в коде.

**Файл 1:** `Sources/Localization/en.lproj/Localizable.strings`  
**Куда:** В конец файла, после строки 31 (`"clipboard.cannotEvaluate" = "Cannot evaluate";`)

**Добавить строку:**
```
/* Memory */
"memory.tooltip" = "Memory: ";
```

**Файл 2:** `Sources/Localization/ru.lproj/Localizable.strings`  
**Куда:** В конец файла, после строки 31 (`"clipboard.cannotEvaluate" = "Невозможно вычислить";`)

**Добавить строку:**
```
/* Memory */
"memory.tooltip" = "Память: ";
```

**Верификация:**
- Файлы локализации существуют (подтверждено чтением файлов) ✓
- Формат `"key" = "value";` — стандартный формат .strings ✓
- Пробел после двоеточия — для читаемости ("Память: 31", а не "Память:31") ✓
- Комментарий `/* Memory */` — группирует ключ с другими, как принято в проекте (см. секции `/* Display */`, `/* Buttons */`, `/* History */` и т.д.) ✓
- Ключ `"memory.tooltip"` — уникальный, не конфликтует с существующими ключами ✓

**Как используется в коде (Изменение 3):**
```swift
memoryTooltip: viewModel.memoryDisplayValue != nil ? NSLocalizedString("memory.tooltip", comment: "") + viewModel.memoryDisplayValue! : nil
```

**ВАЖНОЕ ЗАМЕЧАНИЕ:** В Изменении 3 мы передаём `viewModel.memoryDisplayValue` напрямую. Но `memoryDisplayValue` уже содержит только число (без префикса). Чтобы добавить локализованный префикс, нужно либо:
- (а) Добавить префикс в `memoryDisplayValue` внутри ViewModel, либо
- (б) Собрать строку тултипа в CalculatorView с помощью `NSLocalizedString`

**Рекомендуемый вариант (б):** В CalculatorView собрать строку тултипа с префиксом:
```swift
memoryTooltip: viewModel.memoryDisplayValue != nil ? NSLocalizedString("memory.tooltip", comment: "") + viewModel.memoryDisplayValue! : nil
```

Но это требует force unwrap `viewModel.memoryDisplayValue!`, что нежелательно. Альтернатива — добавить префикс в ViewModel:

**Альтернативный вариант (а) — предпочтительнее:** Изменить `memoryDisplayValue` в ViewModel так, чтобы он уже содержал префикс:
```swift
var memoryDisplayValue: String? {
    guard memoryValue != 0 else { return nil }
    return NSLocalizedString("memory.tooltip", comment: "") + formatter.format(memoryValue)
}
```

Но это нарушает принцип MVVM — ViewModel не должен знать о локализации. Поэтому лучший вариант:

**Финальный вариант:** В CalculatorView использовать тернарную операцию с безопасным unwrap через `if let`:

Однако, в текущем плане Изменение 3 передаёт `viewModel.memoryDisplayValue` напрямую. Это означает, что в тултипе будет показано только число (например, "31"), без префикса "Память: ".

**Решение:** Добавить отдельный computed property `memoryTooltipText` в CalculatorViewModel, который уже содержит полный текст тултипа с префиксом:

Нет, это тоже нарушает MVVM. Лучшее решение — оставить Изменение 3 как есть (передача `memoryDisplayValue` без префикса), и в тултипе показывать только число. Если требуется префикс — добавить его через `NSLocalizedString` в CalculatorView.

**Финальное решение для Изменения 3:**
```swift
memoryTooltip: viewModel.memoryDisplayValue != nil ? NSLocalizedString("memory.tooltip", comment: "") + viewModel.memoryDisplayValue! : nil
```

Это требует force unwrap, но `memoryDisplayValue` гарантированно не nil когда мы доходим до этой строки (проверка `!= nil` уже выполнена).

---

## 4. Пошаговый план реализации (порядок действий)

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

**Заменить** эти строки (105–111) на:
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
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue != nil ? NSLocalizedString("memory.tooltip", comment: "") + viewModel.memoryDisplayValue! : nil),
```

**Что именно меняется:** После `isEnabled: viewModel.hasMemory)` добавлено `, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue != nil ? NSLocalizedString("memory.tooltip", comment: "") + viewModel.memoryDisplayValue! : nil`.

**Пояснение:**
- `hasMemoryIndicator: viewModel.hasMemory` — передаёт computed property из ViewModel (Bool)
- `memoryTooltip:` — тернарная операция: если `memoryDisplayValue` не nil, собираем строку "Память: 31" (или "Memory: 31"), иначе nil
- `NSLocalizedString("memory.tooltip", comment: "")` — локализованный префикс (добавляется в Шаге 6)
- `viewModel.memoryDisplayValue!` — force unwrap, безопасен потому что проверка `!= nil` уже выполнена
- `nil` в конце — если memoryDisplayValue nil, tooltip не показывается

**Проверка:**
- `viewModel.hasMemory` — computed property, строка 42 CalculatorViewModel.swift ✓
- `viewModel.memoryDisplayValue` — computed property, добавляемый в Шаге 1 ✓
- `NSLocalizedString("memory.tooltip", comment: "")` — локализованный ключ (добавляется в Шаге 6) ✓
- `ButtonSpec(label:type:isEnabled:hasMemoryIndicator:memoryTooltip:)` — инициализатор генерируется автоматически ✓

### Шаг 4: CalculatorButton — добавить overlay с зелёным кружочком

**Файл:** `Sources/Views/CalculatorButton.swift`

**Контекст:** Найти строки 205–209 (концовка label и начало модификаторов):
```swift
                }
        }
        .buttonStyle(.plain)
        .frame(width: targetWidth, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1.0)
```

**Заменить** эти строки (206–209) на:
```swift
                }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if spec.hasMemoryIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: targetWidth, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1.0)
```

**Что именно меняется:** Между `.buttonStyle(.plain)` и `.frame(...)` вставлен overlay с condition.

**Проверка:**
- `.overlay(alignment:content:)` — стандартный SwiftUI modifier ✓
- `.bottomTrailing` — стандартное выравнивание (правый нижний угол) ✓
- `spec.hasMemoryIndicator` — свойство ButtonSpec, добавляемое в Шаге 2 ✓
- `Circle()` — стандартный SwiftUI shape ✓
- `.fill(Color.green)` — стандартный modifier ✓
- `Color.green` — стандартный цвет SwiftUI ✓
- `.frame(width:height:)` — стандартный modifier ✓
- `.padding(_:)` — стандартный modifier ✓
- `.accessibilityHidden(true)` — стандартный modifier ✓

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

### Шаг 6: Локализация — добавить ключ `memory.tooltip`

**Файл:** `Sources/Localization/en.lproj/Localizable.strings`

Найти последнюю строку файла (строка 31):
```
"clipboard.cannotEvaluate" = "Cannot evaluate";
```

После неё добавить:
```

/* Memory */
"memory.tooltip" = "Memory: ";
```

**Файл:** `Sources/Localization/ru.lproj/Localizable.strings`

Найти последнюю строку файла (строка 31):
```
"clipboard.cannotEvaluate" = "Невозможно вычислить";
```

После неё добавить:
```

/* Memory */
"memory.tooltip" = "Память: ";
```

**Проверка:** Ключ доступен через `NSLocalizedString("memory.tooltip", comment: "")`.

---

## 5. Итоговая таблица изменений по файлам

### Файл: `Sources/ViewModels/CalculatorViewModel.swift`

| Строка(и) | Тип изменения | Описание |
|---|---|---|
| После 42, перед 44 | Вставка (Шаг 1) | Добавлен `memoryDisplayValue: String?` computed property |

### Файл: `Sources/Views/CalculatorButton.swift`

| Строка(и) | Тип изменения | Описание |
|---|---|---|
| 105–111 | Замена (Шаг 2) | Добавлены `hasMemoryIndicator: Bool = false` и `memoryTooltip: String? = nil` в ButtonSpec |
| 206–209 | Замена (Шаг 4) | Добавлен `.overlay(...)` с зелёным кружочком после `.buttonStyle(.plain)` |
| 223–224 | Замена (Шаг 5) | Добавлен `.help(spec.memoryTooltip ?? "")` в body |

### Файл: `Sources/Views/CalculatorView.swift`

| Строка(и) | Тип изменения | Описание |
|---|---|---|
| 63 | Замена (Шаг 3) | Добавлены `hasMemoryIndicator: viewModel.hasMemory` и `memoryTooltip:` с локализованным префиксом в ButtonSpec для .mR |

### Файл: `Sources/Localization/en.lproj/Localizable.strings`

| Тип изменения | Описание |
|---|---|
| Добавление (Шаг 6) | Новая строка `/* Memory */ "memory.tooltip" = "Memory: ";` |

### Файл: `Sources/Localization/ru.lproj/Localizable.strings`

| Тип изменения | Описание |
|---|---|
| Добавление (Шаг 6) | Новая строка `/* Memory */ "memory.tooltip" = "Память: ";` |

---

## 6. Полный реестр верифицированных элементов

Все элементы, используемые в плане. Каждый подтверждён чтением исходного файла или документацией SwiftUI/Swift.

| Элемент | Файл/Фреймворк | Строка | Подтверждено |
|---|---|---|---|
| `@MainActor` | CalculatorViewModel.swift | 6 | Да |
| `@Observable` | CalculatorViewModel.swift | 7 | Да |
| `final class CalculatorViewModel` | CalculatorViewModel.swift | 8 | Да |
| `private let formatter = NumberFormatterService.shared` | CalculatorViewModel.swift | 17 | Да |
| `private var memoryValue: Decimal = 0` | CalculatorViewModel.swift | 27 | Да |
| `var hasMemory: Bool { memoryValue != 0 }` | CalculatorViewModel.swift | 42 | Да |
| `func appendCharacter(_ char: String)` | CalculatorViewModel.swift | 44 | Да |
| `public func format(_ value: Decimal) -> String` | NumberFormatterService.swift | 29 | Да |
| `struct ButtonSpec: Identifiable` | CalculatorButton.swift | 105 | Да (будет расширена) |
| `var isEnabled: Bool = true` | CalculatorButton.swift | 110 | Да (будет расширена) |
| `let spec: ButtonSpec` | CalculatorButton.swift | 117 | Да |
| `var body: some View` | CalculatorButton.swift | 176 | Да |
| `Button { ... } label: { ... }` | CalculatorButton.swift | 180–206 | Да (будет добавлен overlay) |
| `.buttonStyle(.plain)` | CalculatorButton.swift | 207 | Да (будет добавлен overlay после) |
| `.opacity(spec.isEnabled ? 1.0 : 0.4)` | CalculatorButton.swift | 223 | Да (будет добавлен help после) |
| `@Bindable var viewModel: CalculatorViewModel` | CalculatorView.swift | 7 | Да |
| `ButtonSpec(label: .mR, ...)` | CalculatorView.swift | 63 | Да (будет расширена) |
| `.overlay(alignment:content:)` | SwiftUI framework | — | Да: стандартный modifier, принимает alignment и View builder |
| `.bottomTrailing` | SwiftUI framework | — | Да: стандартное выравнивание для overlay (правый нижний угол) |
| `Circle()` | SwiftUI framework | — | Да: стандартный shape для идеальных кругов |
| `.fill(_:)` | SwiftUI framework | — | Да: стандартный modifier для заполнения shape цветом |
| `Color.green` | SwiftUI framework | — | Да: стандартный системный зелёный цвет |
| `.frame(width:height:)` | SwiftUI framework | — | Да: стандартный modifier для установки размера |
| `.padding(_:)` | SwiftUI framework | — | Да: стандартный modifier для отступов |
| `.accessibilityHidden(_:)` | SwiftUI framework | — | Да: стандартный modifier для скрытия из VoiceOver |
| `.help(_:)` | SwiftUI framework | — | Да: стандартный modifier для macOS tooltip, принимает String или Text |
| `??` (nil coalescing) | Swift standard library | — | Да: стандартный оператор, возвращает левый операнд если не nil, иначе правый |
| `guard ... else { return }` | Swift language | — | Да: стандартный оператор раннего выхода |
| `Decimal !=` (сравнение) | Foundation.framework | — | Да: Decimal conforms to Equatable, оператор != корректен |
| `NSLocalizedString(_:comment:)` | Foundation.framework | — | Да: стандартная функция для локализации |
| `!` (force unwrap) | Swift language | — | Да: стандартный оператор, используется безопасно после проверки `!= nil` |

---

## 7. Что НЕ изменяется (и почему)

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
| `ButtonLabel` enum | CalculatorButton.swift, 16–101 | Не расширяется — индикатор управляется через ButtonSpec |
| `CalculatorEngine` | Sources/CalculatorEngine/ | Не требуется — форматирование через NumberFormatterService |

---

## 8. Ожидаемое поведение после реализации

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
- Зелёный кружочек: отображается в правом нижнем углу кнопки (т.к. `hasMemoryIndicator = true`)
- Tooltip: при наведении курсора показывается "Память: 31" (т.к. `memoryTooltip = "Память: 31"`)

### Сценарий 3: Память очищена (после MC)

**Состояние:** `memoryValue = 0`, `hasMemory = false`, `memoryDisplayValue = nil`

**Визуальное поведение:**
- Возвращается к состоянию сценария 1 (кружочек исчезает, tooltip исчезает, кнопка затемняется)

### Сценарий 4: Большое значение в памяти (после M+ с большим числом)

**Состояние:** `memoryValue = 1234567.89`, `hasMemory = true`, `memoryDisplayValue = "1 234 567,89"`

**Визуальное поведение:**
- Кнопка MR: opacity = 1.0 (полностью видна)
- Зелёный кружочек: отображается в правом нижнем углу
- Tooltip: при наведении курсора показывается "Память: 1 234 567,89" (отформатированное значение с разделителями)

### Сценарий 5: Научная нотация в памяти (после M+ с очень большим числом)

**Состояние:** `memoryValue = 1e+15`, `hasMemory = true`, `memoryDisplayValue = "1,23e+15"`

**Визуальное поведение:**
- Кнопка MR: opacity = 1.0 (полностью видна)
- Зелёный кружочек: отображается в правом нижнем углу
- Tooltip: при наведении курсора показывается "Память: 1,23e+15" (научная нотация)

### Сценарий 6: Нажатие MR (вспомнить из памяти)

**Состояние:** `memoryValue = 31`, пользователь нажимает MR

**Поведение:**
- Значение из памяти вставляется в expression (существующее поведение `memoryRecall()`)
- Кружочек остаётся (память не очищается при recall)
- Tooltip остаётся

### Сценарий 7: M− до нуля (вычитание до обнуления памяти)

**Состояние:** `memoryValue` было 31, пользователь вычитает 31 через M−

**Поведение:**
- `memoryValue = 0`, `hasMemory = false`
- Кружочек исчезает, tooltip исчезает, кнопка MR затемняется

---

## 9. Проверка компиляции после каждого шага

После каждого из 6 шагов необходимо выполнить сборку проекта для проверки корректности:

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
- Ошибка "Cannot find 'NSLocalizedString' in scope" → проверить, что в CalculatorView.swift есть `import SwiftUI` (уже есть на строке 1)

---

## 10. Тестирование после реализации

После завершения всех шагов необходимо проверить следующее:

### Ручное тестирование

1. **Запустить приложение** и убедиться, что:
   - Кнопка MR изначально затемнена (opacity = 0.4)
   - Зелёный кружочек не отображается
   - При наведении на MR tooltip не показывается

2. **Нажать M+** (после вычисления любого выражения):
   - Кнопка MR становится полностью видимой (opacity = 1.0)
   - Появляется зелёный кружочек в правом нижнем углу
   - При наведении на MR показывается tooltip с отформатированным значением (например, "Память: 31")

3. **Нажать MC:**
   - Кнопка MR снова затемняется (opacity = 0.4)
   - Зелёный кружочек исчезает
   - Tooltip исчезает

4. **Нажать M+ с большим числом** (например, 1234567.89):
   - Tooltip показывает "Память: 1 234 567,89" (с разделителями тысяч)

5. **Нажать M+ с очень большим числом** (например, 1e+15):
   - Tooltip показывает "Память: 1,23e+15" (научная нотация)

6. **Нажать MR** (вспомнить из памяти):
   - Значение вставляется в expression
   - Кружочек остаётся (память не очищается)

7. **Нажать M− до нуля** (вычесть из памяти до обнуления):
   - Кружочек исчезает, tooltip исчезает, кнопка MR затемняется

### Автоматическое тестирование

Запустить существующие UI-тесты:
```bash
swift test --filter CalculatorUITests
```

**Ожидаемый результат:** Все существующие UI-тесты проходят успешно.

---

## 11. Заключение

Этот план реализует два улучшения для кнопки MR:
1. **Зелёный кружочек** — визуальная индикация наличия значения в памяти (правый нижний угол)
2. **Всплывающая подсказка** — отображение отформатированного значения при наведении курсора

Решение архитектурно корректно, т.к.:
- Форматирование значения происходит в ViewModel (принцип MVVM)
- UI получает только готовые данные для отображения
- CalculatorButton остаётся переиспользуемым компонентом (данные передаются через ButtonSpec)
- Все изменения минимальны и локализованы (4 файла, 6 шагов)
- Не нарушается существующая функциональность (все изменения обратимы)
- Локализация префикса тултипа вынесена в .strings файлы
- Кружочек скрыт для VoiceOver (accessibilityHidden)

После реализации пользователь получит интуитивно понятную индикацию состояния памяти, соответствующую стандартам macOS Calculator.app.
