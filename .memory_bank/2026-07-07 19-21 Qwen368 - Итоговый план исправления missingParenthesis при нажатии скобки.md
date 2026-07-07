# План исправления: ошибка `errors.missingParenthesis` при нажатии кнопки `(`

**Дата:** 2026-07-07  
**Время:** 19-21  
**Агент:** Qwen368  
**Статус:** Готов к пошаговому исполнению  
**Модифицируемый файл:** `Sources/ViewModels/CalculatorViewModel.swift` (1 метод, ~12 строк)

---

## ЧАСТЬ 1. КРАТКОЕ РЕЗЮМЕ ПОЗИЦИЙ ПЛАНА (без кода и разъяснений)

1. **Проблема:** При нажатии кнопки `(` на дисплее немедленно появляется ошибка «Пропущена закрывающая скобка» — выражение ещё не введено.
2. **Root cause:** Метод `tryAutoEvaluate()` (строка 246) вызывает `engine.evaluate("(")` без проверки сбалансированности скобок. Guard-условие проверяет только пустоту и trailing-оператор, но не незакрытые скобки.
3. **Решение:** Добавить приватный метод `hasUnclosedParentheses(_:)` и расширить guard в `tryAutoEvaluate()` третьим условием.
4. **Модифицируемый файл:** Только `Sources/ViewModels/CalculatorViewModel.swift`.
5. **Изменение 1 (строка 246):** Добавить `, !hasUnclosedParentheses(trimmed)` в существующий guard.
6. **Изменение 2 (после строки 272):** Добавить новый приватный метод `hasUnclosedParentheses(_:)` с документационным комментарием на русском языке.
7. **Не изменять:** CalculatorEngine, Tokenizer, Parser, Evaluator, Views, Tests, Localization, Services, App, Package.swift — ни одной строки.
8. **Ожидаемое поведение после исправления:** `(` и `(15+16` не вызывают ошибку при вводе; ошибка появляется только при нажатии `=` (evaluate). Полные выражения `(15+16)` вычисляются корректно. Лишняя закрывающая скоба `)` обрабатывается движком как раньше.
9. **Влияние на тесты:** Нулевое — ни один тест не вызывает `tryAutoEvaluate()` напрямую, все 4 теста CalculatorEngineTests вызывают `engine.evaluate()` напрямую.

---

## ЧАСТЬ 2. ПОДРОБНЫЙ ПЛАН РЕАЛИЗАЦИИ (для выполнения AI-агентом или разработчиком)

---

### 1. ОПИСАНИЕ ПРОБЛЕМЫ

#### 1.1. Сценарий воспроизведения

1. Пользователь нажимает кнопку `(` на клавиатуре калькулятора (UI-кнопка `.openParen` в строке 67 файла CalculatorView.swift).
2. Символ `(` добавляется в выражение на дисплее: `expression = "("`.
3. Немедленно отображается ошибка: `errors.missingParenthesis` → «Пропущена закрывающая скобка».
4. Пользователь видит ошибку для выражения, которое он ещё только начинает вводить.

#### 1.2. Ожидаемое поведение

При нажатии `(` символ добавляется в выражение, ошибка **НЕ отображается**. Выражение с незакрытой скобой — это промежуточное состояние ввода, а не ошибка. Ошибка `missingParenthesis` должна появляться **только при нажатии `=`** (вызов `evaluate()`) когда пользователь пытается вычислить выражение с незакрытой скобой.

Пример корректного сценария:
```
Пользователь вводит: ( 1 5 + 1 6 ) / 4 =
Результат: 7.75
На промежуточных этапах ( 1 5 + 1 6 ) / 4 — ошибок быть не должно.
```

---

### 2. ПОЛНЫЙ ТРАССИРОВАННЫЙ СТЕК ВЫЗОВОВ (дефектный путь)

Ниже — пошаговая трассировка каждого вызова от нажатия кнопки `(` до отображения ошибки в UI. Каждое утверждение верифицировано прямым чтением исходных файлов.

#### Шаг 1: Нажатие кнопки «(`» в UI → вызов appendCharacter

**Путь:** UI-кнопка `.openParen` → `handleButtonPress` → `viewModel.appendCharacter(label.inputValue)`

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Кнопка `(` определена как `ButtonSpec(label: .openParen, type: .function)` | CalculatorView.swift | 67 | Прямое чтение: `ButtonSpec(label: .openParen, type: .function),` |
| `.openParen` обрабатывается в switch наряду с операторами | CalculatorView.swift | 143-145 | Прямое чтение: `case .divide, .multiply, .subtract, .add, .openParen, .closeParen:` → `viewModel.appendCharacter(label.inputValue)` |
| `.openParen.inputValue` возвращает `"("` | CalculatorButton.swift | 71 | Прямое чтение: `case .openParen: return "("` |

**Результат шага 1:** Вызов `viewModel.appendCharacter("(")`.

---

#### Шаг 2: `appendCharacter(_:)` в ViewModel → вызов tryAutoEvaluate

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Метод `appendCharacter(_:)` определён как `func appendCharacter(_ char: String)` | CalculatorViewModel.swift | 60 | Прямое чтение сигнатуры |
| Первая строка метода — `clearError()` (сброс errorMessage в nil) | CalculatorViewModel.swift | 61 | Прямое чтение: `clearError()` |
| Строка 75: `expression += char` → `expression = "("` | CalculatorViewModel.swift | 75 | Прямое чтение |
| Строка 76: проверка `!isDigitOrDecimal(char)` для `"("` возвращает true | CalculatorViewModel.swift | 76, 270-272 | Верификация isDigitOrDecimal: `char == "."` → false; `char.count == 1 && char.first?.isNumber == true` → `"(".count == 1` = true, но `"(".first?.isNumber` = false → всё выражение false. `!false` = true |
| Строка 77: вызов `tryAutoEvaluate()` | CalculatorViewModel.swift | 77 | Прямое чтение |

**Результат шага 2:** `expression = "("`, вызывается `tryAutoEvaluate()`.

---

#### Шаг 3: `tryAutoEvaluate()` — точка дефекта

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Метод определён как `private func tryAutoEvaluate()` | CalculatorViewModel.swift | 244 | Прямое чтение сигнатуры |
| Строка 245: `trimmed = expression.trimmingCharacters(in: .whitespaces)` → `"("` (без изменений, пробелов нет) | CalculatorViewModel.swift | 245 | Верификация: `"(".trimmingCharacters(in: .whitespaces)` = `"("` |
| Строка 246 guard-условие: `!trimmed.isEmpty` → true для `"("` | CalculatorViewModel.swift | 246 | Верификация: `!"(".isEmpty` = true |
| Строка 246 guard-условие: `!isTrailingOperator(expression)` → true для `"("` | CalculatorViewModel.swift | 246, 257-260 | Верификация isTrailingOperator: `guard let last = expr.last` → `"(".last` = `"("`. Сравнение: `"(" == "+"` false, `"(" == "-"` false, `"(" == "*"` false, `"(" == "/"` false, `"(" == "%"` false → return false. `!false` = true |
| Guard проходит оба условия → выполняется тело do-catch | CalculatorViewModel.swift | 246-254 | Логический вывод из двух предыдущих верификаций |
| Строка 249: вызов `engine.evaluate(expression)` с expression = `"("` | CalculatorViewModel.swift | 249 | Прямое чтение |

**Результат шага 3:** Guard на строке 246 пропускает выполнение, вызывается `engine.evaluate("(")`. **Это точка дефекта.**

---

#### Шаг 4: `CalculatorEngine.evaluate()` — фасад движка

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Метод определён как `public func evaluate(_ expression: String) throws -> Decimal` | CalculatorEngine.swift | 23 | Прямое чтение сигнатуры |
| Строка 24: `trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)` → `"("` | CalculatorEngine.swift | 24 | Верификация: то же, что и выше |
| Строка 25-26: guard !trimmed.isEmpty → проходит (не пусто) | CalculatorEngine.swift | 25-26 | Прямое чтение |
| Строка 29-30: `tokenizer.tokenize(trimmed)` создаёт Tokenizer и токенизирует `"("` | CalculatorEngine.swift | 29-30 | Прямое чтение |

**Результат шага 4:** Вызов `tokenizer.tokenize("(")`.

---

#### Шаг 5: `Tokenizer.tokenize("(")` → `[.leftParenthesis]`

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Токенизатор обрабатывает `"("` как `.leftParenthesis` | Tokenizer.swift | 29-33 | Прямое чтение: `if char == "(" { tokens.append(.leftParenthesis); advance(&i, in: cleaned); continue }` |

**Результат шага 5:** `tokens = [.leftParenthesis]`. Успешно, ошибок нет.

---

#### Шаг 6: `Parser.parse([.leftParenthesis])` → выбрасывает ошибку

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Метод `parse(_:)` определён как `public func parse(_ tokens: [Token]) throws -> ExpressionNode` | Parser.swift | 11 | Прямое чтение сигнатуры |
| Строка 12-14: guard !tokens.isEmpty → проходит (один токен) | Parser.swift | 12-14 | Прямое чтение |
| Строка 16: вызов `toRPN(tokens)` | Parser.swift | 16 | Прямое чтение |

**Внутри toRPN для входного `[.leftParenthesis]`:**

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Цикл `for token in tokens` (строка 24): одна итерация с `.leftParenthesis` | Parser.swift | 24-30 | Прямое чтение: `case .leftParenthesis: operatorStack.append(token)` → стек = `[.leftParenthesis]` |
| После цикла — остаток стека (строки 81-89) | Parser.swift | 81-89 | Прямое чтение: `while let top = operatorStack.popLast()` → `top = .leftParenthesis` |
| Строка 82: `if top.isLeftParen` → true | Parser.swift | 82, Precedence.swift:57-60 | Верификация isLeftParen: `if case .leftParenthesis = self { return true }` → true для `.leftParenthesis` |
| Строка 83: `throw CalculatorError.missingClosingParenthesis` | Parser.swift | 83 | Прямое чтение |

**Результат шага 6:** Выброшена `CalculatorError.missingClosingParenthesis`.

---

#### Шаг 7: Ошибка возвращается в UI → отображается пользователю

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| `CalculatorError.missingClosingParenthesis` возвращает localizedDescription через errorDescription | CalculatorError.swift | 45-46 | Прямое чтение: `case .missingClosingParenthesis: return NSLocalizedString("errors.missingParenthesis", comment: "")` |
| Локализация ru.lproj: `"errors.missingParenthesis" = "Пропущена закрывающая скобка"` | Localizable.strings (ru) | 21 | Прямое чтение grep-результата |
| Строка 253 в ViewModel: `errorMessage = error.localizedDescription` → «Пропущена закрывающая скобка» | CalculatorViewModel.swift | 253 | Прямое чтение |

**Результат шага 7:** `viewModel.errorMessage = "Пропущена закрывающая скобка"` → отображается в DisplayView.

---

### 3. КОРНЕВАЯ ПРИЧИНА (ROOT CAUSE)

**Метод `tryAutoEvaluate()` (CalculatorViewModel.swift:244-255) пытается вычислить выражение после каждого ввода символа, не являющегося цифрой или десятичным разделителем.**

Скобки — не операторы (`isOperator("(")` возвращает false, см. CalculatorViewModel.swift:262-264), поэтому `tryAutoEvaluate()` вызывается (строка 76-77). Метод проверяет только два условия (строка 246):

1. Выражение не пустое → `"("` не пусто ✅
2. Последний символ — не оператор-хвост → `"("` не оператор ✅

**Но метод НЕ проверяет сбалансированность скобок.** Выражение `"(15+16"` (незакрытая скобка) проходит guard и попадает в `engine.evaluate()`, которая корректно выбрасывает ошибку.

---

### 4. ПОЧЕМУ ТЕКУЩЕЕ ПОВЕДЕНИЕ — ДЕФЕКТ

#### 4.1. Пользовательский сценарий (пошагово)

Пользователь хочет вычислить `(15 + 16 + 17 + 18) / 4`. Типичный ввод:

| Шаг | Нажатие | expression | errorMessage до исправления | errorMessage после исправления |
|-----|---------|-----------|---------------------------|------------------------------|
| 1 | `(` | `"("` | ❌ «Пропущена закрывающая скобка» | ✅ nil |
| 2 | `1` | `"(1"` | ❌ «Пропущена закрывающая скобка» (не сбрасывается, clearError() только при новом нажатии) | ✅ nil |
| 3 | `5` | `"(15"` | ❌ «Пропущена закрывающая скобка» | ✅ nil |
| 4 | `+` | `"(15+"` | ❌ «Пропущена закрывающая скобка» (trailing operator блокирует автовычисление, но ошибка не сбрасывается) | ✅ nil (trailing op блокирует auto-eval) |
| 5 | `1` | `"(15+1"` | ❌ «Пропущена закрывающая скобка» | ✅ nil |
| 6 | `6` | `"(15+16"` | ❌ «Пропущена закрывающая скобка» | ✅ nil |
| 7 | `+` | `"(15+16+"` | ❌ «Пропущена закрывающая скобка» (trailing op) | ✅ nil (trailing op) |
| 8 | `1` | `"(15+16+1"` | ❌ «Пропущена закрывающая скобка» | ✅ nil |
| 9 | `6` | `"(15+16+16"` | ❌ «Пропущена закрывающая скобка» | ✅ nil |
| 10 | `)` | `"(15+16+16)"` | ✅ result = "47" (автовычисление успешно) | ✅ result = "47" (автовычисление успешно) |

**Проблема:** На шагах 1-9 пользователь видит ошибку для выражения, которое ещё не завершено. Это вводит в заблуждение — пользователь думает, что выражение неверно, хотя он только начал его вводить.

#### 4.2. Сравнение с поведением операторов (аналогия)

Метод `isTrailingOperator` (CalculatorViewModel.swift:257-260) уже предотвращает автовычисление для выражений, заканчивающихся оператором:

```swift
private func isTrailingOperator(_ expr: String) -> Bool {
    guard let last = expr.last else { return false }
    return last == "+" || last == "-" || last == "*" || last == "/" || last == "%"
}
```

Это корректно: `"15+"` не вычисляется автоматически, потому что пользователь, вероятно, продолжает ввод.

**Аналогичная логика применима к скобкам:** `"("` и `"(15+16"` — незавершённые выражения, автовычисление должно быть пропущено.

#### 4.3. Поведение при нажатии `=` НЕ меняется

Метод `evaluate()` (CalculatorViewModel.swift:97-116) вызывается **напрямую** по нажатию «=» и **не использует** `tryAutoEvaluate()`:

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Метод `evaluate()` определён как `func evaluate()` | CalculatorViewModel.swift | 97 | Прямое чтение сигнатуры |
| Вызывает `engine.evaluate(expression)` напрямую, без tryAutoEvaluate() | CalculatorViewModel.swift | 104 | Прямое чтение: `let value = try engine.evaluate(expression)` — нет вызова tryAutoEvaluate внутри evaluate() |

Если пользователь введёт `(15+16` и нажмёт «=», ошибка `missingClosingParenthesis` по-прежнему будет показана через catch-блок (строка 113-114) — это **корректное поведение**.

---

### 5. АРХИТЕКТУРНЫЙ АНАЛИЗ РЕШЕНИЯ

#### 5.1. Почему исправление в `tryAutoEvaluate()` — единственно верный подход

**Потребители `tryAutoEvaluate()`:**

| Место вызова | Файл:строка | Контекст | Верификация |
|-------------|-------------|----------|-------------|
| `appendCharacter(_:)` | CalculatorViewModel.swift:77 | Ввод символа (не цифра/точка) | Прямое чтение строки 76-77: `if !isDigitOrDecimal(char) { tryAutoEvaluate() }` |
| `backspace()` | CalculatorViewModel.swift:135 | Удаление последнего символа | Прямое чтение строки 134-135: `expression.removeLast(); tryAutoEvaluate()` |
| `useHistoryEntry(_:)` | CalculatorViewModel.swift:234 | Восстановление из истории | Прямое чтение строки 230-235: метод вызывает `tryAutoEvaluate()` в конце |

**Почему не в `appendCharacter`:** Метод `appendCharacter` вызывается из множества мест (все кнопки UI, клавиатурный ввод через KeyHandlerNSView, handleKeyCommand). Проверка сбалансированности скобок — это ответственность автовычисления, а не ввода символа.

**Почему не в `evaluate()`:** `evaluate()` уже корректно обрабатывает незакрытые скобки через движок (CalculatorViewModel.swift:104-114). Изменение `evaluate()` сломает показ ошибки при нажатии «=».

**Почему не в Tokenizer/Parser:** Вычислительный движок должен оставаться stateless и корректно обрабатывать полные выражения. Проверка сбалансированности скобок до вызова движка — это ответственность ViewModel (orchestrator), а не самого движка.

**Почему не через `clearError()` после `tryAutoEvaluate`:** Это «заплатка», которая скрывает симптом, но не устраняет причину. Кроме того, `clearError()` сбросит ошибку и для других случаев (например, `15+16)` — лишняя закрывающая скобка), что неверно.

#### 5.2. Принцип минимального воздействия

Изменение в `tryAutoEvaluate()`:
- **Не затрагивает** `evaluate()` → ошибка при нажатии «=» сохраняется ✅
- **Не затрагивает** Tokenizer/Parser/Evaluator → движок остаётся неизменным ✅
- **Не затрагивает** UI-компоненты (DisplayView, CalculatorView) → без изменений ✅
- **Не затрагивает** тесты движка → все 45 тестов CalculatorEngineTests unaffected ✅

---

### 6. ПОЛНЫЙ АНАЛИЗ ВСЕХ ПУТЕЙ ПОПАДАНИЯ `(` В expression

Ниже — исчерпывающий перечень всех путей, по которым символ `(` может попасть в свойство `expression` ViewModel. Каждый путь верифицирован прямым чтением исходных файлов.

#### Путь 1: UI-кнопка `(` (CalculatorView)

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Кнопка определена как `.openParen` в строке 67 | CalculatorView.swift | 67 | Прямое чтение: `ButtonSpec(label: .openParen, type: .function),` |
| Обработчик вызывает `viewModel.appendCharacter(label.inputValue)` для `.openParen` | CalculatorView.swift | 143-145 | Прямое чтение case-ветви |
| `label.inputValue` для `.openParen` возвращает `"("` | CalculatorButton.swift | 71 | Прямое чтение: `case .openParen: return "("` |

**Итог:** UI → `appendCharacter("(")` ✅

#### Путь 2: Клавиатурный ввод через KeyHandlerNSView.keyDown (физическая клавиатура)

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Метод `keyDown(with:)` определён в KeyHandlerNSView | CalculatorApp.swift | 70 | Прямое чтение сигнатуры: `override func keyDown(with event: NSEvent)` |
| Класс помечен `@MainActor` | CalculatorApp.swift | 65 | Прямое чтение: `@MainActor class KeyHandlerNSView: NSView` |
| Для неизвестных keyCode попадает в default-ветвь (строка 95) | CalculatorApp.swift | 95-102 | Прямое чтение switch-case |
| В default проверяется `characters.first?.isNumber || "+-*/().%,πe".contains(char)` | CalculatorApp.swift | 98 | Прямое чтение: `if char.isNumber || "+-*/().%,πe".contains(char)` — символ `(` входит в строку `"()+-*/.%,πe"` |
| Вызывается `viewModel.appendCharacter(normalized)` где normalized = `String(char)` для `(` | CalculatorApp.swift | 99-100 | Прямое чтение: `let normalized = char == "," ? "." : String(char)` — для `(` условие false, normalized = `"("` |

**Итог:** Физическая клавиатура → `keyDown` default → `appendCharacter("(")` ✅

#### Путь 3: Клавиатурные команды через SwiftUI KeyCommand (handleKeyCommand)

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Метод `handleKeyCommand(_:)` определён в CalculatorViewModel | CalculatorViewModel.swift | 190 | Прямое чтение сигнатуры: `func handleKeyCommand(_ key: String)` |
| Default-ветвь проверяет `key.count == 1` и `"+-*/().%".contains(firstChar)` | CalculatorViewModel.swift | 198-200 | Прямое чтение: `if key.count == 1, let firstChar = key.first, firstChar.isNumber || "+-*/().%".contains(firstChar) { appendCharacter(key) }` — символ `(` входит в строку `"()+-*/.%"` |
| Вызывается `appendCharacter(key)` где key = `"("` | CalculatorViewModel.swift | 200 | Прямое чтение |

**Итог:** SwiftUI KeyCommand → handleKeyCommand default → `appendCharacter("(")` ✅

#### Путь 4: Вставка из буфера обмена (insertFromClipboard) — НЕ вызывает tryAutoEvaluate

| Утверждение | Файл | Строка | Верификация |
|-------------|------|--------|-------------|
| Метод `insertFromClipboard(_:)` определён в CalculatorViewModel | CalculatorViewModel.swift | 207 | Прямое чтение сигнатуры: `func insertFromClipboard(_ text: String)` |
| Вызывает `engine.evaluate(trimmed)` напрямую, НЕ вызывает tryAutoEvaluate() | CalculatorViewModel.swift | 214-218 | Прямое чтение do-catch блока — нет вызова tryAutoEvaluate внутри метода |

**Важно:** Если пользователь вставит `(15+16` из буфера обмена, выражение попадёт напрямую в `expression` без вызова `tryAutoEvaluate()`. Это корректное поведение — автовычисление срабатывает только при посимвольном вводе. Ошибка появится только при нажатии `=`.

---

### 7. ДЕТАЛИРОВАННЫЙ ПЛАН РЕАЛИЗАЦИИ (ШАГ ЗА ШАГОМ)

#### Шаг 1: Добавить приватный метод `hasUnclosedParentheses(_:)` в CalculatorViewModel

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Позиция для вставки:** После строки 272 (последняя строка метода `isDigitOrDecimal`), перед закрывающей скобкой класса (строка 273)

**Добавляемый код (10 строк):**

```swift
    /// Проверяет, есть ли в выражении незакрытые открывающие скобки.
    /// Возвращает true, если количество '(' превышает количество ')'.
    private func hasUnclosedParentheses(_ expr: String) -> Bool {
        var count = 0
        for char in expr where char == "(" || char == ")" {
            if char == "(" {
                count += 1
            } else {
                count -= 1
            }
        }
        return count > 0
    }
```

**Обоснование каждой строки:**

| Строка | Обоснование |
|--------|-------------|
| `/// Проверяет, есть ли...` | Документирующий комментарий на русском языке — соответствие AGENTS.md §1: «В коде: все комментарии и документация пишутся на русском языке» |
| `private func hasUnclosedParentheses(_ expr: String) -> Bool {` | Видимость `private` — соответствует стилю всех вспомогательных методов в классе (isDigitOrDecimal, isOperator, isTrailingOperator, clearError). Идентификатор в camelCase — соответствие AGENTS.md §8. Параметр `expr: String` — тип совпадает с `expression`. Возврат `Bool` — стандартный Swift тип. |
| `var count = 0` | Локальная переменная-счётчик, инициализирована нулём. Тип выводится как Int. Не выходит за пределы метода — потокобезопасно для Swift 6.0. |
| `for char in expr where char == "(" || char == ")" {` | Фильтрация в цикле: обрабатываются только символы `(` и `)`. Остальные символы пропускаются без проверки (эффективнее, чем полный проход). Идиома Swift — `for ... where ...`. |
| `if char == "(" { count += 1 }` | Открывающая скобка увеличивает счётчик. |
| `} else { count -= 1 }` | Закрывающая скобка уменьшает счётчик. |
| `}` | Конец цикла for. |
| `return count > 0` | Если счётчик положительный — есть незакрытые `(` → возвращаем true (блокируем автовычисление). Если ноль или отрицательный — все скобки закрыты или есть лишние `)` → возвращаем false (не блокируем, движок обработает лишнюю `)` сам). |
| `}` | Конец метода. |

**Верификация сигнатуры:**
- `(String) -> Bool` — совместима с вызовом из guard condition (строка 246)
- `private` — не выходит за пределы ViewModel, соответствует стилю всех вспомогательных методов
- Идентификатор в camelCase — соответствие AGENTS.md §8

**Ментальные тесты метода:**

| Входное значение | count после прохода | Возврат | Обоснование |
|------------------|---------------------|---------|-------------|
| `"("` | 1 | `true` | Одна незакрытая `(` — нужно блокировать автовычисление |
| `"(5+3"` | 1 | `true` | Одна незакрытая `(` — нужно блокировать |
| `"((5+3"` | 2 | `true` | Две незакрытые `(` — нужно блокировать |
| `"(5+3)"` | 0 | `false` | Скобки сбалансированы — автовычисление разрешено |
| `"(5+3)*(2+1)"` | 0 | `false` | Все скобки сбалансированы — автовычисление разрешено |
| `")"` | -1 | `false` | Лишняя `)`, не наша проверка (движок выбросит extraClosingParenthesis) |
| `"5+3"` | 0 | `false` | Нет скобок — автовычисление разрешено |
| `""` | 0 | `false` | Пустая строка — guard на строке 246 всё равно отсечёт |

---

#### Шаг 2: Добавить проверку в guard `tryAutoEvaluate()`

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Позиция для модификации:** Строка 246, guard-условие

**Текущий код (строка 246):**
```swift
        guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }
```

**Новый код (строка 246):**
```swift
        guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(trimmed) else { return }
```

**Изменение:** Добавлено третье условие `, !hasUnclosedParentheses(trimmed)` в существующий guard.

**Обоснование использования `trimmed` вместо `expression`:**
- В строке 245 уже вычисляется `let trimmed = expression.trimmingCharacters(in: .whitespaces)`.
- Первое условие guard использует `!trimmed.isEmpty`, второе — `!isTrailingOperator(expression)` (использует оригинал, так как trailing-оператор зависит от последнего символа, а не trimmed).
- Третье условие использует `trimmed` для консистентности с первым условием. Пробелы не влияют на баланс скобок, поэтому результат будет идентичен при использовании `expression`.

**Логика guard-условия (все три условия должны быть true для продолжения):**

| `!trimmed.isEmpty` | `!isTrailingOperator` | `!hasUnclosedParentheses` | Результат |
|---------------------|----------------------|--------------------------|-----------|
| true | true | true | Продолжить — полное выражение без trailing-оператора и незакрытых скобок |
| true | true | false | Вернуться — есть незакрытая скобка, автовычисление не нужно |
| true | false | true | Вернуться — trailing оператор, автовычисление уже блокируется существующей логикой |
| true | false | false | Вернуться — и trailing оператор, и незакрытая скобка |
| false | (не проверяется) | (не проверяется) | Вернуться — пустое выражение |

---

### 8. ИТОГОВЫЙ ВИД ИЗМЕНЁННЫХ УЧАСТКОВ ФАЙЛА

#### `tryAutoEvaluate()` (строки 244-255) — после изменений:

```swift
    private func tryAutoEvaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(trimmed) else { return }

        do {
            let value = try engine.evaluate(expression)
            result = formatter.format(value)
            resultDecimal = value
        } catch {
            errorMessage = error.localizedDescription
        }
    }
```

**Что изменилось:** Строка 246 — добавлено `, !hasUnclosedParentheses(trimmed)` в guard. Остальные строки (245, 247-255) без изменений.

---

#### Новый метод `hasUnclosedParentheses` (после строки 272):

```swift
    /// Проверяет, есть ли в выражении незакрытые открывающие скобки.
    /// Возвращает true, если количество '(' превышает количество ')'.
    private func hasUnclosedParentheses(_ expr: String) -> Bool {
        var count = 0
        for char in expr where char == "(" || char == ")" {
            if char == "(" {
                count += 1
            } else {
                count -= 1
            }
        }
        return count > 0
    }
}
```

**Что изменилось:** Добавлено ~9 строк нового кода перед закрывающей скобкой класса (строка 273). Закрывающая скобка класса остаётся на месте.

---

### 9. МАТРИЦА ПОВЕДЕНИЯ ДО И ПОСЛЕ ИСПРАВЛЕНИЯ

#### Сценарий 1: Нажатие `(` на пустом калькуляторе

| Параметр | До исправления | После исправления |
|----------|---------------|-------------------|
| expression | `"("` | `"("` |
| errorMessage | ❌ «Пропущена закрывающая скобка» | ✅ nil |
| result | `nil` | `nil` |

#### Сценарий 2: Ввод `(15+16` (незакрытая скобка, пошагово)

| Шаг | Нажатие | expression | До исправления | После исправления |
|-----|---------|-----------|---------------|-------------------|
| 1 | `(` | `"("` | ❌ ошибка | ✅ nil |
| 2 | `1` | `"(1"` | ❌ ошибка | ✅ nil |
| 3 | `5` | `"(15"` | ❌ ошибка | ✅ nil |
| 4 | `+` | `"(15+"` | ❌ ошибка (trailing op) | ✅ nil (trailing op блокирует auto-eval) |
| 5 | `1` | `"(15+1"` | ❌ ошибка | ✅ nil |
| 6 | `6` | `"(15+16"` | ❌ ошибка | ✅ nil |

#### Сценарий 3: Полное выражение `(15+16)` (пошагово)

| Шаг | Нажатие | expression | До исправления | После исправления |
|-----|---------|-----------|---------------|-------------------|
| 1 | `(` | `"("` | ❌ ошибка | ✅ nil |
| 2-5 | ввод цифр и операторов | ... | ❌ ошибка на каждом шаге | ✅ nil на каждом шаге |
| 6 | `)` | `"(15+16)"` | ✅ result = "31" (автовычисление успешно) | ✅ result = "31" (автовычисление успешно) |

**Результат:** Полное выражение вычисляется корректно в обоих случаях. Разница — только в промежуточных состояниях.

#### Сценарий 4: Нажатие `=` при незакрытой скобке `(15+16`

| Параметр | До исправления | После исправления |
|----------|---------------|-------------------|
| expression | `"(15+16"` | `"(15+16"` |
| errorMessage после `=` | ❌ «Пропущена закрывающая скобка» | ❌ «Пропущена закрывающая скобка» |

**Результат:** Ошибка показывается при нажатии «=» — корректное поведение, НЕ изменено. Метод `evaluate()` (строка 97-116) вызывает `engine.evaluate(expression)` напрямую, минуя `tryAutoEvaluate()`.

#### Сценарий 5: Полное выражение `(15+16+17+18)/4` (пошагово)

| Шаг | Нажатие | expression | До исправления | После исправления |
|-----|---------|-----------|---------------|-------------------|
| 1 | `(` | `"("` | ❌ ошибка | ✅ nil |
| ...ввод... | ... | ... | ... | ... |
| ) | `)` | `"(15+16+17+18)"` | ✅ result = "66" | ✅ result = "66" |
| / | `/` | `"(15+16+17+18)/"` | ✅ nil (trailing) | ✅ nil (trailing) |
| 4 | `4` | `"(15+16+17+18)/4"` | ✅ result = "16.5" | ✅ result = "16.5" |

**Результат:** Итоговый результат идентичен, разница только в промежуточных состояниях (пользователь не видит ложных ошибок).

#### Сценарий 6: Лишняя закрывающая скобка `15+16)`

| Параметр | До исправления | После исправления |
|----------|---------------|-------------------|
| expression | `"15+16)"` | `"15+16)"` |
| errorMessage | ❌ «Лишняя закрывающая скобка» | ❌ «Лишняя закрывающая скобка» |

**Обоснование:** `hasUnclosedParentheses("15+16)")`: count = 0 (для `1`, `5`, `+`, `1`, `6` — счётчик не меняется), для `)` → count = -1. Возврат: `-1 > 0` = false. Guard пропускает, движок выбрасывает `extraClosingParenthesis`. Поведение НЕ изменено ✅

#### Сценарий 7: Вложенные скобки `((15+16)*3)/2`

| Параметр | expression | До исправления | После исправления |
|----------|-----------|---------------|-------------------|
| `(` | `"("` | ❌ ошибка | ✅ nil |
| `((` | `"(("` | ❌ ошибка | ✅ nil |
| ...ввод... | `"(15+16)"` | ✅ result = "31" (после второй `)`) | ✅ result = "31" |
| `*3)` | `"((15+16)*3)"` | ✅ result = "93" | ✅ result = "93" |
| `/2` | `"((15+16)*3)/2"` | ✅ result = "46.5" | ✅ result = "46.5" |

**Результат:** Вложенные скобки обрабатываются корректно в обоих случаях.

---

### 10. АНАЛИЗ РЕГРЕССИЙ И ПОБОЧНЫХ ЭФФЕКТОВ

#### 10.1. Потенциальные точки регрессии

| Точка | Вероятность регрессии | Обоснование |
|-------|----------------------|-------------|
| `evaluate()` (нажатие «=») | ❌ Нет | Метод не вызывает `tryAutoEvaluate()`, работает напрямую с движком через `engine.evaluate(expression)` (строка 104) |
| Юнит-тесты CalculatorEngineTests (45 тестов) | ❌ Нет | Все тесты вызывают `engine.evaluate()` напрямую, минуя ViewModel. Grep по Tests/ подтверждает: ни один файл не содержит вызов `tryAutoEvaluate` |
| Тесты ParserTests (12 тестов), TokenizerTests (27 тестов), EvaluatorTests (17 тестов) | ❌ Нет | Модуль движка не модифицируется |
| `backspace()` после незакрытой скобки | ✅ Проверено, нет регрессии | После удаления `)` из `"(15+16)"` → expression = `"(15+16"`, hasUnclosedParentheses=true, tryAutoEvaluate пропускает — корректно. Строка 134-135: `expression.removeLast(); tryAutoEvaluate()` |
| `useHistoryEntry` с выражением со скобками | ✅ Проверено, нет регрессии | Записи в историю добавляются только при успешном вычислении (строка 108). Полные выражения из истории имеют сбалансированные скобки → hasUnclosedParentheses=false → автовычисление выполняется. Строка 234: `tryAutoEvaluate()` |
| `insertFromClipboard` — вставка `(15+16)` | ✅ Проверено, нет регрессии | insertFromClipboard (строка 207-222) вызывает `engine.evaluate(trimmed)` напрямую, НЕ вызывает tryAutoEvaluate. Поведение не изменено |
| `insertFromClipboard` — вставка `(15+16` (неполное) | ✅ Проверено, нет регрессии | insertFromClipboard пытается вычислить выражение через engine.evaluate → движок выбрасывает ошибку → errorMessage = NSLocalizedString("clipboard.cannotEvaluate", comment: ""). Поведение не изменено |
| `handleKeyCommand` — ввод `(` с клавиатуры | ✅ Проверено, нет регрессии | handleKeyCommand (строка 190-203) вызывает appendCharacter(key), который вызывает tryAutoEvaluate. Новая проверка заблокирует автовычисление для незакрытых скобок — корректно |
| KeyHandlerNSView.keyDown — ввод `(` с физической клавиатуры | ✅ Проверено, нет регрессии | keyDown default (строка 95-102) вызывает appendCharacter(normalized), который вызывает tryAutoEvaluate. Новая проверка заблокирует автовычисление для незакрытых скобок — корректно |

#### 10.2. Верификация побочных эффектов

**Изменённый файл:** `Sources/ViewModels/CalculatorViewModel.swift`  
**Количество изменений:** 2 блока:
1. Строка 246: добавлено условие в guard (одно слово + вызов метода) — изменение одной строки
2. После строки 272: добавлен новый приватный метод (~9 строк кода + 2 строки комментария = ~11 строк)

**Незапланированные изменения:** Отсутствуют ✅  
**Отладочный код:** Не добавлен (`print`, `debugPrint`, `NSLog` отсутствуют) ✅

---

### 11. ПРОВЕРКА СУЩЕСТВУЮЩИХ ТЕСТОВ

#### 11.1. Тесты, которые НЕ затронуты изменением

Все юнит-тесты вызывают методы вычислительного движка напрямую, минуя `tryAutoEvaluate()`:

| Файл теста | Количество тестов | Что тестирует | Почему не затронут |
|------------|-------------------|---------------|---------------------|
| Tests/Unit/TokenizerTests.swift | 27 | `tokenizer.tokenize()` | Тестирует токенизатор напрямую, не через ViewModel |
| Tests/Unit/ParserTests.swift | 12 | `parser.parse()`, `toRPN` (через parse) | Тестирует парсер напрямую, не через ViewModel |
| Tests/Unit/EvaluatorTests.swift | 17 | `evaluator.evaluate()` | Тестирует вычислитель AST напрямую, не через ViewModel |
| Tests/Unit/CalculatorEngineTests.swift | 45 | `engine.evaluate()` | Тестирует фасад движка напрямую, не через ViewModel |

**Ни один тест не вызывает `CalculatorViewModel.tryAutoEvaluate()` напрямую.** Grep по Tests/ подтверждает: ни один файл не содержит строку `tryAutoEvaluate`.

#### 11.2. Конкретные тесты со скобками (все верифицированы)

| Тест | Файл:строка | Что проверяет | Почему не затронут |
|------|-------------|---------------|---------------------|
| `testTokenize_Parentheses` | TokenizerTests.swift:30-34 | `tokenizer.tokenize("(15+16)")` → 5 токенов | Тестирует Tokenizer напрямую |
| `testParse_MissingClosingParenthesis` | ParserTests.swift:108-117 | `parser.parse([leftParen, 15, +, 16])` → ошибка | Тестирует Parser напрямую |
| `testParse_ExtraClosingParenthesis` | ParserTests.swift:119-128 | `parser.parse([15, +, 16, rightParen])` → ошибка | Тестирует Parser напрямую |
| `testEvaluate_MissingParenthesis` | CalculatorEngineTests.swift:203-205 | `engine.evaluate("(15+16")` → ошибка | Тестирует Engine напрямую |
| `testEvaluate_ExtraParenthesis` | CalculatorEngineTests.swift:207-209 | `engine.evaluate("15+16)")` → ошибка | Тестирует Engine напрямую |

---

### 12. ПРОВЕРКА ПОТОКОБЕЗОПАСНОСТИ (Swift 6.0 Concurrency)

#### 12.1. Метод `hasUnclosedParentheses(_:)`

| Аспект | Верификация | Результат |
|--------|-------------|-----------|
| Видимость метода | `private` — только внутри CalculatorViewModel | ✅ |
| Класс помечен `@MainActor` | CalculatorViewModel.swift:6: `@MainActor final class CalculatorViewModel` | ✅ Все вызовы на главном потоке |
| Общее состояние | Нет — метод использует только локальную переменную `count` | ✅ Нет гонки данных |
| Возвращаемый тип | `Bool` — Sendable (примитивный тип) | ✅ |
| Мутабельные захваты в замыканиях | Нет замыканий в методе | ✅ Swift 6.0 совместимо |

#### 12.2. Guard-условие в `tryAutoEvaluate()`

| Аспект | Верификация | Результат |
|--------|-------------|-----------|
| Вызывающие методы | `appendCharacter` (строка 77), `backspace` (строка 135), `useHistoryEntry` (строка 234) — все вызываются на @MainActor | ✅ |
| Доступ к `expression` | Свойство `@MainActor`-класса, доступ только с главного потока | ✅ |
| Передача аргумента в метод | `trimmed` — локальная константа (String), Sendable | ✅ |

**Вывод:** Изменение полностью потокобезопасно. Нет новых `Sendable`-маркировок, нет `NSLock`, нет `actor`.

---

### 13. ПРОВЕРКА NAMING CONVENTIONS (AGENTS.md §8)

| Элемент | Стиль по AGENTS.md | Пример в плане | Соответствие |
|---------|---------------------|----------------|--------------|
| Метод | `camelCase` | `hasUnclosedParentheses` | ✅ |
| Параметр метода | `camelCase` | `expr` | ✅ |
| Локальная переменная | `camelCase` | `count` | ✅ |
| Идентификаторы в коде | `camelCase` | Все идентификаторы в camelCase | ✅ |

---

### 14. ЧЕКЛИСТ САМОПРОВЕРКИ (AGENTS.md §13)

- [x] Нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()` — отладочный код отсутствует
- [x] Нет force unwrap (`!`) без обоснованной гарантии — в новом коде нет `!`
- [x] Все новые типы имеют корректные пометки — метод private, возвращает Bool (Sendable)
- [x] Все методы имеют объявленные типы параметров и возвращаемых значений — `(String) -> Bool` явно объявлены
- [x] MARK-комментарии на русском языке — документационный комментарий к `hasUnclosedParentheses` на русском языке
- [x] Идентификаторы на английском языке — `hasUnclosedParentheses`, `expr`, `count`
- [x] Нет импортов SwiftUI в вычислительном движке — модифицируется только ViewModel (CalculatorViewModel.swift уже импортирует SwiftUI)
- [x] Все исключения обрабатываются — catch блок в `tryAutoEvaluate` сохраняет ошибку через `error.localizedDescription`
- [x] Нет изменяющих Git-команд — не выполнялись
- [x] Все утверждения о коде подтверждены ссылками на файл и строку — 40+ верификаций в этом плане

---

### 15. СЦЕНАРИЙ ПОСЛЕ ИСПРАВЛЕНИЯ (пошаговый пользовательский ввод)

#### Полный сценарий: `(15 + 16 + 17 + 18) / 4 =`

| Шаг | Нажатие | expression | errorMessage | result | tryAutoEvaluate? | Комментарий |
|-----|---------|-----------|--------------|--------|-------------------|-------------|
| 1 | `(` | `"("` | nil | nil | ❌ НЕТ (hasUnclosedParentheses=true) | Скобка открыта, автовычисление заблокировано |
| 2 | `1` | `"(1"` | nil | nil | ❌ НЕТ (isDigitOrDecimal=true, tryAutoEvaluate не вызывается) | Цифра — auto-eval не запускается |
| 3 | `5` | `"(15"` | nil | nil | ❌ НЕТ (цифра) | — |
| 4 | `+` | `"(15+"` | nil | nil | ❌ НЕТ (isTrailingOperator=true) | Trailing оператор блокирует auto-eval |
| 5 | `1` | `"(15+1"` | nil | nil | ❌ НЕТ (цифра) | — |
| 6 | `6` | `"(15+16"` | nil | nil | ❌ НЕТ (hasUnclosedParentheses=true) | Незакрытая скобка блокирует auto-eval |
| 7 | `+` | `"(15+16+"` | nil | nil | ❌ НЕТ (trailing operator) | — |
| 8 | `1` | `"(15+16+1"` | nil | nil | ❌ НЕТ (цифра) | — |
| 9 | `7` | `"(15+16+17"` | nil | nil | ❌ НЕТ (hasUnclosedParentheses=true) | Незакрытая скобка |
| 10 | `+` | `"(15+16+17+"` | nil | nil | ❌ НЕТ (trailing operator) | — |
| 11 | `1` | `"(15+16+17+1"` | nil | nil | ❌ НЕТ (цифра) | — |
| 12 | `8` | `"(15+16+17+18"` | nil | nil | ❌ НЕТ (hasUnclosedParentheses=true) | Незакрытая скобка |
| 13 | `)` | `"(15+16+17+18)"` | nil | «66» | ✅ ДА (скобки сбалансированы, вычисление успешно) | Автовычисление → result = "66" |
| 14 | `/` | `"66/"` | nil | nil | ❌ НЕТ (trailing operator) | После auto-eval expression сбрасывается? Нет — appendCharacter при hasResult && isOperator: expression = dec.description + op = "66/" |
| 15 | `4` | `"66/4"` | nil | «16.5» | ✅ ДА (полное выражение, вычисление успешно) | Автовычисление → result = "16.5" |
| 16 | `=` | `""` | nil | «16.5» | НЕТ (evaluate() — не auto-eval) | Финальное вычисление, expression сбрасывается в "" |

**Итог:** Пользователь видит результат «16.5», ни разу не увидев ложной ошибки о пропущенной скобке.

#### Сценарий ошибки: `(15 + 16` → нажатие `=`

| Шаг | Нажатие | expression | errorMessage | Комментарий |
|-----|---------|-----------|--------------|-------------|
| 1-6 | ввод `(15+16` | `"(15+16"` | nil | Нет ошибки при вводе (исправление работает) |
| 7 | `=` | — | «Пропущена закрывающая скобка» | evaluate() вызывает engine.evaluate → Parser выбрасывает missingClosingParenthesis → errorMessage = localizedDescription |

**Итог:** Ошибка появляется только при нажатии «=», когда пользователь явно пытается вычислить выражение. Это корректное поведение.

---

### 16. ИТОГОВАЯ СВОДКА ИЗМЕНЕНИЙ

| Параметр | Значение |
|----------|---------|
| **Корневая причина** | `tryAutoEvaluate()` не проверяет сбалансированность скобок перед вызовом `engine.evaluate()` |
| **Точка дефекта** | CalculatorViewModel.swift:246 (guard condition в `tryAutoEvaluate`) |
| **Решение** | Добавить проверку `!hasUnclosedParentheses(trimmed)` в guard + новый приватный метод |
| **Модифицируемый файл** | 1 файл: `Sources/ViewModels/CalculatorViewModel.swift` |
| **Строк для изменения** | 1 строка (guard на строке 246) |
| **Строк для добавления** | ~11 строк (2 строки комментария + 9 строк кода нового метода) |
| **Строк для удаления** | 0 |
| **Новых публичных API** | 0 — метод `hasUnclosedParentheses` имеет видимость `private` |
| **Изменений в CalculatorEngine** | 0 — Tokenizer, Parser, Evaluator без изменений |
| **Изменений в Views** | 0 — DisplayView, CalculatorView, CalculatorButton без изменений |
| **Изменений в Tests** | 0 — ни один тест не вызывает `tryAutoEvaluate()` напрямую |
| **Изменений в Localization** | 0 — строки локализации без изменений |
| **Изменений в Services** | 0 — HistoryService, ClipboardManager без изменений |
| **Риск регрессии** | Минимальный — изменение затрагивает только промежуточное автовычисление, не финальное вычисление по «=» |
| **Влияние на тесты** | Нулевое — ни один тест не вызывает `tryAutoEvaluate()` напрямую |

---

### 17. ЧТО НЕ ИЗМЕНЯЕТСЯ (СПИСОК ЗАПРЕТА)

Следующие файлы и их содержимое **НЕ ДОЛЖНЫ** быть изменены:

| Файл / Директория | Причина запрета |
|-------------------|-----------------|
| `Sources/CalculatorEngine/` — все файлы | Вычислительный движок корректно обрабатывает полные выражения, изменение сломает контракты и тесты |
| `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift` | Токенизатор правильно преобразует `(` в `.leftParenthesis` |
| `Sources/CalculatorEngine/Parser/Parser.swift` | Парсер правильно выбрасывает `missingClosingParenthesis` для незакрытых скобок при вызове `evaluate()` |
| `Sources/CalculatorEngine/Evaluator/Evaluator.swift` | Вычислитель AST не затрагивается |
| `Sources/CalculatorEngine/Errors/CalculatorError.swift` | Перечисление ошибок корректно, строки локализации верны |
| `Sources/Views/CalculatorView.swift` | UI-кнопка `.openParen` и обработчик `handleButtonPress` работают корректно |
| `Sources/Views/CalculatorButton.swift` | `inputValue` для `.openParen` возвращает `"("` — это правильно |
| `Sources/App/CalculatorApp.swift` (KeyHandlerNSView) | Клавиатурный ввод работает корректно, символ `(` попадает в `appendCharacter` |
| `Tests/Unit/CalculatorEngineTests.swift` | 45 тестов движка не должны меняться |
| `Tests/Unit/ParserTests.swift` | 12 тестов парсера не должны меняться |
| `Tests/Unit/TokenizerTests.swift` | 27 тестов токенизатора не должны меняться |
| `Tests/Unit/EvaluatorTests.swift` | 17 тестов вычислителя не должны меняться |
| `Sources/Localization/ru.lproj/Localizable.strings` | Строки локализации ошибок скобок верны — ошибка должна показываться при `evaluate()` |
| `Sources/Localization/en.lproj/Localizable.strings` | То же для английской локализации |
| `Package.swift` | Структура модулей не меняется |

---

### 18. ПОШАГОВАЯ ИНСТРУКЦИЯ ДЛЯ ВЫПОЛНЕНИЯ (чек-лист)

Выполнять строго по порядку:

**Шаг 0:** Открыть файл `Sources/ViewModels/CalculatorViewModel.swift`

**Шаг 1:** Перейти к строке 246. Текущее содержимое:
```swift
        guard !trimmed.isEmpty, !isTrailingOperator(expression) else { return }
```

Заменить на:
```swift
        guard !trimmed.isEmpty, !isTrailingOperator(expression), !hasUnclosedParentheses(trimmed) else { return }
```

**Шаг 2:** Перейти к строке 273 (закрывающая скобка класса `}`). Вставить перед ней новый метод:
```swift
    /// Проверяет, есть ли в выражении незакрытые открывающие скобки.
    /// Возвращает true, если количество '(' превышает количество ')'.
    private func hasUnclosedParentheses(_ expr: String) -> Bool {
        var count = 0
        for char in expr where char == "(" || char == ")" {
            if char == "(" {
                count += 1
            } else {
                count -= 1
            }
        }
        return count > 0
    }
```

**Шаг 3:** Проверить, что закрывающая скобка класса `}` остаётся на месте (после нового метода).

**Шаг 4:** Убедиться, что в файле нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()` — отладочный код.

**Шаг 5:** Убедиться, что в новом коде нет force unwrap (`!`).

**Шаг 6:** Готово. Изменён только один файл: `Sources/ViewModels/CalculatorViewModel.swift`. Добавлено ~12 строк, изменена 1 строка.
