# Краткое содержание плана

## Задача
Добавить на кнопку MR два визуальных элемента: зелёный кружочек в правом нижнем углу (когда в памяти есть значение) и всплывающую подсказку с отформатированным значением памяти при наведении курсора.

## Изменяемые файлы (4 штуки)
1. `Sources/ViewModels/CalculatorViewModel.swift` — добавить computed property `memoryDisplayValue: String?`
2. `Sources/Views/CalculatorButton.swift` — добавить два свойства в ButtonSpec, добавить `.overlay(...)` с кружком и `.help(...)` для тултипа
3. `Sources/Views/CalculatorCalculatorView.swift` — передать новые параметры в ButtonSpec для кнопки .mR
4. `Sources/Localization/en.lproj/Localizable.strings` и `ru.lproj/Localizable.strings` — добавить ключ `"memory.tooltip"`

## Что НЕ изменяется
- `memoryValue`, `hasMemory`, `memoryClear()`, `memoryAdd()`, `memorySubtract()`, `memoryRecall()` — untouched
- Кнопки MC, M+, M− — без индикации
- `ButtonLabel` enum — не расширяется

## Позиция кружка
Правый НИЖНИЙ угол кнопки MR (`.bottomTrailing`), а не верхний.

## Ключевые решения
- `memoryDisplayValue: String?` — опциональный тип, nil когда память пуста (tooltip не показывается)
- `.overlay(alignment: .bottomTrailing)` — кружок в правом нижнем углу
- `.help(spec.memoryTooltip ?? "")` — тултип при наведении
- `.accessibilityHidden(true)` на кружке — VoiceOver игнорирует его
- Локализация префикса "Память: " / "Memory: " через NSLocalizedString

## Порядок шагов
1. CalculatorViewModel — добавить `memoryDisplayValue`
2. CalculatorButton — свойства в ButtonSpec
3. CalculatorView — передать параметры в кнопку MR
4. CalculatorButton — overlay с кружком (после `.buttonStyle(.plain)`)
5. CalculatorButton — `.help()` для тултипа (после `.opacity(...)`)
6. Локализация — добавить ключи
