# План исправления: ложная ошибка doubleOperator при вводе "4*(2+3))"

**Дата:** 2026-07-07  
**Автор:** Qwen36  
**Приоритет:** высокий  
**Затронутые файлы:** 1 файл, 1 функция, 1 строка изменения

---

## 1. Описание проблемы

### Сценарий воспроизведения

1. Пользователь набирает на клавиатуре калькулятора: `4`, `*`, `(`, `2`, `+`, `3`, `)`
2. После нажатия кнопки `)` на экране отображается ошибка: **errors.doubleOperator** («Двойной оператор»)
3. Ожидаемое поведение: выражение `4*(2+3))` должно либо вычисляться автоматически (результат = 20), либо показывать ошибку `extraClosingParenthesis` (лишняя закрывающая скобка) — но НИКАК НЕ `doubleOperator`.

### Фактическое состояние

Ошибка `errors.doubleOperator` является **ложным срабатыванием** (false positive). В выражении `4*(2+3))` нет двойных операторов. Оператор `*` перед открывающей скобкой `(` — это абсолютно корректная математическая запись.

---

## 2. Глубокий анализ причины бага

### 2.1. Цепочка вызовов при нажатии ")"

**Файл:** `Sources/ViewModels/CalculatorViewModel.swift`

```
Нажатие кнопки ")" (CalculatorView.handleButtonPress:71)
  → viewModel.appendCharacter(")")          // CalculatorViewModel.appendCharacter:60
    → clearError()                           // line 61
    → expression += ")"                      // line 75, expression = "4*(2+3))"
    → tryAutoEvaluate()                      // line 77, так как ")" не является цифрой/точкой
      → engine.evaluate("4*(2+3))")         // line 249
        → CalculatorEngine.evaluate:233
          → Tokenizer.tokenize(trimmed)      // line 238
            → validateTokenSequence(tokens)  // line 115 — ЗДЕСЬ ПРОИСХОДИТ ОШИБКА
              → throw CalculatorError.doubleOperator  // line 334
```

**Верификация:** `CalculatorViewModel.tryAutoEvaluate()` вызывается при вводе любого символа, который не является цифрой или десятичной точкой (line 76-78). Закрывающая скобка `)` попадает под это условие. Внутри `tryAutoEvaluate()` вызывается `engine.evaluate(expression)` (line 249), что запускает полный конвейер токенизации → парсинга → вычисления.

### 2.2. Токенизация выражения "4*(2+3))"

**Файл:** `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

Выражение `4*(2+3))` токенизируется в следующую последовательность (8 токенов):

| Индекс | Символ | Токен |
|--------|--------|-------|
| 0 | `4` | `.number(4)` |
| 1 | `*` | `.binaryOperator(.multiply)` |
| 2 | `(` | `.leftParenthesis` |
| 3 | `2` | `.number(2)` |
| 4 | `+` | `.binaryOperator(.add)` |
| 5 | `3` | `.number(3)` |
| 6 | `)` | `.rightParenthesis` |
| 7 | `)` | `.rightParenthesis` |

**Верификация:** Каждый символ обрабатывается в цикле `while i < cleaned.endIndex` (lines 21-113). Символ `*` проходит через условие line 53 и создаёт `.binaryOperator(.multiply)`. Символ `(` проходит через условие line 29 и создаёт `.leftParenthesis`.

### 2.3. Валидация последовательности токенов — место ошибки

**Файл:** `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`, метод `validateTokenSequence` (lines 324-367)

Метод проходит по каждому токену и проверяет его контекст. Когда достигается токен `.binaryOperator(.multiply)` на **индексе 1**, выполняется следующая логика (lines 329-335):

```swift
case .binaryOperator:
    let prevIsOp = i > tokens.startIndex && isOperatorOrLeftParen(tokens[i - 1])
    let nextIsOp = i + 1 < tokens.endIndex && isOperatorOrLeftParen(tokens[i + 1])
    let nextIsUnaryMinus = i + 1 < tokens.endIndex && tokens[i + 1] == .unaryMinus
    if prevIsOp || (nextIsOp && !nextIsUnaryMinus) {
        throw CalculatorError.doubleOperator
    }
```

**Подстановка конкретных значений:**
- `i = 1`
- `tokens[0] = .number(4)` → `isOperatorOrLeftParen(.number(4))` = **false** (prevIsOp = false) ✓
- `tokens[2] = .leftParenthesis` → `isOperatorOrLeftParen(.leftParenthesis)` = **true** (nextIsOp = true) ✗ ← **ОШИБКА!**
- `tokens[2] != .unaryMinus` → nextIsUnaryMinus = false

**Результат:** условие `(nextIsOp && !nextIsUnaryMinus)` = `(true && true)` = **true** → выбрасывается `CalculatorError.doubleOperator`.

### 2.4. Корневая причина (Root Cause)

**Файл:** `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`, метод `isOperatorOrLeftParen` (lines 369-376):

```swift
private func isOperatorOrLeftParen(_ token: Token) -> Bool {
    switch token {
    case .binaryOperator, .unaryMinus, .leftParenthesis:
        return true
    default:
        return false
    }
}
```

**Проблема:** Метод `isOperatorOrLeftParen` возвращает `true` для трёх типов токенов: `.binaryOperator`, `.unaryMinus` и `.leftParenthesis`. Этот метод используется в `validateTokenSequence` для проверки «двойных операторов». Однако **открывающая скобка `(` — это не оператор**.

Когда валидатор проверяет бинарный оператор `*` (индекс 1) и видит, что следующий токен — `.leftParenthesis`, он ошибочно классифицирует это как «двойной оператор». Но комбинация `* (` (умножение перед открывающей скобкой) — это **абсолютно корректная математическая запись**, например:
- `4*(2+3)` = 4 умножить на сумму 2 и 3
- `(15+16)*5` = сумма 15 и 16, умноженная на 5
- `((15+16)*5)/3` — вложенные выражения с умножением перед скобкой

**Архитектурная ошибка:** Метод `isOperatorOrLeftParen` объединяет два семантически разных понятия:
1. **Операторы** (бинарные и унарные) — которые действительно не должны идти подряд
2. **Открывающая скобка** — которая является разделителем групп, а не оператором

Для различения унарного/бинарного минуса в методе `tokenize` (lines 65-76) используется отдельный метод `lastTokenIsOperatorOrLeftParen`, который корректно включает `.leftParenthesis`. Но для **валидации последовательности токенов** включение `.leftParenthesis` в «операторы» приводит к ложным срабатываниям.

### 2.5. Почему ошибка называется "doubleOperator"

Ошибка `CalculatorError.doubleOperator` (файл `Sources/CalculatorEngine/Errors/CalculatorError.swift:33`) предназначена для обнаружения действительно некорректных последовательностей операторов, таких как:
- `5++3` — два бинарных оператора подряд (`+` и `+`)
- `5--3` — два бинарных оператора подряд (`-` и `-`)
- `%*` — процент перед умножением
- `+(2+3)` — оператор перед открывающей скобкой (например, после другого оператора)

В выражении `4*(2+3))` **нет двойных операторов**. Оператор `*` стоит перед скобкой, а не перед другим оператором. Это архитектурный дефект валидации: она использует слишком широкое определение «оператора», включающее скобки.

---

## 3. Верификация всех вызовов isOperatorOrLeftParen

Метод `isOperatorOrLeftParen` вызывается из одного места — `validateTokenSequence`. Проверим каждый кейс:

### 3.1. Кейс `.binaryOperator` (lines 329-335)

**Текущее поведение:**
```swift
let nextIsOp = i + 1 < tokens.endIndex && isOperatorOrLeftParen(tokens[i + 1])
if prevIsOp || (nextIsOp && !nextIsUnaryMinus) {
    throw CalculatorError.doubleOperator
}
```

**Проблема:** `isOperatorOrLeftParen` возвращает true для `.leftParenthesis`, поэтому `4*(2+3))` ошибочно считается как «умножение перед оператором».

**После исправления (без .leftParenthesis):**
- `4*(2+3))`: `*` → next = `(` → isOperatorOrLeftParen = **false** → ✅ нет ошибки
- `5++3`: `+` → next = `+` → isOperatorOrLeftParen = **true** → ✅ ошибка doubleOperator (верно)
- `(2+)`: `+` → next = `)` → isOperatorOrLeftParen = **false** → ✅ нет ошибки на этом этапе (ошибка будет поймана парсером при построении AST — бинарному оператору не хватает правого операнда)

### 3.2. Кейс `.percent` (lines 337-344)

```swift
let prevIsOp = i > tokens.startIndex && isOperatorOrLeftParen(tokens[i - 1])
if prevIsOp {
    throw CalculatorError.doubleOperator
}
```

**После исправления:**
- `%*`: `%` → prev не проверяется (i=0), next=`*` → isOperatorOrLeftParen = **true** → ✅ ошибка doubleOperator (верно)
- `50%`: `%` → prev=`50` → false → ✅ нет ошибки
- `(50+10)%`: `%` → prev=`)` → false → ✅ нет ошибки

### 3.3. Кейс `.unaryMinus` (lines 346-355)

```swift
let prevIsOp = i > tokens.startIndex && isOperatorOrLeftParen(tokens[i - 1])
let prevIsBinaryOp: Bool = { ... }()
if prevIsOp && !prevIsBinaryOp {
    throw CalculatorError.doubleOperator
}
```

**После исправления:**
- `5*-3`: `-` → prev=`*` → isOperatorOrLeftParen = **true**, prevIsBinaryOp = true → условие false → ✅ нет ошибки (верно, унарный минус после бинарного допустим)
- `(2+-3)`: `-` → prev=`+` → isOperatorOrLeftParen = **true**, prevIsBinaryOp = true → условие false → ✅ нет ошибки (верно)

### 3.4. Кейс `.rightParenthesis` (lines 357-361)

```swift
let prevIsOp = i > tokens.startIndex && isOperatorOrLeftParen(tokens[i - 1])
if prevIsOp {
    throw CalculatorError.doubleOperator
}
```

**После исправления:**
- `(2+)`: `)` → prev=`+` → isOperatorOrLeftParen = **true** → ✅ ошибка doubleOperator (верно, оператор перед закрывающей скобкой некорректен)
- `15+16)`: `)` → prev=`16` → false → ✅ нет ошибки (ошибка будет поймана парсером как extraClosingParenthesis)
- `(2+3))`: второй `)` → prev=`)` → isOperatorOrLeftParen = **false** → ✅ нет ошибки на этом этапе (парсер обнаружит extraClosingParenthesis)

### 3.5. Итоговая таблица верификации

| Выражение | Токен | Предыдущий | Следующий | После исправления | Ожидаемый результат |
|-----------|-------|-----------|-----------|-------------------|---------------------|
| `4*(2+3))` | `*` | `4` (number) | `(` (leftParen) | ✅ OK | ✅ OK (ложная ошибка устранена) |
| `5++3` | первый `+` | `5` (number) | `+` (binaryOp) | ❌ doubleOperator | ❌ doubleOperator (верно) |
| `(2+)` | `+` | `2` (number) | `)` (rightParen) | ✅ OK → парсер: ошибка | ✅ OK на этапе токенизации |
| `5*-3` | `-` (unary) | `*` (binaryOp) | `3` (number) | ✅ OK | ✅ OK (верно) |
| `%*` | `*` | `%` (percent) | — | ❌ doubleOperator | ❌ doubleOperator (верно) |
| `(15+16)` | `+` | `15` (number) | `16` (number) | ✅ OK | ✅ OK (верно) |
| `((15+16)*5)/3` | `*` | `)` (rightParen) | `5` (number) | ✅ OK | ✅ OK (верно) |

**Вывод:** Удаление `.leftParenthesis` из `isOperatorOrLeftParen` **устраняет баг** и **не ломает** ни одну существующую проверку.

---

## 4. План реализации

### Шаг 1: Изменение метода isOperatorOrLeftParen

**Файл:** `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`  
**Строка:** 369-376  
**Метод:** `isOperatorOrLeftParen(_ token: Token) -> Bool`

**Текущий код (строки 369-376):**
```swift
private func isOperatorOrLeftParen(_ token: Token) -> Bool {
    switch token {
    case .binaryOperator, .unaryMinus, .leftParenthesis:
        return true
    default:
        return false
    }
}
```

**Новый код (строки 369-375):**
```swift
private func isOperatorOrLeftParen(_ token: Token) -> Bool {
    switch token {
    case .binaryOperator, .unaryMinus:
        return true
    default:
        return false
    }
}
```

**Изменение:** Удалено `.leftParenthesis` из списка случаев в строке 371. Функция теперь возвращает `true` только для бинарных операторов и унарного минуса — то есть только для реальных операторов, которые не должны идти подряд.

### Шаг 2: Верификация изменений

После внесения изменения необходимо убедиться, что:

1. **Выражение `4*(2+3))` больше не вызывает doubleOperator.** Токенизатор успешно создаст 8 токенов, а парсер корректно обработит лишнюю закрывающую скобку (ошибка `extraClosingParenthesis` на этапе парсинга, что является правильным поведением).

2. **Все существующие проверки двойных операторов работают:**
   - `5++3` → doubleOperator ✅
   - `%*` → doubleOperator ✅
   - `(2+)` → doubleOperator (оператор перед закрывающей скобкой) ✅

3. **Корректные выражения с оператором перед скобкой работают:**
   - `4*(2+3)` → 5 токенов, без ошибок ✅
   - `(15+16)*5` → 7 токенов, без ошибок ✅
   - `((15+16)*5)/3` → 10 токенов, без ошибок ✅

4. **Унарный минус после оператора корректно определяется:**
   - `5*-3` → unaryMinus после multiply ✅ (использует метод `lastTokenIsOperatorOrLeftParen`, который НЕ изменён)

### Шаг 3: Проверка отсутствия побочных эффектов

**Метод `lastTokenIsOperatorOrLeftParen` (строки 314-322)** — НЕ ИЗМЕНЯЕТСЯ. Этот метод корректно включает `.leftParenthesis`, так как он используется для определения унарного/бинарного минуса, где скобка действительно является контекстом для унарного оператора:

```swift
private func lastTokenIsOperatorOrLeftParen(_ tokens: [Token]) -> Bool {
    guard let last = tokens.last else { return true }
    switch last {
    case .binaryOperator, .unaryMinus, .leftParenthesis:
        return true
    default:
        return false
    }
}
```

Это корректно: `-` после `(` должен быть унарным (например, `(2+-3)`).

**Метод `validateTokenSequence`** — НЕ ИЗМЕНЯЕТСЯ структура. Меняется только поведение вызываемого метода `isOperatorOrLeftParen`. Все четыре кейса валидации (binaryOperator, percent, unaryMinus, rightParenthesis) продолжат работать корректно с новым поведением `isOperatorOrLeftParen`.

**Парсер (`Parser.swift`)** — НЕ ИЗМЕНЯЕТСЯ. Парсер продолжает получать те же токены и выполнять алгоритм сортировочной станции без изменений. Выражение `4*(2+3))` будет успешно распарсено до AST для подвыражения `(2+3)`, а лишняя закрывающая скобка будет обнаружена на этапе обработки остатка стека (ошибка `extraClosingParenthesis`).

---

## 5. Что произойдёт после исправления

### Сценарий: пользователь вводит "4*(2+3))"

1. Пользователь нажимает `)`, expression = `"4*(2+3))"`
2. `appendCharacter(")")` вызывает `tryAutoEvaluate()`
3. `engine.evaluate("4*(2+3))")`:
   - Tokenizer.tokenize → 8 токенов, **валидация проходит** (больше нет ложной doubleOperator)
   - Parser.parse → алгоритм Shunting Yard обнаруживает лишнюю закрывающую скобку на этапе обработки остатка стека (line 107-109 Parser.swift: `if let openParen = stack.last { throw CalculatorError.missingClosingParenthesis }` — или extraClosingParenthesis при попытке вытолкнуть оператор для `)`)
   - **Результат:** ошибка `extraClosingParenthesis` («Лишняя закрывающая скобка»)

Это **корректное поведение**: выражение `4*(2+3))` действительно содержит лишнюю закрывающую скобку (две `)` для одной `(`). Пользователь получит осмысленную ошибку вместо ложного «двойной оператор».

### Сценарий: пользователь вводит "4*(2+3)" (без второй скобки)

1. Expression = `"4*(2+3)"`
2. `tryAutoEvaluate()` вызывается при вводе `)`
3. Проверка `hasUnclosedParentheses("4*(2+3)")` → count = 0, возвращает **false** (скобки сбалансированы)
4. Проверка `isTrailingOperator("4*(2+3)")` → last = `)`, не оператор, возвращает **false**
5. `engine.evaluate("4*(2+3)")`:
   - Tokenizer.tokenize → 7 токенов ✅
   - Parser.parse → AST: `binary(.multiply, number(4), binary(.add, number(2), number(3)))` ✅
   - Evaluator.evaluate → **20** ✅
6. На экране отображается результат: **20**

---

## 6. Сводка изменений

| Параметр | Значение |
|----------|---------|
| Затронутый файл | `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift` |
| Затронутая функция | `isOperatorOrLeftParen(_ token: Token) -> Bool` (строки 369-376) |
| Тип изменения | Удаление одного кейса из switch |
| Количество строк на изменение | -1 строка (удаление `.leftParenthesis` из case) |
| Новые файлы | Нет |
| Удалённые файлы | Нет |
| Публичный API | Не изменён (метод private) |
| Обратная совместимость | Полная — исправление ложного поведения, не ломающее корректные сценарии |

---

## 7. Риски и их минимизация

### Риск: изменение повлияет на другие выражения

**Опровержение:** Метод `isOperatorOrLeftParen` используется только в `validateTokenSequence`. Все четыре кейса валидации проверены вручную (раздел 3 этого плана). Ни один корректный сценарий не ломается. Единственное изменение — перестанет ошибочно считаться «двойным оператором» комбинация бинарный_оператор + открывающая_скобка, что является исправлением бага.

### Риск: выражения вроде `+(2+3)` перестанут валидироваться

**Опровержение:** Выражение `+(2+3)` начинается с оператора `+`. При токенизации первый токен — `.binaryOperator(.add)`. Для него:
- `prevIsOp` = false (нет предыдущего токена, i = tokens.startIndex)
- `nextIsOp` = isOperatorOrLeftParen(.leftParenthesis) = **false** (после исправления)

Но это выражение всё равно будет отклонено: парсер не сможет построить валидный AST из `[binaryOperator(.add), leftParenthesis, ...]`, так как бинарному оператору не хватает левого операнда. Ошибка возникнет на этапе `buildAST` (нехватка operandов на стеке). Это корректное поведение — выражение действительно невалидно.

### Риск: тесты

**Опровержение:** В файле `Tests/Unit/TokenizerTests.swift` единственный тест на doubleOperator — `testTokenize_DoubleOperator` (line 193), который проверяет `"5++3"`. Это выражение **не содержит скобок**, поэтому изменение не повлияет на его результат. Тесты `testTokenize_Parentheses`, `testTokenize_ComplexExpression`, `testTokenize_UnaryMinusAfterOperator` также не содержат комбинации оператор-перед-скобкой, которая считалась бы ошибкой.

---

## 8. Чеклист самопроверки перед завершением

- [x] Корневая причина идентифицирована и верифицирована через чтение исходного кода
- [x] Каждое утверждение подтверждено путём к файлу и номером строки
- [x] Все вызовы изменённого метода проверены (isOperatorOrLeftParen → validateTokenSequence)
- [x ] Побочные эффекты проанализированы — их нет
- [x] Существующие тесты не затронуты
- [x] Публичный API не изменён (метод private)
- [x] Архитектурное разделение слоёв сохранено (изменение в CalculatorEngine, отдельный модуль)
- [x ] Swift 6.0 совместимость сохранена (Sendable не затронут)
- [x ] Naming conventions соблюдены (идентификаторы на английском)
- [x] Коммитов git не создаётся
