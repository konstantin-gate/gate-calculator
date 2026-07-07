# План: Замена статического оверлея MR на hover-тултип

**Дата:** 2026-07-06
**Автор:** MimoCode
**Статус:** Готов к утверждению
**Проблема:** Значение памяти отображается статически поверх кнопки MR (некрасиво, число не помещается)
**Цель:** При наведении курсора на MR появляется всплывающая подсказка с хранимым значением

---

## Анализ текущего состояния

### Что сделано предыдущим планом (19-30)

План `2026-07-06 19-30 MimoCode - Исправление тултипа MR финальный план.md` выполнил три изменения:

1. **CalculatorView.swift:63** — упрощена передача `memoryTooltip`: вместо `NSLocalizedString(...) + viewModel.memoryDisplayValue!` теперь `viewModel.memoryDisplayValue`
2. **CalculatorButton.swift:235** — `.helpIfPresent()` заменён на статический `.overlay { Text(tip)... }`
3. **CalculatorButton.swift:249-261** — удалена мёртвая extension `helpIfPresent`

### Текущая проблема

Overlay на строках 235-245 рендерится **всегда** (безусловно), когда `memoryTooltip != nil`. Текст тултипа отображается статически поверх кнопки MR в виде всплывающего «облака» с чёрным фоном. Это не соответствует требованию пользователя: подсказка должна появляться **только при наведении курсора**.

**Текущий код** (`Sources/Views/CalculatorButton.swift:235-245`):
```swift
        .overlay {
            if let tip = spec.memoryTooltip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.bottom, diameter + 4)
            }
        }
```

**Корневая причина:** `.overlay` не имеет привязки к состоянию наведения — он рендерится на каждом кадре.

---

## Архитектурно верное решение

Заменить статический `.overlay` на **`.popover(isPresented:)`** с привязкой к **`.onHover()`**.

**Почему именно `.popover` + `.onHover`:**

| Критерий | `.popover` + `.onHover` | `.overlay` + `.onHover` | Системный `.help()` |
|---|---|---|---|
| Появляется при наведении | Да | Да | Да (с задержкой ~5 сек) |
| Исчезает при уходе курсора | Да (автоматически) | Да (вручную) | Да (автоматически) |
| Стандартное поведение macOS | Да (NSPopover) | Нет (кастомный рендер) | Да (NSToolTip) |
| Контроль над содержимым | Полный | Полный | Ограниченный (строка) |
| Архитектурная чистота | Высокая | Средняя | Высокая |

**Итог:** `.popover` — нативный SwiftUI-компонент для всплывающих окон на macOS. Использует `NSPopover` под капотом, корректно позиционируется относительно целевого view, автоматически закрывается при потере фокуса.

---

## Верификация утверждений

### Утверждение 1: `ButtonSpec.memoryTooltip` — `String?`, определена в `CalculatorButton.swift:112`

**Факт:** `Sources/Views/CalculatorButton.swift:105-113`:
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
**Статус:** ✅ Подтверждено через `read`.

### Утверждение 2: `CalculatorButton` содержит `@State private var isPressed` на строке 126

**Факт:** `Sources/Views/CalculatorButton.swift:126`:
```swift
    @State private var isPressed = false
```
**Статус:** ✅ Подтверждено через `read`. Новое `@State`-свойство добавляется после этой строки.

### Утверждение 3: `viewModel.memoryDisplayValue` — computed property, тип `String?`

**Факт:** `Sources/ViewModels/CalculatorViewModel.swift:45-48`:
```swift
    var memoryDisplayValue: String? {
        guard memoryValue != 0 else { return nil }
        return formatter.format(memoryValue)
    }
```
**Статус:** ✅ Подтверждено через `read`.

### Утверждение 4: Кнопка MR создаётся с `memoryTooltip: viewModel.memoryDisplayValue` в `CalculatorView.swift:63`

**Факт:** `Sources/Views/CalculatorView.swift:63`:
```swift
                ButtonSpec(label: .mR,             type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue),
```
**Статус:** ✅ Подтверждено через `read`.

### Утверждение 5: `.popover(isPresented:)` доступен в macOS 14.0+

**Факт:** `.popover(isPresented:content:)` — стандартный SwiftUI модификатор, доступен с macOS 10.15. Проект таргетируется на macOS 14.0+.
**Статус:** ✅ Подтверждено (SwiftUI docs).

### Утверждение 6: `.onHover()` доступен в macOS 10.15+

**Факт:** `.onHover(perform:)` — стандартный SwiftUI модификатор, доступен с macOS 10.15.
**Статус:** ✅ Подтверждено (SwiftUI docs).

### Утверждение 7: Extension `helpIfPresent` удалена, других вызовов в проекте нет

**Факт:** `grep` по `Sources/` на `helpIfPresent` вернул 0 результатов.
**Статус:** ✅ Подтверждено через `grep`.

### Утверждение 8: Строка 235 в CalculatorButton.swift содержит начало блока `.overlay`

**Факт:** `Sources/Views/CalculatorButton.swift:235`:
```swift
        .overlay {
```
**Статус:** ✅ Подтверждено через `read` (строки 225-257).

---

## План изменений

### Изменение 1: Добавить `@State` для отслеживания наведения

**Файл:** `Sources/Views/CalculatorButton.swift`
**Строка:** После строки 126 (`@State private var isPressed = false`)
**Действие:** Добавить новое `@State`-свойство.

**Текущий код (строки 126-127):**
```swift
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

**Новый код (строки 126-128):**
```swift
    @State private var isPressed = false
    @State private var isHoveringTooltip = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

**Обоснование:** `isHoveringTooltip` управляет видимостью popover. Значение `true` устанавливается при наведении курсора на кнопку, `false` — при уходе. Тип `Bool` — стандартный для `.popover(isPresented:)`.

---

### Изменение 2: Заменить статический `.overlay` на `.popover` + `.onHover`

**Файл:** `Sources/Views/CalculatorButton.swift`
**Строки:** 235-245
**Действие:** Заменить блок `.overlay { ... }` на два модификатора: `.popover(isPresented:)` и `.onHover(perform:)`.

**Текущий код (строки 235-245):**
```swift
        .overlay {
            if let tip = spec.memoryTooltip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.bottom, diameter + 4)
            }
        }
```

**Новый код (строки 235-249):**
```swift
        .popover(isPresented: $isHoveringTooltip) {
            if let tip = spec.memoryTooltip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: 12, weight: .regular))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
        .onHover { hovering in
            isHoveringTooltip = hovering && spec.memoryTooltip != nil
        }
```

**Что изменилось:**
- `.overlay { ... }` → `.popover(isPresented: $isHoveringTooltip) { ... }`
- Убран `.foregroundStyle(Color.white)` — popover использует системный стиль текста (автоматически адаптируется к теме)
- Убран `.background(Color.black.opacity(0.85), in: RoundedRectangle(...))` — popover уже имеет системный фон
- Убран `.padding(.bottom, diameter + 4)` — popover позиционируется автоматически относительно кнопки
- Добавлен `.onHover { hovering in isHoveringTooltip = hovering && spec.memoryTooltip != nil }` — привязка к состоянию наведения

**Почему убраны `Color.white` и `Color.black.opacity(0.85)`:** Нативный popover на macOS использует системный визуальный стиль (NSPopover). Самодельный чёрный фон с белым текстом выглядит нестандартно и не адаптируется к тёмной теме. Нативный popover адаптируется автоматически.

**Верификация:**
- `$isHoveringTooltip` — `Binding<Bool>`, передаётся в `.popover(isPresented:)` ✅
- `spec.memoryTooltip` — `String?` (CalculatorButton.swift:112) ✅
- `.onHover(perform:)` принимает `(Bool) -> Void` ✅
- Два независимых модификатора (`.popover` и `.onHover`) не конфликтуют ✅

---

### Изменение 3: НЕ ТРЕБУЕТСЯ — `CalculatorView.swift:63` остаётся без изменений

**Файл:** `Sources/Views/CalculatorView.swift`
**Строка:** 63
**Статус:** Без изменений. `memoryTooltip: viewModel.memoryDisplayValue` уже передаёт корректное значение.

---

### Изменение 4: НЕ ТРЕБУЕТСЯ — `CalculatorViewModel.swift` остаётся без изменений

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`
**Статус:** Без изменений. `memoryDisplayValue` (строки 45-48) корректно возвращает `String?`.

---

## Итоговая таблица изменений

### Файл: `Sources/Views/CalculatorButton.swift`

| Строка | Тип изменения | Описание |
|---|---|---|
| После 126 | Вставка | `@State private var isHoveringTooltip = false` |
| 235-245 | Замена | Статический `.overlay { Text(tip)... }` → `.popover(isPresented:)` + `.onHover` |

### Файлы БЕЗ изменений

| Файл | Причина |
|---|---|
| `Sources/Views/CalculatorView.swift` | `memoryTooltip: viewModel.memoryDisplayValue` уже корректен |
| `Sources/ViewModels/CalculatorViewModel.swift` | `memoryDisplayValue` работает корректно |
| `Sources/Views/DisplayView.swift` | Не связано с задачей |
| `Sources/History/HistoryEntry.swift` | Не связано с задачей |
| `Package.swift` | Изменения не требуются |

---

## Пошаговый план исполнения

### Шаг 1: Добавить `@State private var isHoveringTooltip`

**Файл:** `Sources/Views/CalculatorButton.swift`

**Действие:** Найти строку 126, содержащую `@State private var isPressed = false`, и вставить новую строку после неё.

**Найти (точная строка 126):**
```swift
    @State private var isPressed = false
```

**Заменить на (строки 126-127):**
```swift
    @State private var isPressed = false
    @State private var isHoveringTooltip = false
```

**Проверка после шага:** Открыть CalculatorButton.swift, убедиться что после `isPressed` объявлена `isHoveringTooltip`.

---

### Шаг 2: Заменить `.overlay` на `.popover` + `.onHover`

**Файл:** `Sources/Views/CalculatorButton.swift`

**Действие:** Найти строки 235-245 (блок `.overlay { ... }`) и заменить их на `.popover(isPresented:)` + `.onHover`.

**Найти (точный блок строк 235-245):**
```swift
        .overlay {
            if let tip = spec.memoryTooltip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.bottom, diameter + 4)
            }
        }
```

**Заменить на (строки 235-249):**
```swift
        .popover(isPresented: $isHoveringTooltip) {
            if let tip = spec.memoryTooltip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: 12, weight: .regular))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
        .onHover { hovering in
            isHoveringTooltip = hovering && spec.memoryTooltip != nil
        }
```

**Проверка после шага:** Открыть CalculatorButton.swift, убедиться что:
1. Строка 235 содержит `.popover(isPresented: $isHoveringTooltip)`
2. Блок popover заканчивается `}` перед `.onHover`
3. Строка `.onHover` содержит `hovering && spec.memoryTooltip != nil`
4. После `.onHover` нет лишних/недостающих скобок

---

### Шаг 3: Проверка компиляции

**Команда:**
```bash
swift build
```

**Ожидаемый результат:** `Build succeeded` без ошибок.

**Если ошибка:** Проверить что:
1. `@State private var isHoveringTooltip = false` добавлен после `isPressed`
2. Блок `.popover` и `.onHover` корректно структурированы (все скобки закрыты)
3. `isHoveringTooltip` используется только в `CalculatorButton.swift` (не выходит за пределы struct)

---

## Ожидаемое поведение после исправления

| Сценарий | Подсказка | Поведение |
|---|---|---|
| MR с памятью, наведение курсора | Попап с числом (например, «10») | Popover появляется мгновенно |
| MR с памятью, уход курсора | Popover исчезает | Автоматически |
| MR без памяти, наведение | Ничего | `memoryTooltip == nil`, popover не появляется |
| Любая другая кнопка, наведение | Ничего | `memoryTooltip == nil`, popover не появляется |
| Зелёный индикатор MR | Виден | Не затронут (отдельный overlay) |

---

## Анализ побочных эффектов

| Элемент | Влияние | Обоснование |
|---|---|---|
| 17 кнопок без тултипа | Не затронуты | `isHoveringTooltip` управляется `spec.memoryTooltip != nil` — на других кнопках popover не появляется |
| Зелёный индикатор | Не затронут | Первый overlay (`.bottomTrailing`, строка 210) — независимый от `.popover` |
| Анимация нажатия (`isPressed`) | Не затронута | `isHoveringTooltip` — независимое состояние |
| `.buttonStyle(.plain)` | Не затронут | `.popover` не зависит от стиля кнопки |
| `.accessibilityLabel` / `.accessibilityHint` | Не затронуты | Остаются без изменений (строки 230-232) |
| `.accessibilityIdentifier` | Не затронут | Остаётся без изменений (строка 233) |
| `.opacity(spec.isEnabled)` | Не затронут | Остаётся без изменений (строка 234) |
| Swift 6.0 strict concurrency | Не затронут | `isHoveringTooltip` — `@State` на `@MainActor`-struct, потокобезопасно |
| CalculatorView.swift | Не затронут | `memoryTooltip: viewModel.memoryDisplayValue` уже корректен |
| CalculatorViewModel.swift | Не затронут | `memoryDisplayValue` уже корректен |

---

## Чеклист верификации перед завершением

- [ ] `@State private var isHoveringTooltip = false` добавлен после `isPressed` в CalculatorButton.swift
- [ ] Блок `.overlay { Text(tip)... }` заменён на `.popover(isPresented: $isHoveringTooltip) { ... }`
- [ ] Добавлен `.onHover { hovering in isHoveringTooltip = hovering && spec.memoryTooltip != nil }`
- [ ] Убраны `foregroundStyle(Color.white)` и `background(Color.black...)` из содержимого popover
- [ ] Убран `padding(.bottom, diameter + 4)` из содержимого popover
- [ ] `swift build` проходит без ошибок
- [ ] Popover появляется ТОЛЬКО при наведении курсора на MR
- [ ] Popover исчезает при уходе курсора с MR
- [ ] На кнопках без памяти popover не появляется
- [ ] Зелёный индикатор продолжает работать корректно
- [ ] Нет `print()`, `debugPrint()`, `NSLog()` в изменённом коде
- [ ] Нет force unwrap (`!`) в изменённом коде
- [ ] Все идентификаторы на английском, комментарии на русском
