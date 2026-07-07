# Правила работы агента для проекта GateCalc

## Назначение документа

Данный файл содержит **обязательные правила работы** для проекта GateCalc — нативного macOS-калькулятора, написанного на Swift 6.0 с использованием SwiftUI и архитектуры MVVM.

**Контекст:** Swift 6.0 • SwiftUI • macOS 14.0+ (Sonoma) • Xcode / Swift Package Manager

---

## 1. Общение и взаимодействие

- Всё общение с пользователем ведётся **исключительно на русском языке** — независимо от языка, на котором пишет пользователь. Это касается всех объяснений, планов, анализа и ответов. Исключения: блоки кода, технические идентификаторы, пути к файлам и системный вывод, которые остаются на английском.
- **В коде**: все комментарии и документация (MARK, inline comments) пишутся **на русском языке**.
- **В коде**: все идентификаторы (переменные, функции, методы, классы, константы, enum-кейсы) пишутся **на английском языке**.
- **В коде**: все локализованные строки (в `NSLocalizedString`) хранятся в `.strings`-файлах, а не в коде.
- **Нет «самодеятельности»**: если есть идея, улучшение или отклонение от инструкций — **сначала предложите пользователю и дождитесь явного подтверждения**.
- Строго следуйте инструкциям пользователя. **Никаких допущений, импровизаций или вольной интерпретации**.
- Любой план или задача может начаться **только после отдельного явного подтверждения** (например, «вперёд», «выполняй», «согласовано»).
- Все рабочие планы **создаются и хранятся** в директории `.memory_bank/`.

---

## 2. Git — категорически запрещено

🚨 **КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО выполнять изменяющие команды Git:**
```
git commit, git branch, git checkout, git reset, git rm, git push, git add
```

**Только чтение РАЗРЕШЕНО:**
```
git status, git diff, git log, git show
```

Все изменения в репозитории вносятся **исключительно пользователем**. Агент может только **предложить** сделать коммит.

---

## 3. Консоль и файловые операции

- При использовании инструментов:
  - НИКОГДА не изменять пути к файлам
  - НИКОГДА не угадывать имена файлов
  - **Всегда использовать точные имена файлов**, включая пробелы, дефисы и спецсимволы. Не пытаться форматировать или упрощать пути к файлам.
  - Копировать пути к файлам ТОЧНО как указано
  - При сомнениях — спросить вместо угадывания

- Все остальные консольные команды выполняются через **bash**.

---

## 4. Нулевые галлюцинации

### 4.1. Основной принцип

🚨 **Никогда не предполагать и не угадывать.** Каждое утверждение о коде **должно** быть подтверждено прямым просмотром файла через `read` или `grep`.

### 4.2. Обязательная верификация перед использованием

Перед ссылкой на любой существующий класс/метод/свойство — **всегда проверять**:

1. **Существование** в кодовой базе (через `grep`)
2. **Точную сигнатуру метода** (через `read`)
3. **Видимость** (public / internal / private)
4. **Аргументы и типы возвращаемых значений**

### 4.3. Стандарт доказательств

Каждое фактическое утверждение о коде должно включать:
- **Путь к файлу:** `Sources/CalculatorEngine/CalculatorEngine.swift`
- **Номер строки:** `:23`
- **Фрагмент кода:** точный контекст (минимум 3 строки до и после)
- **Метод верификации:** какой инструмент подтвердил

```
✅ ПРАВИЛЬНО:
"Метод evaluate() определён в Sources/CalculatorEngine/CalculatorEngine.swift:23
и принимает параметр expression типа String, возвращая Decimal."

❌ НЕПРАВИЛЬНО:
"Система, вероятно, вычисляет результат из выражения."
```

### 4.4. Декларация неопределённости

Если факт не может быть верифицирован — **использовать обязательный формат:**
```
"НЕ ВЕРИФИЦИРОВАНО: Не удалось найти [класс/метод/файл] потому что [причина].
Утверждение основано на [доказательство] и может быть неточным."
```

---

## 5. Потокобезопасность (Swift 6.0 Concurrency)

Проект использует Swift 6.0 с строгой проверкой потокобезопасности. Все правила обязательны.

### 5.1. Пометки потокобезопасности

| Механизм | Где применяется | Зачем |
|---|---|---|
| `@MainActor` | `CalculatorViewModel`, `KeyHandlerNSView` | Все обновления UI-состояния происходят на главном потоке |
| `@unchecked Sendable` | `HistoryService`, `ClipboardManager` | Статический анализатор не может проверить NSLock — ручная пометка |
| `Sendable` | `CalculatorEngine`, `Tokenizer`, `Parser`, `Evaluator` | Вычислительный движок полностью потокобезопасен |
| `NSLock` | `HistoryService`, `ClipboardManager` | Синхронизация доступа к разделяемым ресурсам |

### 5.2. Правила

- Все View-модели должны быть помечены `@MainActor`
- Все сервисы с общим состоянием (`shared`) должны использовать `NSLock` для синхронизации
- Вычислительный движок должен оставаться полностью `Sendable` и stateless
- При добавлении новых общих ресурсов — обязательно добавлять `NSLock` или использовать `actor`

---

## 6. Архитектура (MVVM)

### 6.1. Разделение ответственности

| Слой | Файлы | Ответственность |
|---|---|---|
| **App** | `Sources/App/CalculatorApp.swift` | Точка входа (@main), WindowGroup, CalculatorContentView, KeyHandlerView (NSViewRepresentable), KeyHandlerNSView (NSView) |
| **Views** | `Sources/Views/*.swift` | Визуальные компоненты (CalculatorView, DisplayView, CalculatorButton, HistoryPanelView) |
| **ViewModel** | `Sources/ViewModels/CalculatorViewModel.swift` | Состояние приложения, методы ввода/вычисления/памяти |
| **Services** | `Sources/Services/*.swift` | Сервисы (HistoryService) |
| **Engine** | `Sources/CalculatorEngine/*.swift` | Вычислительный движок (Tokenizer, Parser, Evaluator) |
| **Support** | `Sources/Clipboard/*.swift`, `Sources/Formatting/*.swift`, `Sources/Theme/*.swift`, `Sources/History/*.swift` | Вспомогательные компоненты |

### 6.2. Запреты

🚨 **В View-слое запрещено:**
- Напрямую обращаться к вычислительному движку
- Содержать бизнес-логику вычислений
- Методы длиннее ~20 строк — признак архитектурного дефекта

🚨 **В ViewModel запрещено:**
- Ссылаться на View напрямую
- Использовать `NSLock` (это ответственность сервисов)

🚨 **В вычислительном движке запрещено:**
- Импортировать SwiftUI или AppKit
- Иметь mutable состояние между вызовами

### 6.3. Связь View ↔ ViewModel

- Связь осуществляется через `@Bindable` (SwiftUI) и `@Observable` (Observation framework)
- ViewModel не ссылается на View напрямую
- Все обновления UI происходят через `@MainActor`

---

## 7. Swift — строгая типизация

### 7.1. Обязательные правила

```swift
// Всегда объявлять типы параметров и возвращаемых значений:
func evaluate(_ expression: String) throws -> Decimal { ... }

// Использовать опциональные типы где уместно:
var result: String? = nil

// Использовать guard для раннего выхода:
guard !trimmed.isEmpty else { throw CalculatorError.emptyExpression }
```

### 7.2. Запрещённые конструкции

🚨 **ЗАПРЕЩЕНО в бизнес-логике:**
```swift
// ❌ Использовать force unwrap без необходимости:
let value = dict["key"]!     // Только если гарантировано наличие ключа

// ❌ Использовать as! без проверки:
let view = controller.view as! SomeView

// ❌ Игнорировать ошибки:
try? someThrowingFunction()   // Только если игнорирование осознанно
```

### 7.3. Swift 6.0 — запрещённые конструкции

🚨 **Следующий синтаксис вызовет предупреждения или ошибки в Swift 6.0:**

| Запрещено | Пример |
|---|---|
| Неявная конкатенация строк | `"count: " + count` → используйте `"\(count)"` |
| Мутабельные захваты в замыканиях | `{ items.append(x) }` → используйте `[items]` или `inout` |

✅ **Разрешённый синтаксис Swift 6.0:**
```swift
// ✅ Строгая типизация
func process(_ input: String) -> Result { }

// ✅ Sendable-протоколы
struct CalculatorEngine: Sendable { }

// ✅ @MainActor для UI
@MainActor final class CalculatorViewModel { }

// ✅ Опциональные типы
var errorMessage: String? = nil
```

---

## 8. Naming Conventions (Swift)

| Элемент | Стиль | Пример |
|---|---|---|
| Классы/структуры/enum | `PascalCase` | `CalculatorEngine`, `HistoryService` |
| Свойства и методы | `camelCase` | `appendCharacter()`, `hasResult` |
| Константы | `camelCase` (static let) | `static let shared` |
| Enum-кейсы | `camelCase` | `.number`, `.binaryOperator`, `.add` |
| Протоколы | `PascalCase` | `Sendable`, `LocalizedError` |
| Файлы | `PascalCase` | `CalculatorEngine.swift`, `Tokenizer.swift` |

---

## 9. Чистота кода и качество

### 9.1. Базовые правила

- **Всегда использовать константы** вместо магических чисел и строк:
  ```swift
  static let maxEntries = 50      // ✅
  50                               // ❌ Магическое число
  ```
- **Следовать стилю Swift API Design Guidelines:**
  - Отступы: **4 пробела** (без табуляций)
  - Длина строки: **≤ 120 символов**
  - Одна пустая строка между методами
  - Без trailing whitespace

### 9.2. Обработка ошибок

🚨 **ЗАПРЕЩЕНО «проглатывать» ошибки:**
```swift
// ❌ ЗАПРЕЩЕНО:
catch {
    return          // Тихая ошибка
}

catch {
    // Пустой catch-блок
}

try? operation()    // Подавление ошибок
```

✅ **Правильная обработка:**
```swift
// ✅ Правильно — показать пользователю:
catch {
    errorMessage = error.localizedDescription
}

// ✅ Правильно — пробросить выше:
catch {
    throw CalculatorError.invalidExpression("\(error)")
}
```

🚨 **Нет PII в логах:** Личные данные, пароли, токены **не должны** попадать в логи.

---

## 10. Верификация классов и методов (обязательный анализ)

### 10.1. Полная цепочка наследования

Для каждого анализируемого класса **обязательно**:

```
✅ Построить ПОЛНОЕ дерево наследования:
   CalculatorViewModel (final class, @MainActor, @Observable)
   HistoryService (final class, @unchecked Sendable)
   ClipboardManager (final class, @unchecked Sendable)

✅ Задокументировать ВСЕ протоколы:
   CalculatorEngine: Sendable
   Tokenizer: Sendable
   Parser: Sendable
   Evaluator: Sendable
   ExpressionNode: Sendable
   CalculatorError: Error, LocalizedError, Sendable
   HistoryEntry: Identifiable, Sendable
   NumberFormatterService: Sendable
   Precedence: Int, Sendable
   Token: Equatable, Sendable
   BinaryOperator: Sendable

✅ Проверить все computed properties:
   CalculatorViewModel.hasResult -> Bool (computed)
   CalculatorViewModel.historyCount -> Int (computed)
   CalculatorViewModel.historyEntries -> [HistoryEntry] (computed)
   CalculatorViewModel.hasMemory -> Bool (computed)
   CalculatorViewModel.memoryDisplayValue -> String? (computed, public)
```

### 10.2. Аудит зависимостей

Для каждого конструктора:
```
✅ Задокументировать ВСЕ параметры
✅ Проверить совпадение типов аргументов с реальными классами
✅ Проверить, что параметры сохраняются как свойства
✅ Задокументировать, какие сервисы инжектируются

🚨 Искать запрещённые паттерны:
   - Прямое создание через new/init в бизнес-логике
   - Глобальные переменные вместо инъекции зависимостей
```

### 10.3. Маппинг внешних вызовов

Для каждого метода создать граф вызовов:
```
Метод evaluate() вызывает:
- engine.evaluate(expression)    — метод движка
- formatter.format(value)        — метод форматирования
- historyService.add(...)        — метод сервиса

✅ Для каждого вызова проверить:
   1. Количество аргументов совпадает с сигнатурой
   2. Совместимость типов аргументов
   3. Обработка возвращаемого значения
   4. Любое неявное приведение типов
```

---

## 11. Анализ регрессий и побочных эффектов

### 11.1. Анализ влияния регрессий

При модификации **базовых классов** (`CalculatorViewModel`, `HistoryService`, `CalculatorEngine`):
```
✅ Определить ВСЕХ потребителей модифицируемого метода/класса
✅ Проверить, что изменения не ломают существующую функциональность
✅ Проверить обратную совместимость
✅ Задокументировать потенциальные точки регрессии
```

### 11.2. Очистка отладочного кода

🚨 **Перед завершением любой задачи — ОБЯЗАТЕЛЬНО проверить и удалить:**
```
print()
debugPrint()
NSLog()
fatalError()    (если добавлен для отладки)
```

### 11.3. Верификация побочных эффектов

```
✅ Для каждого модифицированного файла:
   1. Определить ВСЕ изменения
   2. Пометить изменения, НЕ указанные в плане реализации
   3. Классифицировать каждое незапланированное изменение:
      - Необходимые побочные (импорты, типы)
      - Случайная регрессия (изменения в несвязанной логике)
      - Отладочный код
   4. Задокументировать и пометить случайные регрессии для удаления
```

---

## 12. Workflow перед написанием кода

**Обязательные шаги перед любой задачей:**

1. **Проанализировать запрос** — какие архитектурные слои затронуты?
2. **Создать чёткий план** — например:
   - "Добавить метод X в CalculatorViewModel → обновить CalculatorView → добавить тесты"
3. **Проверить согласованность** — изучить существующие файлы, следовать тем же именам, стилю и паттернам
4. **Нулевые галлюцинации** — каждое решение в плане должно основываться на **конкретных фактах** из текущей кодовой базы

---

## 13. Чеклист самопроверки перед завершением задачи

Перед объявлением задачи выполненной, **проверить:**

- [ ] Нет `print()`, `debugPrint()`, `NSLog()`, `fatalError()` (отладочный код)
- [ ] Нет force unwrap (`!`) без обоснованной гарантии
- [ ] Все новые типы имеют `Sendable` (если используются вне `@MainActor`)
- [ ] Все методы имеют объявленные типы параметров и возвращаемых значений
- [ ] MARK-комментарии на русском языке
- [ ] Идентификаторы на английском языке
- [ ] Нет импортов SwiftUI в вычислительном движке
- [ ] Все исключения обрабатываются (не «проглатываются»)
- [ ] Нет изменяющих Git-команд
- [ ] Все утверждения о коде подтверждены ссылками на файл и строку

---

## 14. Справочная информация

### 14.1. Известные типы в проекте

| Тип | Файл | Описание |
|---|---|---|
| `CalculatorEngine` | `Sources/CalculatorEngine/CalculatorEngine.swift` | Фасад вычислительного движка |
| `Tokenizer` | `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift` | Лексический анализатор |
| `Parser` | `Sources/CalculatorEngine/Parser/Parser.swift` | Синтаксический анализатор (Shunting Yard) |
| `Evaluator` | `Sources/CalculatorEngine/Evaluator/Evaluator.swift` | Вычислитель AST |
| `Token` | `Sources/CalculatorEngine/Tokenizer/Token.swift` | Enum токенов |
| `BinaryOperator` | `Sources/CalculatorEngine/Tokenizer/Token.swift` | Enum бинарных операторов |
| `ExpressionNode` | `Sources/CalculatorEngine/AST/ExpressionNode.swift` | AST узел (indirect enum) |
| `CalculatorError` | `Sources/CalculatorEngine/Errors/CalculatorError.swift` | Enum ошибок (10 кейсов) |
| `Precedence` | `Sources/CalculatorEngine/Parser/Precedence.swift` | Enum приоритетов операторов (Int, Sendable) |
| `CalculatorViewModel` | `Sources/ViewModels/CalculatorViewModel.swift` | ViewModel приложения (@MainActor, @Observable) |
| `CalculatorView` | `Sources/Views/CalculatorView.swift` | Главный вид калькулятора |
| `CalculatorButton` | `Sources/Views/CalculatorButton.swift` | Компонент кнопки (View) |
| `DisplayView` | `Sources/Views/DisplayView.swift` | Дисплей (выражение + результат) |
| `HistoryPanelView` | `Sources/Views/HistoryPanelView.swift` | Панель истории |
| `CalculatorApp` | `Sources/App/CalculatorApp.swift` | Точка входа (@main) |
| `KeyHandlerView` | `Sources/App/CalculatorApp.swift:36` | NSViewRepresentable обёртка для клавиатуры |
| `KeyHandlerNSView` | `Sources/App/CalculatorApp.swift:52` | NSView для перехвата клавиатуры (@MainActor) |
| `HistoryService` | `Sources/Services/HistoryService.swift` | Сервис истории (@unchecked Sendable, NSLock) |
| `ClipboardManager` | `Sources/Clipboard/ClipboardManager.swift` | Менеджер буфера обмена (@unchecked Sendable, NSLock) |
| `NumberFormatterService` | `Sources/Formatting/NumberFormatterService.swift` | Форматирование чисел (Sendable) |
| `CalculatorColors` | `Sources/Theme/CalculatorColors.swift` | Цветовая система |
| `HistoryEntry` | `Sources/History/HistoryEntry.swift` | Модель записи истории (Identifiable, Sendable) |
| `ButtonLabel` | `Sources/Views/CalculatorButton.swift:16` | Enum меток кнопок (19 кейсов) |
| `CalcButtonType` | `Sources/Views/CalculatorButton.swift:5` | Enum типов кнопок (.digit, .operator, .function) |
| `ButtonSpec` | `Sources/Views/CalculatorButton.swift:105` | Структура спецификации кнопки (Identifiable) |
| `AnyShape` | `Sources/Views/CalculatorButton.swift:241` | Обёртка для совместимости Shape |

### 14.2. Безопасные статические вызовы

| Вызов | Описание |
|---|---|
| `HistoryService.shared` | Singleton сервиса истории |
| `ClipboardManager.shared` | Singleton менеджера буфера обмена |
| `NumberFormatterService.shared` | Singleton форматирования чисел |
| `CalculatorColors.*` | Статические цвета приложения |
| `NSLocalizedString(key, comment:)` | Локализованные строки |

### 14.3. Структура проекта (ключевые директории)

```
Sources/
├── App/                    — Точка входа (CalculatorApp, KeyHandlerView, KeyHandlerNSView)
├── Views/                  — Виды (CalculatorView, DisplayView, CalculatorButton, HistoryPanelView)
├── ViewModels/             — ViewModel (CalculatorViewModel)
├── Services/               — Сервисы (HistoryService)
├── CalculatorEngine/       — Вычислительный движок (отдельный модуль)
│   ├── Tokenizer/          — Токенизатор (Tokenizer, Token, BinaryOperator)
│   ├── Parser/             — Парсер (Parser, Precedence)
│   ├── AST/                — AST (ExpressionNode)
│   ├── Evaluator/          — Вычислитель (Evaluator)
│   └── Errors/             — Ошибки (CalculatorError)
├── Clipboard/              — Буфер обмена (ClipboardManager)
├── Formatting/             — Форматирование (NumberFormatterService)
├── Theme/                  — Тема (CalculatorColors)
├── History/                — Модель истории (HistoryEntry)
├── Localization/           — Локализация (en.lproj, ru.lproj)
└── TestRunner/             — Консольный тестер (executable target в Package.swift)
Tests/
├── Unit/                   — Юнит-тесты (файлы на диске, но НЕ определены как SPM targets)
│   ├── EvaluatorTests.swift
│   ├── TokenizerTests.swift
│   ├── ParserTests.swift
│   └── CalculatorEngineTests.swift
└── UI/                     — UI-тесты (файлы на диске, но НЕ определены как SPM targets)
    └── CalculatorUITests.swift

🚨 ВАЖНО: Tests/ содержит файлы тестов, но Package.swift НЕ определяет
   тестовые цели (test targets). Команда `swift test` работать не будет.
   Тестовые файлы существуют на диске, но не включены в сборку SPM.
```

### 14.4. Текущее состояние ViewModel (верифицировано)

**Свойства:**

| Свойство | Тип | Видимость | Описание |
|---|---|---|---|
| `expression` | `String` | public (var) | Текущее выражение (внутреннее, ASCII). Пустая строка по умолчанию |
| `result` | `String?` | public (var) | Отформатированный результат. nil по умолчанию |
| `resultDecimal` | `Decimal?` | internal (var) | Результат в виде Decimal. nil по умолчанию |
| `errorMessage` | `String?` | public (var) | Текст ошибки. nil по умолчанию |
| `memoryValue` | `Decimal` | private (var) | Значение в памяти калькулятора. 0 по умолчанию |
| `hasResult` | `Bool` | public (computed) | `resultDecimal != nil` |
| `historyCount` | `Int` | public (computed) | Количество записей в истории (`historyService.count()`) |
| `historyEntries` | `[HistoryEntry]` | public (computed) | Записи истории (`historyService.getEntries()`) |
| `hasMemory` | `Bool` | public (computed) | `memoryValue != 0` |
| `currentDisplayValue` | `Decimal?` | private (computed) | Текущее значение на дисплее для операций памяти. Если есть resultDecimal — возвращает его, иначе пытается вычислить expression |
| `memoryDisplayValue` | `String?` | public (computed) | Отформатированное значение памяти для отображения в UI. nil если memoryValue == 0 |

**Приватные зависимости (инициализируются в конструкторе):**

| Зависимость | Тип | Описание |
|---|---|---|
| `engine` | `CalculatorEngine` | Вычислительный движок (private) |
| `historyService` | `HistoryService` | Сервис истории — singleton (private) |
| `formatter` | `NumberFormatterService` | Сервис форматирования — singleton (private) |

**Методы:**

| Метод | Описание |
|---|---|
| `appendCharacter(_ char: String)` | Основной метод ввода символа. При hasResult && !isOperator — сбрасывает выражение и результат |
| `appendOperator(_ op: String)` | Метод-заглушка (не вызывается из UI, оставлен для совместимости) |
| `evaluate()` | Вычисление выражения. Форматирует результат, добавляет в историю, сбрасывает expression |
| `clear()` | Полная очистка состояния (expression, result, resultDecimal, errorMessage) |
| `backspace()` | Удаление последнего символа. При пустом expression и hasResult — полный сброс |
| `toggleSign()` | Инверсия знака текущего числа/выражения |
| `memoryClear()` | Очистка памяти (memoryValue = 0) |
| `memoryAdd()` | Добавление currentDisplayValue в память |
| `memorySubtract()` | Вычитание currentDisplayValue из памяти |
| `memoryRecall()` | Запись memoryValue в expression, сброс result |
| `handleKeyCommand(_ key: String)` | Обработка клавиатурных команд (вызывается из KeyHandlerNSView) |
| `insertFromClipboard(_ text: String)` | Вставка текста из буфера обмена в expression |
| `copyResult()` | Копирование отформатированного результата в буфер обмена |
| `useHistoryEntry(_ entry: HistoryEntry)` | Восстановление выражения и результата из записи истории |
| `clearHistory()` | Очистка всей истории через HistoryService |

**Вспомогательные методы:**

| Метод | Видимость | Описание |
|---|---|---|
| `clearError()` | private | Сброс errorMessage в nil |
| `tryAutoEvaluate()` | private | Попытка автоматического вычисления при вводе операторов |
| `isDigitOrDecimal(_ char: String)` | private | Проверка, является ли символ цифрой или десятичным разделителем |
| `isOperator(_ char: String)` | private | Проверка, является ли символ оператором |

### 14.5. Структура вычислительного движка (CalculatorEngine)

**Фасад:**
```swift
public struct CalculatorEngine: Sendable {
    public func evaluate(_ expression: String) throws -> Decimal
}
```

**Цепочка обработки выражения:**
```
expression (String)
  → Tokenizer.tokenize() → [Token]
  → Parser.parse() → ExpressionNode (AST)
  → Evaluator.evaluate() → Decimal
```

**Token:**
```swift
public enum Token: Equatable, Sendable {
    case number(Decimal)
    case binaryOperator(BinaryOperator)
    case unaryMinus
    case leftParenthesis
    case rightParenthesis
    case percent
}

public enum BinaryOperator: String, Sendable {
    case add, subtract, multiply, divide
}
```

**ExpressionNode (indirect enum):**
```swift
public indirect enum ExpressionNode: Sendable {
    case number(Decimal)
    case unaryMinus(ExpressionNode)
    case binary(BinaryOperator, ExpressionNode, ExpressionNode)
}
```

**CalculatorError (10 кейсов):**
```swift
public enum CalculatorError: Error, LocalizedError, Sendable {
    case divisionByZero
    case invalidExpression(String)
    case missingClosingParenthesis
    case extraClosingParenthesis
    case invalidCharacter(String)
    case emptyExpression
    case numberOverflow
    case invalidNumber(String)
    case doubleOperator
    case multipleDecimalSeparators
}
```

**Precedence (приоритеты операций):**
```swift
enum Precedence: Int, Sendable {
    case addition = 1
    case multiplication = 2
    case unaryMinus = 3
    case percent = 4
}
```

### 14.6. Структура Views

**CalculatorView:**
- `@Bindable var viewModel: CalculatorViewModel` — привязка к ViewModel
- `@Binding var showHistory: Bool` — управление видимостью панели истории
- Константы размеров: `buttonDiameter = 60`, `buttonFontSize = 18`, `buttonSpacing = 8`
- Private computed: `isAC: Bool` — определяет, показывать «AC» или «C»

**CalculatorButton:**
- Принимает `ButtonSpec`, `diameter`, `fontSize`, `isAC`, `spacing`, `onTap`
- `@State private var isPressed = false` — визуальная обратная связь нажатия
- Поддержка `accessibilityReduceMotion` через Environment

**ButtonLabel (19 кейсов):**
- Стандартные: `.digit(String)`, `.decimalSeparator`, `.clear`, `.backspace`, `.plusMinus`, `.percent`
- Операторы: `.divide`, `.multiply`, `.subtract`, `.add`, `.equals`
- Скобки: `.openParen`, `.closeParen`
- Память и константы: `.mc`, `.mPlus`, `.mMinus`, `.mR`, `.pi`, `.eulerConst`
- Computed: `displayTitle`, `inputValue`, `accessibilityDescription`

**CalcButtonType (3 кейса):**
- `.digit` — цифры 0–9, запятая, +/−
- `.operator` — арифметические операторы
- `.function` — функциональные кнопки

**ButtonSpec:**
- `let id = UUID()`, `label: ButtonLabel`, `type: CalcButtonType`
- `var isWide: Bool` — широкая кнопка «0»
- `var isEnabled: Bool`, `hasMemoryIndicator: Bool`, `memoryTooltip: String?`

**DisplayView:**
- Отображает `expression`, `result`, `errorMessage`
- Минимальная высота: 90pt

**HistoryPanelView:**
- `@Bindable var viewModel: CalculatorViewModel`
- Использует `viewModel.historyEntries` и `NumberFormatterService.shared.format()`

### 14.7. KeyHandlerNSView (перехват клавиатуры)

**Обработка keyDown (keyCode → действие):**
| keyCode | Клавиша | Действие |
|---|---|---|
| 53 | Escape | `viewModel.clear()` |
| 51 | Backspace/Delete | `viewModel.backspace()` |
| 36, 76 | Return / Enter | `viewModel.evaluate()` |
| 75 | Numpad / | `viewModel.appendCharacter("/")` |
| 67 | Numpad * | `viewModel.appendCharacter("*")` |
| 78 | Numpad − | `viewModel.appendCharacter("-")` |
| 69 | Numpad + | `viewModel.appendCharacter("+")` |
| default | Символы | Проверка isNumber/+-*/().%,πe → `viewModel.appendCharacter()` |

**Обработка performKeyEquivalent (⌘+буква):**
| Комбинация | Действие |
|---|---|
| ⌘C | `viewModel.copyResult()` |
| ⌘V | `ClipboardManager.shared.getString()` → `viewModel.insertFromClipboard()` |
| ⌘A | Заглушка (return true) |
| ⌘Z | Заглушка (return false — передаётся дальше) |

### 14.8. Package.swift (структура модулей)

```swift
// swift-tools-version: 6.0
// macOS 14.0+

targets: [
    .target(
        name: "CalculatorEngine",
        path: "Sources/CalculatorEngine"
    ),
    .executableTarget(
        name: "CalculatorApp",
        dependencies: ["CalculatorEngine"],
        path: "Sources"
    ),
]
```

- `CalculatorEngine` — библиотека (target), содержит весь вычислительный движок
- `CalculatorApp` — исполняемый target (executableTarget), содержит App, Views, ViewModel, Services, Support
- Зависимость: `CalculatorApp` зависит от `CalculatorEngine`

---

## 15. Инструкции по сохранению файлов

### 15.1. Маленькие результаты (до ~3000 строк)

Сохранять результат в один файл:
```
.memory_bank/[date] [time] [author] - [title].md
```

### 15.2. Большие результаты (больше ~3000 строк)

Разбить результат на пронумерованные части и сохранить в отдельные файлы:
```
.memory_bank/[date] [time] [author] - [title] INDEX.md     — навигация
.memory_bank/[date] [time] [author] - [title] PART-01.md
.memory_bank/[date] [time] [author] - [title] PART-02.md
... и так далее
```

### 15.3. Формат имени файла — ОБЯЗАТЕЛЬНОЕ ПРАВИЛО

Это **строгая, не подлежащая обсуждению конвенция именования** для всех новых файлов, создаваемых в директории `.memory_bank/`. **Без исключений.**

Формат имени файла:
```
[date] [time] [author] - [title].md
```

Где:
- **[date]** = ГГГГ-ММ-ДД (пример: 2026-07-06)
- **[time]** = ЧЧ-ММ (пример: 16-25)
- **[author]** = OrnithQ8 | MimoCode | ClaudeCode | GeminiPro и т.д.
- **[title]** = краткое описание содержимого

### 15.4. Как получить дату и время для имени файла

Перед созданием любого нового файла в директории `.memory_bank/` ОБЯЗАТЕЛЬНО выполнить следующую команду для получения текущей системной даты и времени:

```bash
date +"%Y-%m-%d %H-%M"
```

**НИКОГДА не угадывать и не галлюцинировать время.** Всегда использовать точный вывод команды `date` для частей `[date]` и `[time]` имени файла.

### 15.5. Примеры корректных имён файлов

```
2026-07-06 16-25 OrnithQ8 - Правила работы агента.md
2026-07-06 17-00 OrnithQ8 - План добавления истории.md
2026-07-06 18-30 OrnithQ8 - Анализ покрытия тестами.md
```

---

## 16. Ограничения контекста

Если заканчивается контекст:
- завершите ответ кратко
- резюмируйте вместо расширения

---

> **Примечание:** Дополнительные чеклисты верификации, пошаговые инструкции аудита и стандарты доказательств находятся в отдельном документе:
> **`.memory_bank/Technical_Documentation.md`**
