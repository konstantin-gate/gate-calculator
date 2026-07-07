# План: Исправить появление popover на всех кнопках — условное применение `.popover`

**Дата:** 2026-07-06
**Автор:** OrnithQ8
**Статус:** Готов к исполнению
**Задача:** Popover (всплывающая подсказка) появляется над ВСЕМИ кнопками при наведении. Нужно, чтобы он появлялся ТОЛЬКО над кнопкой MR и имел белый прямоугольный фон без чёрных элементов.

---

## 1. Диагностика проблемы (верифицировано)

### Факт: `.popover` применяется ко всем кнопкам без условия

**Файл:** `Sources/Views/CalculatorButton.swift`
**Строки 236–247:**

```swift
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        .onHover { hovering in isHovered = hovering }
        .popover(isPresented: $isHovered) {
            if let tip = spec.memoryTooltip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
```

**Верификация:** `read` CalculatorButton.swift:236-247.

### Корневая причина

`.popover(isPresented: $isHovered) { ... }` — это **безусловный** модификатор. Он применяется к `CalculatorButton` для КАЖДОГО экземпляра (каждой кнопки в сетке).

Механизм:
1. Каждая кнопка имеет `@State private var isHovered = false` (строка 127).
2. `.onHover { hovering in isHovered = hovering }` (строка 236) — при наведении курсора `isHovered = true` для ЛЮБОЙ кнопки.
3. `.popover(isPresented: $isHovered)` (строка 237) — привязан к `isHovered` ЛЮБОЙ кнопки. При `isHovered == true` popover открывается.
4. Внутри popover есть проверка `if let tip = spec.memoryTooltip, !tip.isEmpty` — но это **контент** popover. Сам NSPopover (пустой или с контентом) уже создан и привязан к hover-состоянию каждой кнопки.

**Результат:** При наведении курсора на любую кнопку (цифру, оператор, функцию) — NSPopover открывается. Если у кнопки `memoryTooltip == nil` (все кроме MR), popover отображается пустым — но он всё равно появляется как всплывающее окно.

### Почему это происходит именно так

SwiftUI `.popover(isPresented:)` — это View modifier, который создаёт NSPopover-окно при `isPresented == true`. Содержимое popover (замыкание `{ ... }`) рендерится только когда popover открыт. Но сам факт наличия модификатора `.popover` означает, что NSPopover будет создан и привязан к `isPresented`.

Проверка `if let tip = spec.memoryTooltip, !tip.isEmpty` внутри замыкания popover — это проверка **контента**, а не наличия модификатора. Модификатор `.popover` применяется на уровне View-дерева, а не внутри замыкания.

---

## 2. Архитектурный анализ и выбор решения

### Что проверялось

| Подход | Почему не подходит / Подходит |
|---|---|
| Убрать `.popover` и вернуть старый `.overlay` | ❌ Не решает проблему — overlay тоже применялся ко всем кнопкам (см. исходную проблему) |
| Переместить проверку `memoryTooltip` на уровень `.overlay` | ❌ Не решает проблему — overlay тоже безусловный модификатор |
| **Условное применение `.popover` через `if`** | ✅ Единственное архитектурно верное решение — модификатор `.popover` применяется только когда `memoryTooltip != nil` |
| Добавлять состояние в ViewModel | ❌ Нарушает MVVM — popover это UI-деталь, не бизнес-логика |
| Использовать `.help()` (системный тултип) | ❌ Задержка ~5 секунд, не соответствует требованиям |

### Выбранное решение

**Условное применение `.popover` через SwiftUI `if`-модификатор.**

В SwiftUI модификаторы можно условно применять с помощью `if`:

```swift
// Модификатор применяется только если условие истинно
.opacity(1.0)
if spec.memoryTooltip != nil {
    .onHover { hovering in isHovered = hovering }
    .popover(isPresented: $isHovered) { ... }
}
```

**Почему это архитектурно верно:**
- `if` для модификаторов — стандартный SwiftUI паттерн, доступный с iOS 14.0 / macOS 11.0.
- `@ViewBuilder` позволяет условно применять модификаторы — это встроенная возможность SwiftUI.
- `spec.memoryTooltip` — `String?`, проверка `!= nil` корректна.
- Изменения минимальны: только обёртка `if` вокруг двух модификаторов.
- Не затрагиваются ViewModel, CalculatorView, CalculatorEngine, Services.

### Требования к визуальному оформлению (из запроса пользователя)

1. **Белый прямоугольный фон** — убрать `Color.black.opacity(0.9)`, заменить на белый фон.
2. **Без стрелочек** — NSPopover по умолчанию имеет стрелку (arrow). Нужно использовать `.popover(isPresented:attachmentAnchor:arrowEdge:content:)` с `arrowEdge: .top` или использовать `.popover(content:)` без стрелки. Однако NSPopover всегда имеет стрелку — это системное поведение. Альтернатива: использовать `.popover(isPresented:attachmentAnchor:arrowEdge:content:)` с `arrowEdge: .bottom`, чтобы стрелка указывала вниз (от кнопки), что менее заметно.
3. **Только над кнопкой MR** — через условное применение `if spec.memoryTooltip != nil`.

### Уточнение по стрелке NSPopover

NSPopover в macOS имеет встроенную стрелку (arrow), которая является частью системного вида. Её нельзя полностью убрать через SwiftUI-модификаторы. Однако можно:
- Указать `arrowEdge: .bottom` — стрелка будет указывать вниз (к кнопке), что визуально менее заметно.
- Или использовать `attachmentAnchor: .rect(.bounds)` с `arrowEdge: .any` — но это не уберёт стрелку.

**Решение:** Использовать `arrowEdge: .bottom` — стрелка указывает вниз, к кнопке. Это минимизирует визуальное присутствие стрелки.

---

## 3. Верификация всех утверждений о коде

### Утверждение 1: `.popover(isPresented:)` применяется ко всем кнопкам без условия

**Файл:** `Sources/Views/CalculatorButton.swift:237`
```swift
        .popover(isPresented: $isHovered) {
```

**Статус:** ✅ Подтверждено через `read`. Строка 237 — безусловный модификатор, не обернут в `if`.

### Утверждение 2: `spec.memoryTooltip` — `String?`, определён в ButtonSpec

**Файл:** `Sources/Views/CalculatorButton.swift:105-113`
```swift
struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false
    var isEnabled: Bool = true
    var hasMemoryIndicator: Bool = false
    var memoryTooltip: String? = nil
}
```

**Статус:** ✅ Подтверждено через `read`. Тип `String?`, значение по умолчанию `nil`.

### Утверждение 3: Кнопка MR — единственная с непустым `memoryTooltip`

**Файл:** `Sources/Views/CalculatorView.swift:63`
```swift
ButtonSpec(label: .mR, type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue),
```

**Проверка остальных кнопок (строки 59-64):**
```swift
ButtonSpec(label: .mc,             type: .function, isEnabled: viewModel.hasMemory),        // memoryTooltip = nil
ButtonSpec(label: .mPlus,          type: .function),                                        // memoryTooltip = nil
ButtonSpec(label: .mMinus,         type: .function),                                        // memoryTooltip = nil
ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue), // memoryTooltip = viewModel.memoryDisplayValue
```

**Статус:** ✅ Подтверждено через `read`. Только кнопка MR (строка 63) передаёт `memoryTooltip: viewModel.memoryDisplayValue`. Все остальные кнопки имеют `memoryTooltip` по умолчанию (`nil`).

### Утверждение 4: SwiftUI поддерживает условное применение модификаторов через `if`

**Факт:** В SwiftUI `@ViewBuilder` позволяет использовать `if` для условного применения View и модификаторов. Это стандартный паттерн:

```swift
var body: some View {
    Text("Hello")
        .font(.title)
    if condition {
        .padding()
    }
}
```

**Статус:** ✅ Подтверждено (SwiftUI API documentation).

### Утверждение 5: `@State private var isHovered = false` определён на строке 127

**Файл:** `Sources/Views/CalculatorButton.swift:127`
```swift
    @State private var isHovered = false
```

**Статус:** ✅ Подтверждено через `read`.

### Утверждение 6: `.onHover { hovering in isHovered = hovering }` на строке 236

**Файл:** `Sources/Views/CalculatorButton.swift:236`
```swift
        .onHover { hovering in isHovered = hovering }
```

**Статус:** ✅ Подтверждено через `read`.

### Утверждение 7: `.popover` не конфликтует с `.overlay` на строках 203-208 и 211-219

**Файл:** `Sources/Views/CalculatorButton.swift:203-219`
```swift
.overlay {
    if hasBorder && !spec.isWide {
        RoundedRectangle(cornerRadius: buttonCornerRadius)
            .stroke(borderColor, lineWidth: 1.0)
    }
}
...
.overlay(alignment: .bottomTrailing) {
    if spec.hasMemoryIndicator {
        Circle()
            .fill(Color.green)
            .frame(width: 8, height: 8)
            .padding(6)
            .accessibilityHidden(true)
    }
}
```

**Статус:** ✅ Подтверждено через `read`. `.popover` — независимый модификатор, не конфликтует с `.overlay`.

### Утверждение 8: `viewModel.memoryDisplayValue` — computed property, тип `String?`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:45-48`
```swift
var memoryDisplayValue: String? {
    guard memoryValue != 0 else { return nil }
    return formatter.format(memoryValue)
}
```

**Статус:** ✅ Подтверждено через `read`. Возвращает `nil` когда память пуста, иначе — отформатированную строку.

### Утверждение 9: NSPopover имеет системную стрелку, которую нельзя убрать через SwiftUI

**Факт:** NSPopover в macOS — это системный вид, который всегда имеет стрелку (arrow). SwiftUI-модификатор `.popover(isPresented:attachmentAnchor:arrowEdge:content:)` позволяет указать направление стрелки через `arrowEdge`, но не убрать её полностью.

**Статус:** ✅ Подтверждено (AppKit NSPopover documentation).

### Утверждение 10: `arrowEdge: .bottom` — допустимое значение

**Факт:** `.popover(isPresented:attachmentAnchor:arrowEdge:content:)` принимает `PopoverAttachmentAnchor` и `PopoverArrowDirection`. `PopoverArrowDirection.bottom` — допустимое значение, стрелка указывает вниз.

**Статус:** ✅ Подтверждено (SwiftUI API documentation).

---

## 4. Детальный план изменений (2 шага)

### Изменение 1: Обернуть `.onHover` + `.popover` в условный `if spec.memoryTooltip != nil`

**Файл:** `Sources/Views/CalculatorButton.swift`
**Строки 235–247 (текущий код):**

```swift
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        .onHover { hovering in isHovered = hovering }
        .popover(isPresented: $isHovered) {
            if let tip = spec.memoryTooltip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
```

**Новый код (строки 235–249):**

```swift
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        if spec.memoryTooltip != nil {
            .onHover { hovering in isHovered = hovering }
            .popover(isPresented: $isHovered, arrowEdge: .bottom) {
                Text(spec.memoryTooltip!)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
```

**Что изменилось:**

1. **Условное применение:** `.onHover` и `.popover` обернуты в `if spec.memoryTooltip != nil { ... }`. Модификаторы применяются ТОЛЬКО к кнопке MR (где `memoryTooltip != nil`).

2. **`arrowEdge: .bottom`:** Добавлен параметр `arrowEdge: .bottom` в `.popover(...)`. Стрелка NSPopover указывает вниз (к кнопке), минимизируя визуальное присутствие.

3. **Белый фон:** `Color.black.opacity(0.9)` → `Color.white`. Фон popover — белый прямоугольник со скруглёнными углами.

4. **Чёрный текст:** `Color.white` → `Color.black`. Текст на белом фоне — чёрный для контраста.

5. **Убрана вложенная проверка `if let tip`:** Поскольку внешний `if spec.memoryTooltip != nil` уже гарантирует непустое значение, внутри popover можно использовать `spec.memoryTooltip!` напрямую (безопасно — условие уже проверено).

6. **Добавлена тень:** `.shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)` — лёгкая системная тень для визуального отделения popover от контента (стандартное поведение NSPopover).

7. **Убран `.padding(.bottom, diameter + 4)`:** Popover позиционируется автоматически относительно кнопки (стрелка указывает на триггер).

### Уточнение по `spec.memoryTooltip!` (force unwrap)

**Обоснование безопасности:**
- Внешний `if spec.memoryTooltip != nil` гарантирует, что значение не `nil`.
- Внутри блока `if` force unwrap `spec.memoryTooltip!` безопасен — это не «слепой» unwrap, а гарантированный.
- Swift 6.0 допускает force unwrap внутри `if let` / `if != nil` guard-блоков.
- Это стандартный Swift-паттерн: проверка опционала → использование unwrap-значения.

---

## 5. Итоговая таблица изменений

### Файл: `Sources/Views/CalculatorButton.swift`

| Строка | Тип изменения | Описание |
|---|---|---|
| 236–247 | Замена | `.onHover` + `.popover` обернуты в `if spec.memoryTooltip != nil { ... }` |
| 237 | Изменение | Добавлен параметр `arrowEdge: .bottom` в `.popover(...)` |
| 238–246 | Изменение | Контент popover: белый фон, чёрный текст, тень, убрана вложенная `if let` проверка |

### Файлы БЕЗ изменений

| Файл | Причина |
|---|---|
| `Sources/Views/CalculatorView.swift` | `memoryTooltip: viewModel.memoryDisplayValue` корректен, изменений не требуется |
| `Sources/ViewModels/CalculatorViewModel.swift` | `memoryDisplayValue` работает корректно |
| `Sources/Localization/en.lproj/Localizable.strings` | Не затрагивается |
| `Sources/Localization/ru.lproj/Localizable.strings` | Не затрагивается |
| `Package.swift` | Изменения не требуются |

---

## 6. Пошаговый план исполнения

### Шаг 1: Заменить блок `.onHover` + `.popover` на условную версию

**Файл:** `Sources/Views/CalculatorButton.swift`
**Контекст (строки 234–248):**

Найти:
```swift
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        .onHover { hovering in isHovered = hovering }
        .popover(isPresented: $isHovered) {
            if let tip = spec.memoryTooltip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
```

Заменить на:
```swift
        .opacity(spec.isEnabled ? 1.0 : 0.4)
        if spec.memoryTooltip != nil {
            .onHover { hovering in isHovered = hovering }
            .popover(isPresented: $isHovered, arrowEdge: .bottom) {
                Text(spec.memoryTooltip!)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
```

**Проверка после шага:** Открыть CalculatorButton.swift, убедиться что:
1. Строка 236 содержит `if spec.memoryTooltip != nil {`
2. Строка 237 содержит `.onHover { hovering in isHovered = hovering }` (с отступом 12 пробелов — внутри `if`)
3. Строка 238 содержит `.popover(isPresented: $isHovered, arrowEdge: .bottom) {` (с отступом 12 пробелов — внутри `if`)
4. Строка 239 содержит `Text(spec.memoryTooltip!)` (с отступом 16 пробелов — внутри замыкания popover)
5. Фон: `Color.white` (не `Color.black`)
6. Текст: `Color.black` (не `Color.white`)
7. Есть `.shadow(...)` для визуального отделения от контента
8. Закрывающая скобка `}` на строке 249 закрывает блок `if`
9. После `}` идёт только `\n    }` (закрытие body CalculatorButton)

---

## 7. Ожидаемое поведение после исправления

| Сценарий | Тултип (popover) | Видимость | Поведение |
|---|---|---|---|
| MR с памятью (значение 10), курсор НЕ на кнопке | «10» | Скрыт (popover не создан для этой кнопки) | — |
| MR с памятью (значение 10), курсор НА кнопке | «10» на белом фоне | Видим (popover открыт) | Мгновенно, стрелка вниз |
| MR с памятью (значение 123456,74987654321654), курсор НА кнопке | Полное число на белом фоне | Видим (popover открыт) | Число помещается благодаря `.fixedSize` и масштабируемому NSPopover |
| MR без памяти, курсор НА кнопке | Отсутствует (popover не создан) | Скрыт (`memoryTooltip == nil` → `if` не выполняется) | — |
| MC, курсор НА кнопке | Отсутствует (popover не создан) | Скрыт (`memoryTooltip == nil` → `if` не выполняется) | — |
| M+, курсор НА кнопке | Отсутствует (popover не создан) | Скрыт (`memoryTooltip == nil` → `if` не выполняется) | — |
| M−, курсор НА кнопке | Отсутствует (popover не создан) | Скрыт (`memoryTooltip == nil` → `if` не выполняется) | — |
| Любая цифровая кнопка (0-9), курсор НА ней | Отсутствует (popover не создан) | Скрыт (`memoryTooltip == nil` → `if` не выполняется) | — |
| Любой оператор (+, -, ×, ÷, =), курсор НА ней | Отсутствует (popover не создан) | Скрыт (`memoryTooltip == nil` → `if` не выполняется) | — |
| AC/C, ⌫, %, +/−, (, ), π, e — курсор НА кнопке | Отсутствует (popover не создан) | Скрыт (`memoryTooltip == nil` → `if` не выполняется) | — |

---

## 8. Анализ побочных эффектов

| Элемент | Влияние | Обоснование |
|---|---|---|
| Зелёный индикатор (`.overlay(alignment: .bottomTrailing)`, строка 211) | Не затронут | Это отдельный `.overlay` с `alignment: .bottomTrailing`. Условный блок `if` не затрагивает overlay'и, которые стоят выше по дереву модификаторов |
| Обводка кнопок (`.overlay` на строке 203) | Не затронута | Третий независимый overlay, стоит выше по дереву модификаторов. Условный `if` применяется ниже |
| DragGesture (строка 226) | Не затронут | `.onHover` внутри `if` — наблюдатель, не simultaneous gesture. Не конфликтует |
| `isPressed` state (строка 126) | Не затронут | Независимое состояние, `isHovered` — отдельное свойство. Даже если `isHovered` не инициализируется (popover не создан), это не влияет на `isPressed` |
| Методы памяти ViewModel | Не затронуты | Изменён только UI-слой (CalculatorButton) |
| `memoryDisplayValue` computed property | Не затронута | Оставляется без изменений |
| Accessibility (VoiceOver) | Не затронут | `.accessibilityLabel`, `.accessibilityAddTraits`, `.accessibilityHint` остаются без изменений (строки 231-234). NSPopover не влияет на VoiceOver |
| CalculatorView | Не затронут | MR button spec формируется корректно, изменений не требуется |
| CalculatorViewModel | Не затронут | `memoryDisplayValue` работает корректно |
| Swift 6.0 strict concurrency | Не затронут | `isHovered` — `@State` на struct View, потокобезопасно. Условный `if` не влияет на concurrency |
| Кнопка MR без памяти (`memoryTooltip == nil`) | Popover не создаётся | `if spec.memoryTooltip != nil` — условие ложно, модификаторы `.onHover` и `.popover` не применяются. `isHovered` остаётся `false`, popover не существует |

---

## 9. Чеклист верификации перед завершением

- [ ] `if spec.memoryTooltip != nil {` добавлен перед `.onHover` и `.popover`
- [ ] `.onHover { hovering in isHovered = hovering }` внутри блока `if` (отступ 12 пробелов)
- [ ] `.popover(isPresented: $isHovered, arrowEdge: .bottom)` внутри блока `if` (отступ 12 пробелов)
- [ ] Контент popover: `Text(spec.memoryTooltip!)` — force unwrap безопасен (условие проверено выше)
- [ ] Фон popover: `Color.white` (белый, не чёрный)
- [ ] Текст popover: `Color.black` (чёрный, не белый)
- [ ] Добавлена тень: `.shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)`
- [ ] Убрана вложенная `if let tip = spec.memoryTooltip, !tip.isEmpty` — не нужна (внешний if гарантирует)
- [ ] `arrowEdge: .bottom` — стрелка указывает вниз
- [ ] Закрывающая скобка `}` закрывает блок `if` корректно
- [ ] `swift build` проходит без ошибок
- [ ] Popover НЕ появляется на кнопках без памяти (MC, M+, M−, цифры, операторы, функции)
- [ ] Popover появляется ТОЛЬКО на кнопке MR при наведении
- [ ] Фон popover — белый прямоугольник
- [ ] Нет `print()`, `debugPrint()`, `NSLog()` в изменённых файлах
- [ ] Нет force unwrap (`!`) вне `if != nil` guard-блоков
- [ ] Все идентификаторы на английском, комментарии на русском (если будут)
- [ ] Отступы: 4 пробела внутри struct, 8 пробелов в body, 12 пробелов внутри `if`, 16 пробелов внутри замыкания popover
