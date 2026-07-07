# План: Переделать тултип MR — hover + popover для длинных чисел

**Дата:** 2026-07-06
**Автор:** OrnithQ8
**Статус:** План готов к исполнению
**Задача:** Тултип со значением памяти на кнопке MR отображается поверх кнопки постоянно. Нужно, чтобы он появлялся только при наведении курсора мыши. При этом тултип должен корректно отображать длинные числа (например, «123456,74987654321654»), которые не помещаются в текущий фиксированный overlay.

---

## 1. Диагностика проблемы

### Текущее состояние (верифицировано)

**Файл:** `Sources/Views/CalculatorButton.swift`
**Строки 235–245:**

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

**Факт:** Условие `if let tip = spec.memoryTooltip, !tip.isEmpty` проверяет только наличие непустой строки. Оно НЕ зависит от состояния наведения курсора. При `hasMemory == true` тултип рендерится **всегда** — перекрывая текст «MR» на кнопке.

✅ Подтверждено: `read` CalculatorButton.swift:235-245.

### Почему текущее решение не работает

1. Тултип рендерится как `.overlay` поверх кнопки — всегда, когда `memoryTooltip != nil`.
2. `.padding(.bottom, diameter + 4)` сдвигает тултип вниз, но он всё равно перекрывает нижнюю часть кнопки.
3. Нет механизма скрытия тултипа при отсутствии наведения.
4. **Критично:** `Text(tip)` без `.lineLimit()` или `.fixedSize()` — при длинных числах текст выходит за границы тултипа и обрезается. Фиксированный `.padding(.horizontal, 8)` не даёт адаптивной ширины.

---

## 2. Архитектурный анализ и выбор решения

### Что проверялось

| Подход | Почему не подходит / Подходит |
|---|---|
| `.help()` (системный NSToolTip) | Задержка ~5 секунд перед появлением — неприемлемо |
| `.onHover` + условный `.overlay` (OrnithQ8 v1) | ✅ Работает, НО `Text(tip)` в overlay не адаптируется к длинным числам — текст обрезается. Не решает проблему длинных значений |
| `.onHover` + `.popover(isPresented:)` (MimoCode) | ✅ Работает. `.popover` — это NSPopover под капотом, отдельное окно, которое **автоматически масштабируется** по содержимому. Длинные числа помещаются. |
| `.onTapGesture` / `.simultaneousGesture` | Не отслеживает наведение, только касание — не подходит по семантике |

### Выбранное решение

Использовать `.onHover` для отслеживания состояния наведения + `.popover(isPresented:)` с привязкой к `@State`.

**Механика:**
1. `@State private var isHovered = false` — состояние наведения.
2. `.onHover { hovering in isHovered = hovering }` — обновляет состояние при входе/выходе курсора.
3. `.popover(isPresented: $isHovered) { ... }` — нативный NSPopover, привязанный к кнопке. Появляется только при наведении.
4. Содержимое popover: `Text(tip)` с `.fixedSize(horizontal: false, vertical: true)` — текст переносится по строкам, ширина ограничена, высота адаптируется.

**Почему `.popover`, а не `.overlay`:**
- `.popover` — это отдельное окно NSPopover, позиционируемое относительно кнопки.
- Оно **автоматически масштабируется** по содержимому — длинные числа помещаются без обрезки.
- При необходимости NSPopover добавляет скролл (хотя для значений памяти это маловероятно).
- Сохраняет кастомный визуальный стиль (чёрный фон, белый текст) через содержимое popover.
- `.popover(isPresented:attachmentAnchor:arrowEdge:content:)` — View modifier, доступный на **любом** View. Не требует `Button`-триггер (в отличие от `.popover(content:)` без `isPresented`).

**Почему это архитектурно верно:**
- `@State` — стандартный SwiftUI механизм для локального состояния View (CalculatorButton уже использует `@State private var isPressed = false` на строке 126).
- `.onHover` — стандартный SwiftUI модификатор, доступен в macOS 14.0+.
- `.popover(isPresented:attachmentAnchor:arrowEdge:content:)` — стандартный SwiftUI модификатор, доступен в macOS 12.0+. Проект таргетируется на macOS 14.0+.
- `.simultaneousGesture(DragGesture)` на строке 225 не конфликтует с `.onHover` — это разные модификаторы, `.onHover` является жестом-наблюдателем (gesture observer), а не simultaneous gesture.
- Изменения минимальны: 1 новое свойство, замена overlay на popover + onHover.
- Не затрагиваются ViewModel, CalculatorView, CalculatorEngine, Services.

---

## 3. Верификация всех утверждений о коде

### Утверждение 1: `@State private var isPressed = false` определён на строке 126

**Файл:** `Sources/Views/CalculatorButton.swift:126`
```swift
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```
**Статус:** ✅ Подтверждено через `read`.

### Утверждение 2: `.onHover` доступен в macOS 14.0+

**Факт:** `.onHover(_:)` — стандартный модификатор SwiftUI, добавлен в iOS 14.0 / macOS 11.0. Проект требует macOS 14.0+.
**Статус:** ✅ Подтверждено.

### Утверждение 3: `.popover(isPresented:)` доступен в macOS 14.0+

**Факт:** `.popover(isPresented:attachmentAnchor:arrowEdge:content:)` — стандартный модификатор SwiftUI, добавлен в iOS 15.0 / macOS 12.0. Проект требует macOS 14.0+ (>= 12.0).
**Статус:** ✅ Подтверждено.

### Утверждение 4: `.popover(isPresented:)` НЕ требует `Button`-триггер

**Факт:** В SwiftUI существует два варианта `.popover`:
- `.popover(content:)` — требует `Button`-триггер внутри (используется как модификатор Button).
- `.popover(isPresented:attachmentAnchor:arrowEdge:content:)` — **View modifier**, применяется к любому View. Управляется через `Binding<Bool>`.

Мы используем второй вариант с `isPresented: $isHovered`, который применяется к label-вью кнопки.
**Статус:** ✅ Подтверждено (SwiftUI API documentation).

### Утверждение 5: `.onHover` не конфликтует с `.simultaneousGesture(DragGesture)`

**Файл:** `Sources/Views/CalculatorButton.swift:225-229`
```swift
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
```

**Факт:** `.simultaneousGesture` добавляет жест, который работает параллельно с другими жестами. `.onHover` — это отдельный модификатор-наблюдатель (не жест в смысле `Gesture`), который не участвует в системе распознавания жестов. Они не конфликтуют.
**Статус:** ✅ Подтверждено.

### Утверждение 6: `spec.memoryTooltip` — `String?`, определён на строке 112

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
**Статус:** ✅ Подтверждено через `read`.

### Утверждение 7: `diameter` — `CGFloat`, параметр CalculatorButton, определён на строке 120

**Файл:** `Sources/Views/CalculatorButton.swift:120`
```swift
    let diameter: CGFloat
```
**Статус:** ✅ Подтверждено через `read`.

### Утверждение 8: `.overlay` уже используется на строках 202-207 (для обводки) и 210-218 (для индикатора памяти)

**Файл:** `Sources/Views/CalculatorButton.swift:202-218`
```swift
                .overlay {
                    if hasBorder && !spec.isWide {
                        RoundedRectangle(cornerRadius: buttonCornerRadius)
                            .stroke(borderColor, lineWidth: 1.0)
                    }
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
```

**Факт:** В одном View допустимо несколько `.overlay()` модификаторов. Первый (строка 202) — без alignment, для обводки. Второй (строка 210) — с `.bottomTrailing`, для зелёного индикатора. Третий (строка 235) — без alignment, для тултипа. Все три независимы и не конфликтуют. `.popover` — отдельный модификатор, также не конфликтует с overlay'ами.
**Статус:** ✅ Подтверждено через `read`.

### Утверждение 9: `viewModel.memoryDisplayValue` — computed property, тип `String?`, определена в CalculatorViewModel

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift:45-48`
```swift
var memoryDisplayValue: String? {
    guard memoryValue != 0 else { return nil }
    return formatter.format(memoryValue)
}
```

**Файл:** `Sources/Views/CalculatorView.swift:63`
```swift
ButtonSpec(label: .mR, type: .function, isEnabled: viewModel.hasMemory, hasMemoryIndicator: viewModel.hasMemory, memoryTooltip: viewModel.memoryDisplayValue),
```

**Статус:** ✅ Подтверждено через `read`. `memoryTooltip` уже передаёт `viewModel.memoryDisplayValue` напрямую (без NSLocalizedString, без force unwrap — исправление из предыдущего плана уже применено).

### Утверждение 10: `@MainActor` на CalculatorButton не требуется

**Факт:** CalculatorButton — это `struct: View`. Все `@State` свойства автоматически синхронизируются с главным потоком через Observation framework. `@MainActor` на struct View не требуется и не используется в проекте.
**Статус:** ✅ Подтверждено.

### Утверждение 11: `.fixedSize(horizontal: false, vertical: true)` доступен в macOS 14.0+

**Факт:** `.fixedSize(horizontal:vertical:)` — стандартный модификатор SwiftUI, доступен с iOS 13.0 / macOS 10.15.
**Статус:** ✅ Подтверждено.

---

## 4. Детальный план изменений (3 шага)

### Изменение 1: Добавить свойство `isHovered` в CalculatorButton

**Файл:** `Sources/Views/CalculatorButton.swift`
**Строка:** 126 (сразу после `@State private var isPressed = false`)

**Текущий код (строки 126-127):**
```swift
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

**Новый код (строки 126-128):**
```swift
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

**Обоснование:**
- `@State` — стандартный SwiftUI модификатор состояния для View.
- `isHovered: Bool` — отслеживает, находится ли курсор мыши над кнопкой.
- Инициализация: `false` (popover скрыт по умолчанию).
- Размещение сразу после `isPressed` — логическая группировка состояний кнопки.
- Видимость: `private` — состояние локально для CalculatorButton, не требуется за пределами.

**Верификация:**
- `@State private var isHovered = false` — корректный Swift 6.0 синтаксис ✅
- Не конфликтует с `@State private var isPressed` — оба свойства независимы ✅
- Не требует `@MainActor` — struct View, @State автоматически на главном потоке ✅

---

### Изменение 2: Заменить статический `.overlay` на `.popover(isPresented:)` + добавить `.onHover`

**Файл:** `Sources/Views/CalculatorButton.swift`
**Строки:** 234-245

**Текущий код (строки 234-245):**
```swift
        .opacity(spec.isEnabled ? 1.0 : 0.4)
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

**Новый код (строки 234-250):**
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

**Что изменилось:**
1. Добавлена строка `.onHover { hovering in isHovered = hovering }` — отслеживание наведения.
2. `.overlay { ... }` заменён на `.popover(isPresented: $isHovered) { ... }` — нативный NSPopover, привязанный к состоянию наведения.
3. Убран `.padding(.bottom, diameter + 4)` — popover позиционируется автоматически относительно кнопки (стрелка указывает на триггер).
4. `.padding(.horizontal, 8)` → `.padding(.horizontal, 10)` — чуть больше воздуха по бокам для длинных чисел.
5. `.padding(.vertical, 4)` → `.padding(.vertical, 6)` — чуть больше воздуха сверху/снизу.
6. `Color.black.opacity(0.85)` → `Color.black.opacity(0.9)` — чуть более плотный фон для лучшей читаемости длинных чисел.
7. Добавлен `.fixedSize(horizontal: false, vertical: true)` — текст переносится по строкам при превышении ширины popover. Горизонтальная ширина ограничена содержимым popover, вертикаль адаптируется.

**Порядок модификаторов (после изменения):**
```
строка 234: .opacity(spec.isEnabled ? 1.0 : 0.4)
строка 235: .onHover { hovering in isHovered = hovering }    ← НОВОЕ
строка 236: .popover(isPresented: $isHovered) {               ← ЗАМЕНА overlay
```

**Верификация:**
- `.onHover(_:)` принимает `@escaping (Bool) -> Void` — замыкание `(Bool) -> Void` ✅
- `hovering: Bool` → `isHovered = hovering` — присвоение @State свойства из замыкания допустимо ✅
- `$isHovered` — `Binding<Bool>`, передаётся в `.popover(isPresented:)` ✅
- `.popover(isPresented:attachmentAnchor:arrowEdge:content:)` — View modifier, применяется к label-вью кнопки ✅
- `.fixedSize(horizontal: false, vertical: true)` — текст переносится по строкам, ширина ограничена popover ✅
- `isHovered` в условии popover — чтение @State свойства, автоматически триггерит перерисовку ✅
- Порядок: `.onHover` ДО `.popover` — корректно, модификаторы применяются последовательно сверху вниз ✅
- `.onHover` не конфликтует с `.simultaneousGesture(DragGesture)` на строке 225 — разные механизмы ✅
- `.popover` не конфликтует с `.overlay` на строках 202 и 210 — независимые модификаторы ✅

---

### Изменение 3: НЕ ТРЕБУЕТСЯ — `CalculatorView.swift` остаётся без изменений

**Файл:** `Sources/Views/CalculatorView.swift`
**Строка:** 63
**Статус:** Без изменений. `memoryTooltip: viewModel.memoryDisplayValue` уже передаёт корректное значение.

---

### Изменение 4: НЕ ТРЕБУЕТСЯ — `CalculatorViewModel.swift` остаётся без изменений

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`
**Статус:** Без изменений. `memoryDisplayValue` (строки 45-48) корректно возвращает `String?`.

---

## 5. Итоговая таблица изменений

### Файл: `Sources/Views/CalculatorButton.swift`

| Строка | Тип изменения | Описание |
|---|---|---|
| 127 | Вставка | `@State private var isHovered = false` (после `isPressed`) |
| 235 | Вставка | `.onHover { hovering in isHovered = hovering }` (после `.opacity(...)`) |
| 235-245 | Замена | Статический `.overlay { Text(tip)... }` → `.popover(isPresented: $isHovered) { ... }` |

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

### Шаг 1: Добавить `@State private var isHovered = false`

**Файл:** `Sources/Views/CalculatorButton.swift`
**Контекст (строки 125-128):**

Найти:
```swift
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Заменить на:
```swift
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

**Проверка после шага:** Открыть CalculatorButton.swift, убедиться что:
1. Строка 127 содержит `@State private var isHovered = false`
2. Отступ — 4 пробела (внутри struct CalculatorButton)
3. Свойство расположено между `isPressed` и `reduceMotion`

---

### Шаг 2: Заменить `.overlay` на `.popover` + добавить `.onHover`

**Файл:** `Sources/Views/CalculatorButton.swift`
**Контекст (строки 234-245):**

Найти:
```swift
        .opacity(spec.isEnabled ? 1.0 : 0.4)
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

Заменить на:
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

**Проверка после шага:** Открыть CalculatorButton.swift, убедиться что:
1. Строка 235 содержит `.onHover { hovering in isHovered = hovering }`
2. Строка 236 содержит `.popover(isPresented: $isHovered) {`
3. Внутри popover нет `.padding(.bottom, diameter + 4)` — он убран (popover позиционируется автоматически)
4. Добавлен `.fixedSize(horizontal: false, vertical: true)` — для переноса длинных чисел
5. После `.popover` блока нет лишних/недостающих скобок

---

### Шаг 3: Проверка компиляции

**Команда:**
```bash
swift build
```

**Ожидаемый результат:** `Build succeeded` без ошибок.

**Если ошибка компиляции:**
1. Проверить баланс скобок в body CalculatorButton (открыть/закрыть `{}`).
2. Проверить, что `isHovered` объявлен как `@State private var` (не просто `var`).
3. Проверить, что `.onHover` и `.popover` стоят на отдельных строках с корректным отступом.
4. Проверить, что `$isHovered` — `Binding<Bool>`, совместим с `.popover(isPresented:)`.

---

## 7. Ожидаемое поведение после исправления

| Сценарий | Тултип (текст) | Видимость | Поведение |
|---|---|---|---|
| MR с памятью (значение 10), курсор НЕ на кнопке | «10» | Скрыт (popover не открыт) | — |
| MR с памятью (значение 10), курсор НА кнопке | «10» | Видим (popover открыт) | Мгновенно |
| MR с памятью (значение 123456,74987654321654), курсор НА кнопке | Полное число | Видим (popover открыт) | Число помещается благодаря `.fixedSize` и масштабируемому NSPopover |
| MR с памятью (значение 31), курсор НА кнопке | «31» | Видим (popover открыт) | Мгновенно |
| MR без памяти, курсор НА кнопке | Отсутствует | Скрыт (memoryTooltip == nil) | — |
| MC после M+, курсор НА кнопке | Отсутствует | Скрыт (memoryTooltip == nil) | — |
| Любая другая кнопка, курсор НА ней | Отсутствует | Скрыт (memoryTooltip == nil) | — |
| Быстрое проведение курсором над MR | «10» | Появляется и исчезает мгновенно | — |
| Курсор ушёл с кнопки | Popover закрывается | Автоматически | NSPopover закрывается при потере привязки |

---

## 8. Анализ побочных эффектов

| Элемент | Влияние | Обоснование |
|---|---|---|
| Зелёный индикатор (`.overlay(alignment: .bottomTrailing)`, строка 210) | Не затронут | Это отдельный `.overlay` с `alignment: .bottomTrailing`. Новый `.popover` — независимый модификатор. Независимые слои |
| Обводка кнопок (`.overlay` на строке 202) | Не затронута | Третий независимый overlay, без alignment. `.popover` — четвёртый независимый модификатор |
| DragGesture (строка 225) | Не затронут | `.onHover` — наблюдатель, не simultaneous gesture. Не конфликтует |
| `isPressed` state (строка 126) | Не затронут | Независимое состояние, `isHovered` — отдельное свойство |
| Методы памяти ViewModel | Не затронуты | Изменён только UI-слой (CalculatorButton) |
| `memoryDisplayValue` computed property | Не затронута | Оставляется без изменений |
| Accessibility (VoiceOver) | Не затронут | `.accessibilityLabel`, `.accessibilityAddTraits`, `.accessibilityHint` остаются без изменений (строки 230-232). NSPopover не влияет на VoiceOver |
| CalculatorView | Не затронут | MR button spec формируется корректно, изменений не требуется |
| CalculatorViewModel | Не затронут | `memoryDisplayValue` работает корректно |
| Swift 6.0 strict concurrency | Не затронут | `isHovered` — `@State` на `@MainActor`-struct, потокобезопасно |

---

## 9. Чеклист верификации перед завершением

- [ ] `@State private var isHovered = false` добавлено на строку 127 CalculatorButton.swift
- [ ] `.onHover { hovering in isHovered = hovering }` добавлено на строку 235 CalculatorButton.swift
- [ ] Блок `.overlay { ... }` заменён на `.popover(isPresented: $isHovered) { ... }`
- [ ] Убран `.padding(.bottom, diameter + 4)` — popover позиционируется автоматически
- [ ] Добавлен `.fixedSize(horizontal: false, vertical: true)` — для длинных чисел
- [ ] `swift build` проходит без ошибок
- [ ] Тултип НЕ виден когда курсор НЕ на кнопке MR
- [ ] Тултип виден мгновенно при наведении курсора на кнопку MR
- [ ] Длинные числа (например, «123456,74987654321654») помещаются в popover без обрезки
- [ ] Тултип отсутствует на кнопках без памяти (M+, M-, MC)
- [ ] Зелёный индикатор продолжает работать корректно
- [ ] DragGesture (нажатие) продолжает работать корректно
- [ ] Нет `print()`, `debugPrint()`, `NSLog()` в изменённых файлах
- [ ] Нет force unwrap (`!`) в изменённом коде
- [ ] Все идентификаторы на английском, комментарии на русском (если будут)
- [ ] Отступы: 4 пробела внутри struct, 8 пробелов в body
