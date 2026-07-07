# План исправления бага: ошибка `doubleOperator` при вводе выражений с оператором перед скобкой

**Агент:** MiMoCode
**Дата:** 2026-07-07
**Статус:** План готов к согласованию

---

## 1. Суть проблемы

При вводе выражения `4*(2+3)` и нажатии кнопки `)` калькулятор отображает ошибку `errors.doubleOperator` вместо вычисления результата.

**Воспроизведение:**
- Нажать `4` → `*` → `(` → `2` → `+` → `3` → `)`
- На экране: `errors.doubleOperator`

**Масштаб бага:** Любое выражение, где **бинарный оператор стоит непосредственно перед открывающей скобкой `(`**, отклоняется токенизатором:
- `4*(2+3)` — FAIL
- `10/(2+3)` — FAIL
- `10-(2+3)` — FAIL
- `2*(3)` — FAIL
- `4*5*(3+1)` — FAIL
- `2*3+(4*5)` — FAIL

**Рабочие выражения** (оператор НЕ перед `(`):
- `(2+3)*4` — OK
- `1+2+3+4` — OK
- `4*5+3` — OK
- `2*3*4` — OK

---

## 2. Корневая причина (verified)

**Файл:** `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`
**Метод:** `validateTokenSequence(_:)` (строка 324)
**Хелпер:** `isOperatorOrLeftParen(_:)` (строка 369)

### Цепочка вызовов, приводящая к ошибке:

1. Токенизатор корректно разбивает `4*(2+3)` на 7 токенов:
   ```
   [0] number(4)
   [1] binaryOperator(.multiply)
   [2] leftParenthesis
   [3] number(2)
   [4] binaryOperator(.add)
   [5] number(3)
   [6] rightParenthesis
   ```

2. Метод `validateTokenSequence` проверяет каждый токен. Для токена `[1]` (binaryOperator `*`):
   ```swift
   case .binaryOperator:
       let prevIsOp = i > tokens.startIndex && isOperatorOrLeftParen(tokens[i - 1])
       let nextIsOp = i + 1 < tokens.endIndex && isOperatorOrLeftParen(tokens[i + 1])
       let nextIsUnaryMinus = i + 1 < tokens.endIndex && tokens[i + 1] == .unaryMinus
       if prevIsOp || (nextIsOp && !nextIsUnaryMinus) {
           throw CalculatorError.doubleOperator
       }
   ```

3. `nextIsOp` проверяет `tokens[2]` — это `leftParenthesis`. Вызывается `isOperatorOrLeftParen(.leftParenthesis)`, которая возвращает **`true`** (строка 371: `case .binaryOperator, .unaryMinus, .leftParenthesis: return true`).

4. `nextIsUnaryMinus` — проверяет `tokens[2]`, это `leftParenthesis`, не `unaryMinus` → **`false`**.

5. Условие: `prevIsOp (false) || (nextIsOp (true) && !nextIsUnaryMinus (true))` = `false || (true && true)` = **`true`** → выбрасывается `CalculatorError.doubleOperator`.

### Почему это неверно:

Открывающая скобка `(` после бинарного оператора — это **абсолютно валидная** конструкция: `4*(2+3)`, `10/(2+3)`, `2+(3*4)`. Скобка не является оператором, она задаёт группировку. Функция `isOperatorOrLeftParen` корректно используется в других контекстах:

- Для проверки `prevIsOp` у `binaryOperator` — `(` перед оператором действительно некорректно (`(+` — ошибка)
- Для проверки `prevIsOp` у `rightParenthesis` — `(` перед `)` некорректно
- Для проверки `prevIsOp` у `unaryMinus` — `(` перед унарным минусом некорректно

Но для проверки **следующего** токена (`nextIsOp`) у `binaryOperator` — `(` после оператора **валидна**. Это единственное место, где `leftParenthesis` не должен считаться оператором.

---

## 3. Решение

Изменить **один файл**: `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

### Шаг 1: Добавить новый хелпер `isOperatorOnly`

Добавить приватный метод рядом с `isOperatorOrLeftParen` (после строки 376):

```swift
/// Проверяет, является ли токен оператором (без скобок).
/// Используется для проверки следующего токена после binaryOperator:
/// оператор после оператора — ошибка, но скобка после оператора — норма.
private func isOperatorOnly(_ token: Token) -> Bool {
    switch token {
    case .binaryOperator, .unaryMinus:
        return true
    default:
        return false
    }
}
```

### Шаг 2: Заменить вызов в валидации binaryOperator

В методе `validateTokenSequence`, в кейсе `.binaryOperator` (строки 331-332), заменить:

**Было:**
```swift
let nextIsOp = i + 1 < tokens.endIndex && isOperatorOrLeftParen(tokens[i + 1])
```

**Стало:**
```swift
let nextIsOp = i + 1 < tokens.endIndex && isOperatorOnly(tokens[i + 1])
```

### Что НЕ меняется:

- Проверка `prevIsOp` для `.binaryOperator` — остаётся `isOperatorOrLeftParen` (корректно: `(` перед оператором — ошибка)
- Все проверки для `.percent`, `.unaryMinus`, `.rightParenthesis` — остаются `isOperatorOrLeftParen` (корректно во всех этих контекстах)
- Метод `isOperatorOrLeftParen` — **не удаляется**, он используется в 4 других местах

---

## 4. Верификация изменений

### 4.1. Что должно начать работать:

| Выражение | Ожидаемый результат |
|---|---|
| `4*(2+3)` | `20` |
| `10/(2+3)` | `2` |
| `10-(2+3)` | `5` |
| `2*(3)` | `6` |
| `4*5*(3+1)` | `80` |
| `2*3+(4*5)` | `26` |

### 4.2. Что НЕ должно сломаться:

| Выражение | Ожидаемый результат | Почему |
|---|---|---|
| `5++3` | `doubleOperator` | `prevIsOp` для `+` проверяет `isOperatorOrLeftParen(prev)` — `+` перед `+` = ошибка |
| `5+-3` | OK (unary minus) | `+` перед `-3` — `nextIsUnaryMinus = true`, поэтому `!nextIsUnaryMinus = false`, условие не срабатывает |
| `(2+3)*4` | `15` | `prevIsOp` для `*` проверяет `)` — `)` не в `isOperatorOrLeftParen`, поэтому false |
| `5%+10` | `10.05` | `prevIsOp` для `%` проверяет `isOperatorOrLeftParen(5)` = false |
| `(50+10)%` | `0.6` | `prevIsOp` для `%` проверяет `isOperatorOrLeftParen())` = false |
| `15+16*5` | `95` | Оператор перед числом — без скобок, всё корректно |
| `100-5%` | `99.95` | `%` после `-` — `prevIsOp` = true, выбросит `doubleOperator` |

### 4.3. Точка регрессии:

Единственный изменяемый файл — `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`. Модуль `CalculatorEngine` не зависит от SwiftUI/AppKit, поэтому изменение не затрагивает UI-слой, ViewModel, сервисы или тему.

Потребители `validateTokenSequence`:
- `tokenize(_:)` — единственный вызов (строка 115)

Потребители `isOperatorOrLeftParen` (после изменения):
- `validateTokenSequence` — case `.binaryOperator` (prevIsOp), `.percent`, `.unaryMinus`, `.rightParenthesis` — **остаётся без изменений**
- Новый метод `isOperatorOnly` — case `.binaryOperator` (nextIsOp) — **единственное изменение**

---

## 5. Пошаговый план реализации

### Шаг 1. Открыть файл
`Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

### Шаг 2. Добавить метод `isOperatorOnly`
Вставить после метода `isOperatorOrLeftParen` (после строки 376), перед методом `advance`:

```swift
/// Проверяет, является ли токен оператором (без скобок).
/// Используется для проверки следующего токена после binaryOperator:
/// оператор после оператора — ошибка, но скобка после оператора — норма.
private func isOperatorOnly(_ token: Token) -> Bool {
    switch token {
    case .binaryOperator, .unaryMinus:
        return true
    default:
        return false
    }
}
```

### Шаг 3. Заменить проверку `nextIsOp`
В методе `validateTokenSequence`, кейс `.binaryOperator` (строка 331):

Заменить:
```swift
let nextIsOp = i + 1 < tokens.endIndex && isOperatorOrLeftParen(tokens[i + 1])
```
На:
```swift
let nextIsOp = i + 1 < tokens.endIndex && isOperatorOnly(tokens[i + 1])
```

### Шаг 4. Проверить сборку
```bash
swift build
```

### Шаг 5. Запустить TestRunner
```bash
swift run TestRunner
```
Ожидаемый результат: все тесты проходят, `5*-3` тоже работает (было сломано тем же багом).

### Шаг 6. Запустить приложение и проверить вручную
```bash
swift run CalculatorApp
```
Проверить:
1. `4*(2+3)` = 20 (базовый кейс)
2. `10/(2+3)` = 2 (деление со скобкой)
3. `10-(2+3)` = 5 (вычитание со скобкой)
4. `(2+3)*4` = 15 (скобка перед оператором — не должно сломаться)
5. `5++3` = ошибка (двойной оператор — не должно сломаться)

### Шаг 7. Проверить отсутствие отладочного кода
Убедиться, что в файле нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()`.

---

## 6. Анализ влияния на TestRunner

TestRunner (`Sources/TestRunner/main.swift`) падает на строке 139:
```swift
checkEqual(try! engine.evaluate("5*-3"), -15, "5*-3=-15")
```

Выражение `5*-3` содержит `*` перед `-3` (унарный минус). До исправления: `isOperatorOrLeftParen(.unaryMinus)` = true → ошибка. После исправления: `isOperatorOnly(.unaryMinus)` = true, но проверяется `nextIsUnaryMinus` = true → `!nextIsUnaryMinus` = false → условие `nextIsOp && !nextIsUnaryMinus` = false → выражение валидно.

TestRunner **начнёт работать** после исправления.

---

## 7. Чеклист самопроверки

- [ ] Нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()` в изменённом файле
- [ ] Нет force unwrap (`!`) без обоснованной гарантии
- [ ] Новый метод `isOperatorOnly` помечен `private`
- [ ] MARK-комментарий на русском языке
- [ ] Идентификатор `isOperatorOnly` на английском языке
- [ ] Нет импортов SwiftUI в Tokenizer.swift (нет изменений в импортах)
- [ ] Все исключения обрабатываются (нет изменений в обработке)
- [ ] Все утверждения о коде подтверждены ссылками на файл и строку
- [ ] Изменения затрагивают только `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`
