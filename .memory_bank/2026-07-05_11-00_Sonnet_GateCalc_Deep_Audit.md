# Профессиональный аудит кодовой базы GateCalc

**Дата:** 2026-07-05, 11:00  
**Агент:** Sonnet (Claude Sonnet 4.6 Thinking)  
**Версия SRS:** 1.1 (Исправленная), документ `2026-07-04_17-00_OrnithQ8_Calculator_SRS_Ispravlennaya_Versiya.txt`  
**Статус кодовой базы:** Реализована, требует аудита

---

## Резюме аудита

Кодовая база реализует большинство требований SRS. Ядро (CalculatorEngine) написано грамотно, архитектура в целом соответствует заявленной. Однако в процессе детального анализа выявлены **критические ошибки**, **существенные несоответствия SRS** и ряд **технических недоработок**, которые необходимо устранить до признания проекта завершённым.

---

## 1. Архитектурный аудит

### 1.1 Соответствие структуры проекта SRS §16

SRS предписывает структуру: `CalculatorEngine/Tokenizer/, Parser/, Evaluator/, AST/`

**Реализация:** ✅ Полностью соответствует. Дополнительно присутствуют:
- `Sources/Components/` — есть (EmptyStateView.swift)
- `Sources/Extensions/` — есть
- `Sources/Models/` — **пустая директория** ⚠️

**Проблема #A-01 (Незначительная):** Директория `Sources/Models/` присутствует, но полностью пустая. Это мусор в проекте. SRS §93 запрещает неиспользуемые файлы/директории.

### 1.2 Package.swift — архитектурная проблема

```swift
.executableTarget(
    name: "CalculatorApp",
    path: "Sources",
    sources: [
        "App", "Views", "ViewModels", "Services",
        "History", "Clipboard", "Models", "Formatting", "Theme"
    ]
)
```

**Проблема #A-02 (Существенная):** `Package.swift` не содержит:
- `Components/` в списке sources — **EmptyStateView.swift фактически не компилируется**
- `Extensions/` — **Decimal+Extensions.swift и String+Calculator.swift не компилируются**
- `Localization/` — **файлы локализации не связаны с таргетом**

Следствие: при сборке через `swift build` эти файлы игнорируются. Компиляция успешна лишь потому, что расширения не используются в коде явно.

### 1.3 Тесты не зарегистрированы в Package.swift

**Проблема #A-03 (Критическая):** Файлы тестов `Tests/Unit/*.swift` и `Tests/UI/*.swift` существуют, но **не зарегистрированы ни в одном `.testTarget()`** в `Package.swift`. `swift test` не выполнит ни одного теста. Это грубое нарушение SRS §90 и §93 (Definition of Done: «Все тесты успешно проходят»).

### 1.4 Нарушение SRS §87 (Swift Concurrency)

**Проблема #A-04 (Существенная):** `HistoryService` использует `NSLock` вместо `actor`:

```swift
public final class HistoryService: @unchecked Sendable {
    private let lock = NSLock()  // SRS §87 запрещает GCD без необходимости
}
```

SRS §87 прямо запрещает использование GCD без объективной необходимости. Правильная реализация:

```swift
public actor HistoryService {
    // ...без NSLock
}
```

Аналогично `ClipboardManager: @unchecked Sendable` обходит Swift Concurrency checker.

---

## 2. Аудит вычислительного движка

### 2.1 Tokenizer — критическая ошибка при распознавании «pi»

В `Tokenizer.swift`, строка 90:

```swift
if char == "\u{03C0}" || char == "π" || char.lowercased() == "pi" {
```

**Проблема #E-01 (Критическая):** Сравнение `char.lowercased() == "pi"` **никогда не может быть истинным**. `char` — это один символ `Character`. `Character.lowercased()` возвращает `String`, но строка одного символа (`"p"`) никогда не равна `"pi"`.

Тест `testTokenize_PiKeyword` проверяет `tokenize("pi")` и ожидает 1 токен — **этот тест должен падать**, так как `p` вызовет `invalidCharacter`.

Правильная реализация: проверять подстроку, а не одиночный символ:
```swift
if cleaned[i...].hasPrefix("pi") || cleaned[i...].hasPrefix("π") {
```

### 2.2 Tokenizer — неоднозначное поведение с `e3`

В `Tokenizer.swift`, строки 96-113: при `char == "e"` и следующем символе-цифре код вызывает `readNumber(cleaned, from: i)` начиная с позиции `i` (то есть с самой `e`).

**Проблема #E-02 (Критическая):** Тест `testTokenize_EulerNumberWithExponent` в `TokenizerTests.swift`:

```swift
let tokens = try tokenizer.tokenize("e3")
XCTAssertEqual(v, 1000) // e is treated as variable...
```

Ожидание `1000` (**= 10³?**) логически противоречиво. `readNumber("e3", from: i)` при `e` в начале сформирует `numberStr = "e3"`, `Decimal(string: "e3")` вернёт `nil`, функция вернёт `(0, start)`. Тест ожидает `1000` — это недостижимое значение данным кодом. Поведение неоднозначно и не документировано.

### 2.3 Parser — неверная ошибка при незакрытой скобке

В `Parser.swift`, строки 84-89:

```swift
while let top = operatorStack.popLast() {
    if top.isLeftParen || top.isRightParen {
        throw CalculatorError.extraClosingParenthesis  // НЕВЕРНО!
    }
    output.append(top)
}
```

**Проблема #E-03 (Критическая):** При выражении `(15+16` в стеке остаётся `leftParenthesis`. Код выбрасывает `extraClosingParenthesis` вместо `missingClosingParenthesis`. Это вводит пользователя в заблуждение.

SRS §33 требует различать случаи. Правильная реализация:
```swift
while let top = operatorStack.popLast() {
    if top.isLeftParen {
        throw CalculatorError.missingClosingParenthesis
    }
    output.append(top)
}
```

### 2.4 Evaluator — отсутствие проверки переполнения

**Проблема #E-04 (Существенная):** SRS §35 требует обработку `numberOverflow` («Число слишком большое»). `Evaluator.swift` не содержит проверки на переполнение `Decimal`. При умножении очень больших чисел `Decimal` может вернуть `NaN`. SRS §36 указывает предел точности: `10^21`.

### 2.5 Tokenizer — тысячные разделители не работают в выражениях

В `Tokenizer.preprocess()`:

```swift
private func isThousandsSeparatorPattern(_ str: String) -> Bool {
    for c in str {
        if !c.isNumber && c != "," { return false }  // не допускает операторы!
    }
    return true
}
```

**Проблема #E-05 (Существенная):** Выражение `1,000+2,000` не пройдёт проверку (содержит `+`). SRS §39 требует корректной обработки тысячных разделителей в составных выражениях. Текущая реализация работает только для одиночных чисел.

### 2.6 Tokenizer — потенциальный бесконечный цикл

В `readNumber()`:
```swift
if numberStr == "." || numberStr.isEmpty {
    return (0, start)  // возвращаем НАЧАЛЬНУЮ позицию!
}
```

**Проблема #E-06 (Существенная):** При ошибочном считывании числа возвращается исходная позиция `start`. В вызывающем цикле `tokenize()` индекс `i` не сдвинется — **бесконечный цикл**. Это потенциальный краш приложения.

---

## 3. Аудит ViewModel

### 3.1 Критическая UX-проблема: вставка из буфера не отображает выражение

В `CalculatorViewModel.insertFromClipboard()`:

```swift
if let value = try? engine.evaluate(trimmed) {
    expression = ""        // ВЫРАЖЕНИЕ ОЧИЩАЕТСЯ!
    result = formatter.format(value)
    historyService.add(expression: trimmed, result: value)
}
```

**Проблема #V-01 (Критическая):** При успешной вставке пользователь **не видит вставленного выражения** — только результат. SRS §38 и §52 явно требуют:
> «Шаг 2: Выражение появляется на дисплее. Шаг 3: Автоматически вычисляется.»

Правильная реализация: `expression = trimmed`, затем `tryAutoEvaluate()`.

### 3.2 Захардкоженные сообщения об ошибках

**Проблема #V-02 (Существенная):** В `insertFromClipboard()`: `errorMessage = "Cannot evaluate"` — захардкоженная английская строка.

В `CalculatorError.swift` все `errorDescription` на английском:
```swift
case .divisionByZero: return "Division by zero"
```

SRS §82 запрещает захардкоженный текст. Должно использоваться `NSLocalizedString(...)`.

### 3.3 Дублирование result = nil

**Проблема #V-03 (Незначительная):** В `appendOperator()` `result = nil` устанавливается дважды: строки 48 и 53.

### 3.4 toggleSign — логическая проблема с форматированными числами

**Проблема #V-04 (Существенная):**

```swift
if let result, let val = Decimal(string: result) {
```

`Decimal(string:)` не распознаёт числа с тысячными разделителями: `Decimal(string: "1,000")` возвращает `nil`. Инвертирование знака для чисел >= 1000 не работает.

### 3.5 memoryAdd/memorySubtract — та же проблема

**Проблема #V-05 (Существенная):**

```swift
guard let result, let val = Decimal(string: result) else { return }
```

Аналогичная проблема — операции памяти молча не работают для форматированных чисел.

### 3.6 Научные функции не реализованы в движке

**Проблема #V-06 (Критическая):** При нажатии `sin⁻¹` вызывается `appendFunction("asin")`, формируя строку `"asin(выражение)"`. Tokenizer не знает слова `asin` — символ `a` вызовет `invalidCharacter`. Весь научный режим (sin, cos, tan, sqrt, log и т.д.) **не работает функционально**. SRS §11 прямо запрещает такие функции.

---

## 4. Аудит пользовательского интерфейса

### 4.1 Нарушение SRS §11 — наличие научного режима

**Проблема #UI-01 (Критическая):** В `CalculatorView.swift` реализован `CalculatorMode.scientific` с кнопками `sin⁻¹`, `cos⁻¹`, `tan⁻¹`, `sinh⁻¹`, `log₂`, `x!` и др. SRS §11 **категорически запрещает**:
> «инженерный режим; научный режим; тригонометрию; логарифмы»

### 4.2 TODO в production-коде

**Проблема #UI-02 (Существенная):**

```swift
case .secondFunc:
    break // TODO: переключение режима кнопок (2ⁿᵈ)
```

SRS §93: «Нет TODO. Нет временных решений. Нет заглушек.»

### 4.3 formattedExpression — ошибки форматирования

В `DisplayView.swift`:

```swift
private var formattedExpression: String {
    expression
        .replacingOccurrences(of: "/", with: " ÷ ")
        .replacingOccurrences(of: "*", with: " × ")
        .replacingOccurrences(of: "-", with: " − ")
        .replacingOccurrences(of: ".", with: ",")
}
```

**Проблема #UI-03 (Критическая):** `.replacingOccurrences(of: ".", with: ",")` заменяет **все** точки безусловно, без учёта локали. В английской локали `3.14` отобразится как `3,14` — некорректно.

**Проблема #UI-04 (Критическая):** `replacingOccurrences(of: "-", with: " − ")` применяется глобально, не различая унарный и бинарный минус. Выражение `-(15+16)` превратится в ` − (15 − 16)` вместо `−(15 + 16)`.

### 4.4 Ширина кнопки «0» — захардкоженный spacing

**Проблема #UI-05 (Существенная):**

```swift
let targetWidth: CGFloat = spec.isWide ? diameter * 2 + 12 : diameter
```

В `CalculatorView` `buttonSpacing = 14`, но в кнопке захардкожено `+12`. При изменении `buttonSpacing` кнопка «0» будет несовпадать.

### 4.5 Выражение исчезает при показе результата

**Проблема #UI-06 (Существенная):**

```swift
if !expression.isEmpty && result == nil && errorMessage == nil {
    Text(formattedExpression)
```

После нажатия «=» пользователь видит только результат без контекста. SRS §52 требует показывать и выражение, и результат.

### 4.6 HistoryPanelView обращается к Singleton напрямую

**Проблема #UI-07 (Существенная):** View напрямую вызывает `HistoryService.shared.getEntries()`, `HistoryService.shared.clear()`. SRS §17-18 требует Dependency Injection через ViewModel. При очистке истории кнопкой «Clear» список не обновляется реактивно — UX-баг.

### 4.7 Строки в History захардкожены

**Проблема #UI-08 (Существенная):** `"No History"`, `"Calculations will appear here"`, `"History"`, `"Done"`, `"Clear"` — все захардкожены, несмотря на наличие ключей в `Localizable.strings`. SRS §82 нарушен.

### 4.8 Task в DisplayView без управления жизненным циклом

**Проблема #UI-09 (Незначительная):**

```swift
Task {
    try? await Task.sleep(nanoseconds: 350_000_000)
    shakeOffset = 0  // неявное захватывание self
}
```

Если View уничтожается до завершения Task, возможно обращение к освобождённому объекту.

### 4.9 KeyHandlerNSView без @MainActor

**Проблема #UI-10 (Существенная):** `KeyHandlerNSView` вызывает методы `@MainActor`-аннотированного `CalculatorViewModel`, но сам не помечен `@MainActor`. В Swift 6 strict concurrency это генерирует предупреждения.

---

## 5. Аудит сервисов

### 5.1 NumberFormatterService — локаль не задана явно

**Проблема #S-01 (Существенная):** `NumberFormatter` без явной локали использует `Locale.current`. Тесты на машине с русской локалью вернут `"15,5"` вместо `"15.5"`, ломая `XCTAssertEqual`.

### 5.2 Неверная логика форматирования экспоненциальных чисел

**Проблема #S-02 (Существенная):**

```swift
return formatted.replacingOccurrences(of: "e+", with: "")
    .replacingOccurrences(of: "e-", with: "e-")
```

`NumberFormatter` со стилем `.scientific` выдаёт `"E"` (заглавную), а не `"e"`. Замена `"e+"` ничего не изменит для строк типа `"1.5E+3"`. На `"1.5e+3"` даст `"1.53"` (удалено `e+`, осталось только `1.53`) — некорректный результат.

### 5.3 NumberFormatterService — противоречивый дизайн

**Проблема #S-03 (Незначительная):** `NumberFormatterService` одновременно является `struct` (копируемым типом) и singleton. Каждый `NumberFormatterService()` создаёт новый `NumberFormatter` — тяжёлый объект.

### 5.4 Decimal.displayString — нарушение DRY и производительности

**Проблема #S-04 (Существенная):** `Decimal+Extensions.swift` создаёт `NumberFormatter()` внутри вычисляемого свойства при каждом обращении. `NumberFormatter` — тяжёлый объект. Функциональность дублирует `NumberFormatterService.format()`.

### 5.5 isMathExpression — мёртвый код

**Проблема #S-05 (Незначительная):** `ClipboardManager.isMathExpression()` и `String.isMathExpression` дублируют одну логику. Оба нигде не вызываются в основном коде.

---

## 6. Аудит тестов

### 6.1 Тесты не интегрированы в Package.swift

**Проблема #T-01 (Критическая):** Нет `.testTarget()` в `Package.swift`. `swift test` не выполнит ни одного теста. SRS §90 нарушен.

### 6.2 Тест testTokenize_PiKeyword неверен

**Проблема #T-02 (Критическая):** Как указано в #E-01, `"pi"` не распознаётся Tokenizer'ом. Тест ожидает 1 токен — должен падать с `invalidCharacter("p")`.

### 6.3 testTokenize_EulerNumberWithExponent — неверное ожидание

**Проблема #T-03 (Существенная):** Тест ожидает `v == 1000` для `"e3"`. Это недостижимо данным кодом (см. #E-02).

### 6.4 testEvaluate_NestedParentheses — нестабильное сравнение

**Проблема #T-04 (Существенная):**

```swift
let expected = Decimal(string: "51.6666666667")!
XCTAssertEqual(result.description, expected.description)
```

Сравнение через `.description` ненадёжно при работе с `Decimal`.

### 6.5 Отсутствуют тесты для критических компонентов

**Проблема #T-05 (Существенная):** По SRS §90-91 требуются тесты для:
- `NumberFormatterService` — **отсутствуют**
- `HistoryService` — **отсутствуют**
- `ClipboardManager` — **отсутствуют**
- `CalculatorViewModel` — **отсутствуют**

---

## 7. Аудит локализации

### 7.1 Локализация декларирована, но не используется

**Проблема #L-01 (Критическая):** Файлы `Localizable.strings` (en/ru) существуют, но нигде в коде не используется `NSLocalizedString()` или `String(localized:)`:
- `CalculatorError.errorDescription` — захардкоженный английский
- `HistoryPanelView` — захардкоженный английский  
- `insertFromClipboard()` — `errorMessage = "Cannot evaluate"`

Русская локализация полностью не работает, несмотря на наличие переводов.

### 7.2 Недостающие ключи в Localizable.strings

В файлах отсутствуют ключи для:
- `errors.invalidCharacter`
- `errors.numberOverflow`
- `errors.invalidNumber`
- `errors.multipleDecimalSeparators`
- Accessibility-описаний кнопок

---

## 8. Аудит Accessibility

**Проблема #ACC-01 (Существенная):** Отсутствуют `accessibilityHint` для кнопок. SRS §83 требует `accessibilityHint` при необходимости.

**Проблема #ACC-02 (Существенная):** Для кнопок `xToY` (`xʸ`), `sqrtN(0)` (`ʸ√x`) — `accessibilityDescription` возвращает математические символы через `default: displayTitle`. VoiceOver прочтёт нечитаемые символы.

**Проблема #ACC-03 (Незначительная):** Поддержка `Tab`/`Shift+Tab` (SRS §68) не тестируется явно.

---

## 9. Аудит горячих клавиш

SRS §68 требует: `⌘C`, `⌘V`, `⌘A`, `⌘Z`.

**Реализовано:** `⌘C` ✅, `⌘V` ✅

**Проблема #K-01 (Существенная):** `⌘A` (выделить всё) и `⌘Z` (отмена) не реализованы.

---

## 10. Аудит восстановления состояния

**Проблема #ST-01 (Существенная):** История хранится только в памяти (`HistoryService.entries: [HistoryEntry]`). При закрытии приложения история **теряется**. Нет `UserDefaults`, `CoreData` или файлового хранилища. SRS §79 (SHOULD): «желательно сохранить историю».

**Проблема #ST-02 (Существенная):** Позиция и размер окна не сохраняются. `.windowResizability(.contentSize)` не обеспечивает автоматическое сохранение позиции.

---

## 11. Итоговая таблица MUST-требований SRS (§8)

| Требование | Статус | Проблемы |
|------------|--------|----------|
| Сложение, вычитание, умножение, деление | ✅ | — |
| Проценты | ✅ | — |
| Отрицательные числа | ✅ | — |
| Десятичные дроби | ✅ | — |
| Вложенные скобки | ✅ | — |
| Длинные выражения | ✅ | — |
| Буфер обмена (⌘V) | ⚠️ | #V-01: выражение не отображается |
| Горячие клавиши | ⚠️ | #K-01: ⌘A, ⌘Z не реализованы |
| История вычислений | ⚠️ | #ST-01: не сохраняется между сессиями |
| Light Mode | ✅ | — |
| Dark Mode | ✅ | — |
| Локализация | ❌ | #L-01: декларирована, но не работает |
| Accessibility | ⚠️ | #ACC-01, #ACC-02 |
| Retina | ✅ | SwiftUI нативно |
| Изменение размера окна | ✅ | — |
| Работа с клавиатуры | ⚠️ | #K-01 |

---

## 12. Нарушения запретов SRS (§11)

| Запрет SRS | Статус |
|------------|--------|
| Инженерный/научный режим | ❌ **НАРУШЕН** (#UI-01) |
| Тригонометрия | ❌ **НАРУШЕНА** (кнопки sin⁻¹, cos⁻¹, tan⁻¹) |
| Логарифмы | ❌ **НАРУШЕНЫ** (кнопка log₂) |
| Сторонние зависимости | ✅ Нет |
| Телеметрия | ✅ Нет |
| WebView/Electron/Flutter | ✅ Нет |

---

## 13. Приоритизированный список всех проблем

### 🔴 Критические — блокируют Definition of Done

| ID | Файл | Описание |
|----|------|----------|
| #A-03 | Package.swift | Тесты не зарегистрированы — swift test не работает |
| #E-01 | Tokenizer.swift:90 | `char.lowercased() == "pi"` — логически невозможное условие |
| #E-02 | Tokenizer.swift:96-113 | Неоднозначное и неверное поведение `e3` |
| #E-03 | Parser.swift:84-89 | Неверная ошибка при незакрытой скобке (extra вместо missing) |
| #V-01 | CalculatorViewModel.swift:182-183 | При вставке из буфера выражение не отображается пользователю |
| #V-06 | CalculatorView.swift:242-243 | Научные функции не реализованы в движке — весь scientific режим сломан |
| #UI-01 | CalculatorView.swift:5-7 | Научный режим запрещён SRS §11 |
| #UI-03 | DisplayView.swift:108 | formattedExpression: точки в числах заменяются на запятые безусловно |
| #UI-04 | DisplayView.swift:107 | Унарный и бинарный минус не различаются при форматировании |
| #L-01 | Весь проект | Локализация декларирована, но NSLocalizedString нигде не используется |
| #T-01 | Package.swift | Тесты не интегрированы в Package.swift |
| #T-02 | TokenizerTests.swift:125 | testTokenize_PiKeyword: ожидание 1 токена неверно из-за #E-01 |

### 🟡 Существенные — снижают качество и соответствие SRS

| ID | Файл | Описание |
|----|------|----------|
| #A-02 | Package.swift | Пропущены Components/, Extensions/, Localization/ в sources |
| #A-04 | HistoryService.swift | NSLock вместо actor — нарушение SRS §87 |
| #E-04 | Evaluator.swift | Отсутствует проверка переполнения Decimal |
| #E-05 | Tokenizer.swift:158-163 | Тысячные разделители работают только в одиночных числах |
| #E-06 | Tokenizer.swift:216-218 | Потенциальный бесконечный цикл при ошибке readNumber |
| #V-02 | CalculatorViewModel.swift:187 | Захардкоженная строка "Cannot evaluate" |
| #V-04 | CalculatorViewModel.swift:102 | toggleSign не работает с форматированными числами (тысячи) |
| #V-05 | CalculatorViewModel.swift:122-128 | memoryAdd/Subtract не работают с форматированными числами |
| #UI-02 | CalculatorView.swift:241 | TODO в production-коде |
| #UI-05 | CalculatorButton.swift:213 | Ширина кнопки «0» захардкожена (+12 вместо реального spacing) |
| #UI-06 | DisplayView.swift:15 | Выражение скрывается при отображении результата |
| #UI-07 | HistoryPanelView.swift | Прямое обращение к Singleton вместо ViewModel |
| #UI-08 | HistoryPanelView.swift | Строки захардкожены, Localizable.strings не используется |
| #UI-10 | CalculatorApp.swift:50 | KeyHandlerNSView не помечен @MainActor |
| #S-01 | NumberFormatterService.swift | Локаль не задана явно — нестабильное поведение в тестах |
| #S-02 | NumberFormatterService.swift:29 | Неверная логика replacingOccurrences для экспоненциальных строк |
| #S-04 | Decimal+Extensions.swift:24 | NumberFormatter создаётся при каждом вызове .displayString |
| #K-01 | CalculatorApp.swift | ⌘A и ⌘Z не реализованы (требуются SRS §68) |
| #ST-01 | HistoryService.swift | История не сохраняется между сессиями |
| #ST-02 | CalculatorApp.swift | Позиция/размер окна не сохраняются |
| #T-03 | TokenizerTests.swift:142 | Ожидание 1000 для "e3" логически неверно |
| #T-04 | CalculatorEngineTests.swift:45 | Нестабильное сравнение через .description |
| #T-05 | Tests/ | Нет тестов для NumberFormatterService, HistoryService, ViewModel |

### 🟢 Незначительные — улучшения качества кода

| ID | Файл | Описание |
|----|------|----------|
| #A-01 | Sources/Models/ | Пустая директория — мусор в проекте |
| #V-03 | CalculatorViewModel.swift:53 | result = nil дважды в appendOperator |
| #UI-09 | DisplayView.swift:43-46 | Task без управления жизненным циклом |
| #S-03 | NumberFormatterService.swift | Противоречивый дизайн struct+singleton |
| #S-05 | ClipboardManager.swift / String+Calculator.swift | isMathExpression — мёртвый код |
| #ACC-01 | CalculatorButton.swift | Отсутствуют accessibilityHint для кнопок |
| #ACC-02 | CalculatorButton.swift | VoiceOver для xʸ, ʸ√x нечитаем |
| #ACC-03 | — | Tab/Shift+Tab не тестируется явно |
| #P-01 | CalculatorViewModel.swift | Нет дебаунсинга tryAutoEvaluate при быстром вводе |

---

## 14. Выводы

Кодовая база содержит качественно написанное ядро вычислений (CalculatorEngine), грамотную архитектурную структуру и ряд удачных решений (Sendable, @Observable, @MainActor, Shunting Yard, AST). Однако проект **не соответствует Definition of Done** из SRS §93 по ключевым причинам:

1. **Грубое нарушение философии SRS**: реализован научный режим, который SRS §11 категорически запрещает
2. **Главная функция сломана**: при вставке выражения через ⌘V пользователь не видит само выражение (#V-01)
3. **Тесты не запускаются**: в Package.swift отсутствуют testTarget — `swift test` выдаёт 0 тестов
4. **Локализация не работает**: файлы ru/en созданы, но нигде не задействуются
5. **Критические ошибки в ядре**: неверная ошибка скобок (#E-03), нерабочее распознавание "pi" (#E-01), потенциальный бесконечный цикл (#E-06)

**Рекомендация по приоритетам:**

1. Устранить #UI-01/#V-06 (удалить научный режим — он запрещён SRS)
2. Исправить #V-01 (буфер обмена — главная функция)
3. Зарегистрировать тесты в Package.swift (#A-03, #T-01)
4. Подключить NSLocalizedString (#L-01, #V-02)
5. Исправить ошибки в Tokenizer (#E-01, #E-03, #E-06)
6. Устранить остальные существенные проблемы

---

*Аудит выполнен агентом Sonnet (Claude Sonnet 4.6 Thinking)*  
*Дата: 2026-07-05*  
*Проверено файлов: 28*  
*Выявлено проблем: 44 (12 критических, 23 существенных, 9 незначительных)*
