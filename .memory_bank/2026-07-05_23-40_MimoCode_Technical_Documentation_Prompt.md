# Промпт: Профессиональный глубокий анализ кода и техническая документация

## Роль

Ты — старший iOS/macOS-инженер и технический писатель. Твоя задача — провести полный профессиональный аудит кодовой базы проекта **GateCalc** (macOS-калькулятор на Swift/SwiftUI) и написать исчерпывающую техническую документацию на русском языке.

## Инструкция

### 1. Структура проекта

Изучи всю файловую структуру проекта, начиная с корневой директории. Прочитай **каждый** исходный файл в `Sources/` и `Tests/`. Не пропускай ни одного `.swift`-файла.

Проект построен как Swift Package с тремя таргетами:
- **CalculatorEngine** — независимый вычислительный движок (Sources/CalculatorEngine/)
- **CalculatorApp** — SwiftUI-приложение (Sources/App/, Sources/Views/, Sources/ViewModels/, Sources/Services/, Sources/History/, Sources/Clipboard/, Sources/Formatting/, Sources/Theme/, Sources/Localization/)
- **TestRunner** — консольный прогон тестов (Sources/TestRunner/)
- **Tests/Unit/** — XCTest-юнит-тесты

### 2. Что должен содержать каждый раздел документации

#### 2.1. Обзор проекта
- Название, платформа, минимальная версия macOS (14+), Swift-tools-version (6.0)
- Назначение приложения
- Архитектурный стиль (MVVM + вычислительный движок как отдельный модуль)
- Список всех файлов с кратким описанием назначения каждого

#### 2.2. Архитектура
- Диаграмма зависимостей модулей (текстовая, в формате Mermaid или ASCII)
- Поток данных: от нажатия кнопки до отображения результата
- Разделение ответственности:哪个 класс за что отвечает
- Паттерны: Facade (CalculatorEngine), MVVM (ViewModel), Singleton (HistoryService, ClipboardManager, NumberFormatterService), NSViewRepresentable (KeyHandlerView)
- Потокобезопасность: NSLock в HistoryService и ClipboardManager, @MainActor для ViewModel и KeyHandlerNSView

#### 2.3. Вычислительный движок (CalculatorEngine)
Подробнейшее описание каждого компонента:

**Tokenizer** (Tokenizer.swift, Token.swift):
- Полный список токенов: number, binaryOperator (+, -, *, /), unaryMinus, leftParenthesis, rightParenthesis, percent
- Предварительная обработка: удаление "=", обработка переносов, нормализация запятых (разделитель тысяч), проверка NaN/Infinity
- Чтение чисел: десятичные, экспоненциальные (1.5e3), hex (0xFF), bin (0b1010), oct (0o77)
- Различение унарного и бинарного минуса (по контексту: в начале строки или после оператора/скобки — унарный)
- Валидация последовательности токенов (двойные оператори т.д.)
- Константы: π (Decimal.pi), e (вычисляется разложением в ряд Тейлора, 30 слагаемых)

**Parser** (Parser.swift, Precedence.swift):
- Алгоритм сортировочной станции (Shunting Yard) для infix → RPN
- Построение AST из RPN
- Приоритеты: addition=1, multiplication=2, unaryMinus=2, percent=2
- Ассоциативность: бинарные операторы — левая, unaryMinus — правая
- Обработка ошибок: незакрытые/лишние скобки, двойные операторы

**AST** (ExpressionNode.swift):
- indirect enum: number(Decimal), unaryMinus(ExpressionNode), binary(BinaryOperator, left, right)

**Evaluator** (Evaluator.swift):
- Рекурсивный обход AST
- Деление на ноль → CalculatorError.divisionByZero

**CalculatorEngine.swift** — фасад: строка → токены → AST → Decimal

**CalculatorError.swift** — полный перечень ошибок с локализацией

#### 2.4. UI-слой (Views)
- **CalculatorView** — главный вид, сетка кнопок 4×7, обработчик нажатий
- **CalculatorButton** — типы кнопок (digit, operator, function), ButtonLabel enum с displayTitle/inputValue/accessibilityDescription, анимация нажатия, AnyShape
- **DisplayView** — дисплей с выражением, результатом, ошибкой; адаптивный шрифт (42/36/30/24pt); анимации (shake при ошибке, flash при результате); форматирование выражения (÷, ×, унарный/бинарный минус); Accessibility
- **HistoryPanelView** — NavigationStack, список истории, ContentUnavailableView при пустоте
- **CalculatorApp** — @main, WindowGroup, .defaultSize(350×520), KeyHandlerNSView (NSViewRepresentable) для клавиатурного ввода

#### 2.5. ViewModel (CalculatorViewModel)
- @Observable, @MainActor
- Состояние: expression, result, errorMessage
- Методы: appendCharacter, appendOperator, evaluate, clear, backspace, toggleSign
- Memory operations: memoryClear, memoryAdd, memorySubtract, memoryRecall
- Clipboard: insertFromClipboard, copyResult
- History: useHistoryEntry, clearHistory
- Автоматическое вычисление (tryAutoEvaluate) при вводе операторов
- Логика замены выражения после результата (новая цифра → очистка, оператор → использование предыдущего результата)

#### 2.6. Сервисы
- **HistoryService** — singleton, NSLock, maxEntries=50, in-memory
- **ClipboardManager** — singleton, NSLock, NSPasteboard
- **NumberFormatterService** — singleton, en_US локаль, decimal/scientific форматирование, экспоненциальный формат для |x|≥1e12 или |x|<1e-6

#### 2.7. Тема и локализация
- **CalculatorColors** — цветовая система по образцу Calculator.app macOS Tahoe
- Локализация: en, ru (Localizable.strings)

#### 2.8. Тестирование
- Структура тестов: TokenizerTests, ParserTests, EvaluatorTests, CalculatorEngineTests
- Покрытие: базовая арифметика, приоритет операторов, скобки, пробелы, унарный минус, десятичные, длинные выражения, проценты, специальные числа (hex/bin/oct/exp/π/e), разделители тысяч, ошибки
- TestRunner — консольный прогон всех тестов без XCTest

#### 2.9. Сборка и запуск
- Package.swift — полный анализ конфигурации пакета
- build_app.sh — скрипт сборки
- GateCalc.app — структура .app-бандла

#### 2.10. Известные проблемы и ограничения
- История не сохраняется между сессиями (in-memory only)
- Undo (⌘Z) не реализован (заглушка)
- Select All (⌘A) не реализован (заглушка)
- Tab navigation не реализована (заглушка)
- Ограничение 50 записей истории

#### 2.11. Реестр исправлений
Проаннотируй все комментарии "ИСПРАВЛЕНИЕ X-XX" в коде. Составь таблицу:
| ID | Описание | Файл | Строки |

#### 2.12. Метрики проекта
- Общее количество строк кода по файлам
- Количество тестов
- Количество XCTest-методов
- Сложность вычислительного движка (количество токенов, глубина AST)

### 3. Формат вывода

Напиши документацию в формате Markdown. Используй:
- Заголовки всех уровней
- Таблицы там, где уместно
- Блоки кода с подсветкой синтаксиса (swift)
- Mermaid-диаграммы для архитектуры и потоков данных
- Списки и нумерованные элементы

Документ должен быть **самодостаточным** — человек, прочитавший его, должен полностью понять архитектуру, логику и устройство проекта без обращения к исходному коду.

### 4. Сохранение результата

Запиши готовую документацию в файл:
```
/Users/kgate/Work/GateCalc/.memory_bank/2026-07-05_23-50_MimoCode_Technical_Documentation.md
```

(Имя файла: ДАТА_ВРЕМЯ_ИМЯ_АГЕНТА_КРАТКОЕ_НАЗВАНИЕ.md)

### 5. Язык

Вся документация должна быть написана **на русском языке**. Ключевые термины (MVVM, Facade, Singleton, AST, RPN, Shunting Yard) оставляй на английском с пояснением при первом упоминании.
