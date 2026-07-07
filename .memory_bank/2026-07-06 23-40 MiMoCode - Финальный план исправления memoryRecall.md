# Финальный план исправления: MR затирает выражение при наличии оператора

**Дата:** 2026-07-06
**Автор:** MiMoCode (финальная версия, объединяющая лучшие решения)
**Статус:** Готов к исполнению

---

## Тезисный план (позиции)

1. Модифицировать метод `memoryRecall()` в файле `Sources/ViewModels/CalculatorViewModel.swift` (строки 176–181)
2. Добавить вызов `clearError()` в начало метода — сброс ошибки перед работой с выражением
3. Добавить проверку: если `expression` не пуст И заканчивается оператором — дописать `memoryValue.description` через `+=`, иначе — заменить expression как раньше
4. Использовать **уже существующий** метод `isTrailingOperator(_:)` (строка 250) — не создавать новых методов
5. Сбросить `result`, `resultDecimal`, `errorMessage` в nil (без изменений, как в оригинале)
6. Проверить компиляцию через `swift build`
7. Проверить сценарий "10" → M+ → "+" → MR → "=" → результат должен быть 20

---

## Детализированный план реализации

### 0. Контекст задачи

**Баг:** При нажатии кнопки MR после ввода оператора (например, `"10+"`) значение из памяти затирает текущее выражение вместо дописывания правого операнда.

**Пример воспроизведения:**
1. Пользователь вводит `"10"` — expression = `"10"`
2. Нажимает M+ — memoryValue = 10
3. Нажимает `"+"` — expression = `"10+"`
4. Нажимает MR — expression = `"10"` (ОШИБКА: должно быть `"10+10"`)
5. Нажимает `"="` — результат 10 (ОШИБКА: должно быть 20)

**Корневая причина:** Метод `memoryRecall()` (строка 177) выполняет безусловное присваивание `expression = memoryValue.description`, полностью заменяя предыдущее выражение.

---

### 1. Файл для изменения

**Путь:** `Sources/ViewModels/CalculatorViewModel.swift`
**Единственный изменяемый файл** — никакие другие файлы проекта не редактируются.

---

### 2. Текущий код метода `memoryRecall()` (строки 176–181)

```swift
func memoryRecall() {
    expression = memoryValue.description
    result = nil
    resultDecimal = nil
    errorMessage = nil
}
```

---

### 3. Новый код метода `memoryRecall()`

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

**Что именно меняется:**
- **Строка 177** (`expression = memoryValue.description`) — заменяется на блок из 5 строк (clearError, let memStr, if/else, expression += memStr или expression = memStr)
- **Строка 180** (`errorMessage = nil`) — удаляется, потому что `clearError()` в начале метода уже выполняет эту работу
- **Строка 179** (`resultDecimal = nil`) — остаётся без изменений

---

### 4. Верификация всех элементов, используемых в исправлении

#### 4.1. Метод `clearError()` — СУЩЕСТВУЕТ

- **Файл:** `Sources/ViewModels/CalculatorViewModel.swift`
- **Строки:** 259–261
- **Сигнатура:** `private func clearError()`
- **Тело:** `errorMessage = nil`
- **Видимость:** private (доступен внутри CalculatorViewModel)
- **Метод верификации:** `read`

#### 4.2. Свойство `expression` — СУЩЕСТВУЕТ

- **Файл:** `Sources/ViewModels/CalculatorViewModel.swift`
- **Строка:** 10
- **Объявление:** `var expression: String = ""`
- **Тип:** `String`
- **Операция `+=`:** стандартная операция конкатенации строк Swift, корректна для String
- **Метод верификации:** `read`

#### 4.3. Свойство `memoryValue` — СУЩЕСТВУЕТ

- **Файл:** `Sources/ViewModels/CalculatorViewModel.swift`
- **Строка:** 37
- **Объявление:** `private var memoryValue: Decimal = 0`
- **Тип:** `Decimal` (Foundation)
- **Метод `.description`:** возвращает строковое представление Decimal в формате ASCII (точка как десятичный разделитель, без разделителей тысяч). Примеры: `Decimal(10).description` → `"10"`, `Decimal(3.14).description` → `"3.14"`, `Decimal(0).description` → `"0"`
- **Метод верификации:** `read`

#### 4.4. Метод `isTrailingOperator(_:)` — СУЩЕСТВУЕТ

- **Файл:** `Sources/ViewModels/CalculatorViewModel.swift`
- **Строки:** 250–253
- **Сигнатура:** `private func isTrailingOperator(_ expr: String) -> Bool`
- **Тело:**
  ```swift
  guard let last = expr.last else { return false }
  return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
  ```
- **Параметр:** `expr` типа `String` — проверяемая строка
- **Возвращаемое значение:** `Bool` — `true` если последний символ строки является одним из операторов (`+`, `-`, `*`, `/`, `%`), `false` во всех остальных случаях
- **Видимость:** private (доступен внутри CalculatorViewModel)
- **Уже используется в:** `tryAutoEvaluate()` (строка 239) — метод протестирован в существующем коде
- **Метод верификации:** `read`

#### 4.5. Свойство `result` — СУЩЕСТВУЕТ

- **Файл:** `Sources/ViewModels/CalculatorViewModel.swift`
- **Строка:** 11
- **Объявление:** `var result: String? = nil`
- **Тип:** `String?`
- **Метод верификации:** `read`

#### 4.6. Свойство `resultDecimal` — СУЩЕСТВУЕТ

- **Файл:** `Sources/ViewModels/CalculatorViewModel.swift`
- **Строка:** 12
- **Объявление:** `internal var resultDecimal: Decimal? = nil`
- **Тип:** `Decimal?`
- **Метод верификации:** `read`

#### 4.7. Вызывающий код в CalculatorView — ЕДИНСТВЕННЫЙ ПОТРЕБИТЕЛЬ

- **Файл:** `Sources/Views/CalculatorView.swift`
- **Строки:** 160–161
- **Код:**
  ```swift
  case .mR:
      viewModel.memoryRecall()
  ```
- **Вызывающий метод:** `handleButtonPress(_ label: ButtonLabel)` (строка 133)
- **Клавиатурный ввод MR:** НЕ реализован. В `KeyHandlerNSView` (файл `Sources/App/CalculatorApp.swift`, строки 82–103) кейс для MR отсутствует. Единственный путь вызова — нажатие кнопки MR в UI.
- **Кнопка MR отключена при пустой памяти:** `ButtonSpec(label: .mR, isEnabled: viewModel.hasMemory, ...)` (строка 63). При `memoryValue == 0` кнопка отключена, `memoryRecall()` не вызывается.
- **Метод верификации:** `read`

---

### 5. Поведение после исправления — полная таблица сценариев

| # | Последовательность действий | expression ДО MR | expression ПОСЛЕ MR | Ожидаемый результат | Корректно? |
|---|---|---|---|---|---|
| A | MR (пустой дисплей) | `""` | `"10"` (memoryValue=10) | Запись числа из памяти | ✅ |
| B | "10" → M+ → "+" → MR → "=" | `"10+"` | `"10+10"` | 20 (было 10) | ✅ Исправляет баг |
| C | "10" → M+ → "-" → MR → "=" | `"10-"` | `"10-10"` | 0 | ✅ Исправляет баг |
| D | "10" → M+ → "*" → MR → "=" | `"10*"` | `"10*10"` | 100 | ✅ Исправляет баг |
| E | "10" → M+ → "/" → MR → "=" | `"10/"` | `"10/10"` | 1 | ✅ Исправляет баг |
| F | "5" → MR | `"5"` | `"10"` (memoryValue=10) | Замена (последний символ "5" — не оператор) | ✅ Стандартное поведение |
| G | "2+3" → "=" (результат 5) → MR | `""` (evaluate очищает expression) | `"10"` | Запись числа (expression пуста) | ✅ |
| H | "2+3" → "=" (результат 5) → "+" → MR | `"5+"` | `"5+10"` | 15 | ✅ Исправляет баг |
| I | "10+" → MR → MR | `"10+"` → `"10+10"` | `"10+10"` → `"10"` | Второй MR: последний символ "0" ≠ оператор → замена | ✅ |
| J | "10+" → MR → "+" → MR | `"10+"` → `"10+10"` → `"10+10+"` | `"10+10+10"` | 30 | ✅ |
| K | MR → MR | `""` → `"10"` | `"10"` → `"10"` | Повторный MR: expression не пуст, но не заканчивается оператором → замена | ✅ |
| L | "++" → MR (теоретический кейс) | `"++"` | `"++10"` | Parser вернёт ошибку `doubleOperator` | ✅ |

---

### 6. Анализ взаимодействия с `tryAutoEvaluate()`

**Важно:** Метод `memoryRecall()` **не вызывает** `tryAutoEvaluate()`.

`tryAutoEvaluate()` вызывается из:
- `appendCharacter(_:)` (строка 77) — при вводе нецифрового символа
- `backspace()` (строка 135) — после удаления символа

**Цепочка после MR → ввод оператора:**
1. `memoryRecall()` → expression = `"10+10"`, result = nil, resultDecimal = nil
2. Пользователь нажимает `"+"` → `appendCharacter("+")`
3. `hasResult` = false (memoryRecall сбросил resultDecimal) → оба guard в appendCharacter пропускаются
4. `expression += "+"` → `"10+10+"`
5. `tryAutoEvaluate()` → `isTrailingOperator("10+10+")` = `true` (последний символ "+") → возврат без вычисления

**Цепочка после MR → ввод цифры:**
1. `memoryRecall()` → expression = `"10+10"`, result = nil, resultDecimal = nil
2. Пользователь нажимает `"5"` → `appendCharacter("5")`
3. `hasResult` = false → оба guard пропускаются
4. `expression += "5"` → `"10+105"`
5. `isDigitOrDecimal("5")` = `true` → `tryAutoEvaluate()` **не вызывается**

**Вывод:** Побочных эффектов с `tryAutoEvaluate()` нет.

---

### 7. Анализ взаимодействия с другими методами памяти

| Метод | Файл:строки | Затронут? | Причина |
|-------|-------------|-----------|---------|
| `memoryClear()` | CalculatorViewModel.swift:162–164 | Нет | Только `memoryValue = 0`, не зависит от memoryRecall |
| `memoryAdd()` | CalculatorViewModel.swift:166–169 | Нет | Только `memoryValue += val`, не зависит от memoryRecall |
| `memorySubtract()` | CalculatorViewModel.swift:171–174 | Нет | Только `memoryValue -= val`, не зависит от memoryRecall |

**Вывод:** Другие операции памяти не затрагиваются.

---

### 8. Анализ влияния на вычисление `currentDisplayValue`

- `currentDisplayValue` (строки 42–49) — computed property, зависит от `resultDecimal` и `expression`
- `memoryRecall()` устанавливает `resultDecimal = nil`, поэтому после MR `currentDisplayValue` вычисляется из `expression`
- После исправления: expression содержит `"10+10"` вместо `"10"`, но `currentDisplayValue` просто читает текущее состояние — логика не меняется

**Вывод:** Нет влияния.

---

### 9. Анализ влияния на `hasResult`

- `hasResult` (строка 19) — computed: `resultDecimal != nil`
- `memoryRecall()` устанавливает `resultDecimal = nil` (строка 179)
- После исправления: `resultDecimal` по-прежнему устанавливается в `nil`

**Вывод:** Нет влияния.

---

### 10. Анализ влияния на историю

- `memoryRecall()` **не вызывает** `historyService.add()`
- История записывается только в `evaluate()` (строка 108)
- После исправления: выражение `"10+10"` будет вычислено по `"="`, в историю запишется `"10+10"` → 20

**Вывод:** История корректна.

---

### 11. Анализ влияния на UI-слой

- `CalculatorView.swift:160-161` — вызывает `viewModel.memoryRecall()` без параметров, без возврата значения
- `DisplayView` — отображает `expression`, `result`, `errorMessage` через @Observable
- После исправления: expression будет содержать `"10+10"` вместо `"10"`, что корректно отобразится

**Вывод:** UI-слой не требует изменений.

---

### 12. Анализ влияния на потокобезопасность (Swift 6.0)

- `CalculatorViewModel` помечен `@MainActor` (строка 6) — все методы выполняются на главном потоке
- `expression`, `result`, `resultDecimal` — мутабельные свойства, доступ синхронизирован через @MainActor
- Изменение с `=` на `+=` для String — атомарная операция в контексте @MainActor

**Вывод:** Потокобезопасность не нарушена.

---

### 13. Файлы, НЕ подлежащие изменению (подтверждено)

| Файл | Причина |
|------|---------|
| `Sources/Views/CalculatorView.swift` | Маппинг `.mR → memoryRecall()` корректен, не меняется |
| `Sources/Views/DisplayView.swift` | Только отображает expression/result/errorMessage |
| `Sources/App/CalculatorApp.swift` | KeyHandlerNSView не вызывает memoryRecall |
| `Sources/CalculatorEngine/*.swift` | Вычислительный движок не участвует в логике памяти |
| `Sources/Services/HistoryService.swift` | Не участвует в операции MR |
| `Sources/Clipboard/ClipboardManager.swift` | Не участвует в операции MR |
| `Sources/Formatting/NumberFormatterService.swift` | Не участвует в операции MR |
| `Sources/History/HistoryEntry.swift` | Модель данных не затрагивается |
| `Package.swift` | Структура модулей не меняется |

---

### 14. Анализ регрессий

| Метод | Затронут? | Риск |
|-------|-----------|------|
| `appendCharacter(_:)` (строки 60–79) | Нет | Отсутствует |
| `evaluate()` (строки 97–116) | Нет | Отсутствует |
| `clear()` (строки 118–123) | Нет | Отсутствует |
| `backspace()` (строки 125–139) | Нет | Отсутствует |
| `toggleSign()` (строки 142–158) | Нет | Отсутствует |
| `handleKeyCommand(_:)` (строки 183–196) | Нет | Отсутствует |
| `insertFromClipboard(_:)` (строки 200–215) | Нет | Отсутствует |
| `useHistoryEntry(_:)` (строки 223–228) | Нет | Отсутствует |
| `tryAutoEvaluate()` (строки 237–248) | Нет | Отсутствует |
| `isTrailingOperator(_:)` (строки 250–253) | Нет (только читается) | Отсутствует |
| `isOperator(_:)` (строки 255–257) | Нет | Отсутствует |

**Вывод:** Ни один другой метод не модифицируется и не зависит от изменений в `memoryRecall()`.

---

### 15. Пошаговый алгоритм исполнения

**Шаг 1.** Открыть файл `Sources/ViewModels/CalculatorViewModel.swift`

**Шаг 2.** Найти метод `memoryRecall()` (строки 176–181). Текущий код:
```swift
func memoryRecall() {
    expression = memoryValue.description
    result = nil
    resultDecimal = nil
    errorMessage = nil
}
```

**Шаг 3.** Заменить метод `memoryRecall()` на новую версию:
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

**Шаг 4.** Проверить, что файл компилируется:
```bash
swift build
```

**Шаг 5.** Проверить сценарий: "10" → M+ → "+" → MR → "=" → результат должен быть 20

---

### 16. Чеклист самопроверки перед завершением

- [ ] Нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()` — отладочный код отсутствует
- [ ] Нет force unwrap (`!`) без обоснованной гарантии — проверено
- [ ] Все методы имеют объявленные типы параметров и возвращаемых значений — `memoryRecall()` без параметров, без возврата
- [ ] MARK-комментарий на русском языке — существующий `// MARK: - Memory operations` (строка 160)
- [ ] Идентификаторы на английском языке — `memoryRecall`, `clearError`, `memStr`, `isTrailingOperator`
- [ ] Нет импортов SwiftUI в вычислительном движке — изменения в ViewModel, не в Engine
- [ ] Все исключения обрабатываются — нет новых throwing-вызовов
- [ ] Нет изменяющих Git-команд — только редактирование файла
- [ ] Все утверждения о коде подтверждены ссылками на файл и строку — верифицировано через `read`
- [ ] Изменения ограничены одним файлом: `Sources/ViewModels/CalculatorViewModel.swift`
- [ ] Используется только существующий метод `isTrailingOperator` — новых методов не добавляется
- [ ] `errorMessage = nil` удалён из конца метода — `clearError()` в начале уже выполняет эту работу

---

### 17. Итого

**Объём изменений:** 1 метод (`memoryRecall()`) в 1 файле (`CalculatorViewModel.swift`). Новых методов, классов, свойств — НЕ добавляется.

**Суть изменения:** Замена безусловного `expression = memoryValue.description` на условную логику: дописывание при наличии trailing-оператора, замена во всех остальных случаях.

**Риск регрессий:** Минимальный — метод `memoryRecall()` не вызывается из других компонентов, единственная точка вызова — кнопка MR в UI.

**Архитектурное соответствие:** Полное — изменение в ViewModel слое, не затрагивает Engine, Services, Views.
