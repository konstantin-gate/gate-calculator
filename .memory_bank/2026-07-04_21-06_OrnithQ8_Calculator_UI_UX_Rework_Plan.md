# План исправления UI/UX калькулятора для macOS

## Общая информация

**Дата создания:** 2026-07-04  
**Автор плана:** OrnithQ8  
**Целевая аудитория:** Младший разработчик (Junior Swift/SwiftUI)  
**Время выполнения:** 3-5 рабочих дней  

---

## Что нужно исправить и зачем

После анализа проекта было выявлено, что вычислительное ядро (CalculatorEngine) работает корректно и полностью соответствует спецификации. Однако пользовательский интерфейс (UI) и взаимодействие с пользователем (UX) имеют критические отклонения от плана SRS v1.1.

**Основные проблемы:**
1. Цвета захардкожены (тёмная тема, оранжевые кнопки) вместо системных semantic colors
2. Нет адаптации к Light/Dark Mode
3. Используется устаревший ObservableObject вместо @Observable
4. Нет локализации (только английский)
5. Нет сохранения состояния между запусками
6. Нет настроек
7. Нет анимаций и микровзаимодействий
8. Нет полноценной Accessibility
9. Есть мёртвый код в тестах

**Цель плана:** Превратить рабочий прототип в production-ready приложение, соответствующее спецификации SRS v1.1.

---

## Подготовка перед началом работы

### Что нужно знать

1. **SwiftUI** — фреймворк для создания интерфейсов
2. **Swift 6** — язык программирования (используй современные возможности)
3. **Observation framework** — новый способ управления состоянием (@Observable вместо ObservableObject)
4. **macOS Human Interface Guidelines** — руководство по дизайну для macOS

### Структура проекта (для справки)

```
Sources/
├── App/                    # Точка входа приложения
│   └── CalculatorApp.swift
├── Views/                  # UI компоненты
│   ├── CalculatorView.swift
│   ├── DisplayView.swift
│   ├── CalculatorButton.swift
│   └── HistoryPanelView.swift
├── ViewModels/             # Логика интерфейса
│   └── CalculatorViewModel.swift
├── Services/               # Сервисы (история, буфер)
│   └── HistoryService.swift
├── Formatting/             # Форматирование чисел
│   └── NumberFormatterService.swift
├── Theme/                  # Цвета и темы
│   └── CalculatorColors.swift
├── CalculatorEngine/       # Вычислительное ядро (НЕ МЕНЯТЬ)
│   ├── Tokenizer/
│   ├── Parser/
│   ├── Evaluator/
│   ├── AST/
│   └── Errors/
├── Localization/           # Локализация (НУЖНО ЗАПОЛНИТЬ)
├── Resources/              # Ресурсы (НУЖНО ЗАПОЛНИТЬ)
└── Components/             # Переиспользуемые компоненты (НУЖНО ЗАПОЛНИТЬ)
```

### Инструменты

- Xcode (или swiftc для компиляции)
- Terminal для запуска тестов: `swift run TestRunner`

---

## Этап 1: Цветовая система (Самое критичное)

### Почему это важно

Сейчас в проекте захардкожены цвета:
- Фон: `Color.black` (чёрный)
- Кнопки цифр: `Color.gray` (серый)
- Кнопки операций: `Color.orange` (оранжевый)
- Текст: `Color.white` (белый)

Это нарушает спецификацию SRS, которая требует:
- Использовать системные semantic colors (адаптируются к Light/Dark Mode)
- Кнопки цифр: `secondarySystemBackground`
- Кнопки операций: `systemGray5`
- Фон: `systemGroupedBackground`

### Что делать (пошагово)

#### Шаг 1.1: Открой файл `Sources/Theme/CalculatorColors.swift`

Текущее содержимое (строки 1-15):
```swift
import AppKit
import SwiftUI

struct CalculatorColors {
    static let background = Color.black
    static let displayBackground = Color.clear
    static let buttonDigit = Color.gray
    static let buttonOperator = Color.orange
    static let buttonEquals = Color.blue
    static let buttonClear = Color.gray
    static let textPrimary = Color.white
    static let textSecondary = Color.gray.opacity(0.7)
    static let textEquals = Color.white
    static let errorColor = Color.red
}
```

#### Шаг 1.2: Замени на правильный код

Удали всё содержимое файла и вставь этот код:

```swift
import SwiftUI

struct CalculatorColors {
    // Фон калькулятора (адаптируется к Light/Dark Mode)
    static let background = Color(.systemGroupedBackground)
    
    // Фон дисплея (прозрачный)
    static let displayBackground = Color.clear
    
    // Фон цифровых кнопок (светло-серый в Light Mode, тёмно-серый в Dark Mode)
    static let buttonDigit = Color(.secondarySystemBackground)
    
    // Фон кнопок операций (серый в Light Mode, средне-серый в Dark Mode)
    static let buttonOperator = Color(.systemGray5)
    
    // Фон кнопки "=" (синий)
    static let buttonEquals = Color(.systemBlue)
    
    // Фон кнопки "C" (такой же как цифровые кнопки)
    static let buttonClear = Color(.secondarySystemBackground)
    
    // Основной текст (чёрный в Light Mode, белый в Dark Mode)
    static let textPrimary = Color(.primaryLabel)
    
    // Вторичный текст (серый в Light Mode, светло-серый в Dark Mode)
    static let textSecondary = Color(.secondaryLabel)
    
    // Текст на кнопке "=" (белый всегда)
    static let textEquals = Color.white
    
    // Цвет ошибок (красный)
    static let errorColor = Color(.systemRed)
}
```

#### Шаг 1.3: Проверь, что нигде не используются старые цвета

Открой файлы:
- `Sources/Views/CalculatorView.swift`
- `Sources/Views/DisplayView.swift`
- `Sources/Views/CalculatorButton.swift`

Убедись, что во всех местах используются цвета из `CalculatorColors`, а не захардкоженные `Color.black`, `Color.gray` и т.д.

**Пример неправильного кода (НЕ ДОЛЖНО БЫТЬ):**
```swift
.background(Color.black)
.foregroundStyle(Color.white)
```

**Пример правильного кода (ДОЛЖНО БЫТЬ):**
```swift
.background(CalculatorColors.background)
.foregroundStyle(CalculatorColors.textPrimary)
```

#### Шаг 1.4: Запусти и проверь

Запусти приложение: `swift run CalculatorApp`

Проверь:
1. ✅ Фон должен быть светло-серым (в Light Mode) или тёмно-серым (в Dark Mode)
2. ✅ Кнопки цифр должны быть светло-серыми (не белыми!)
3. ✅ Кнопки операций должны быть серыми (не оранжевыми!)
4. ✅ Текст должен быть чёрным (в Light Mode) или белым (в Dark Mode)
5. ✅ Переключение между Light/Dark Mode должно работать автоматически

---

## Этап 2: Переход на @Observable (Observation framework)

### Почему это важно

Сейчас в проекте используется устаревший `ObservableObject` с `@Published`. Спецификация требует использовать современный `Observation` framework с `@Observable`.

**Преимущества @Observable:**
- Не нужно вызывать `objectWillChange.send()`
- Более чистый код
- Лучшая производительность
- Соответствует современным рекомендациям Apple

### Что делать (пошагово)

#### Шаг 2.1: Открой файл `Sources/ViewModels/CalculatorViewModel.swift`

#### Шаг 2.2: Замени импорты

**Было (строка 1-5):**
```swift
import Foundation
import SwiftUI
import Observation
import CalculatorEngine

@MainActor
final class CalculatorViewModel: ObservableObject {
```

**Стало:**
```swift
import Foundation
import SwiftUI
import Observation
import CalculatorEngine

@MainActor
@Observable
final class CalculatorViewModel {
```

#### Шаг 2.3: Замени @Published на обычные свойства

**Было (строки 9-11):**
```swift
@Published var expression: String = ""
@Published var result: String? = nil
@Published var errorMessage: String? = nil
```

**Стало:**
```swift
var expression: String = ""
var result: String? = nil
var errorMessage: String? = nil
```

**Важно:** Удали префикс `@Published` из всех трёх свойств. Остальной код менять НЕ нужно — `@Observable` автоматически отслеживает изменения этих свойств.

#### Шаг 2.4: Открой файл `Sources/App/CalculatorApp.swift`

#### Шаг 2.5: Замени @StateObject на @State

**Было (строка 5):**
```swift
@StateObject private var viewModel = CalculatorViewModel()
```

**Стало:**
```swift
@State private var viewModel = CalculatorViewModel()
```

#### Шаг 2.6: Замени @ObservedObject на @Bindable или просто убрал

**Было (строка 21):**
```swift
@ObservedObject var viewModel: CalculatorViewModel
```

**Стало (в двух местах):**
1. В `CalculatorContentView` (строка 21):
```swift
@Bindable var viewModel: CalculatorViewModel
```

2. В `KeyHandlerView` (строка 35):
```swift
@Bindable var viewModel: CalculatorViewModel
```

**Важно:** `@Bindable` нужен только если ты используешь эти свойства в модификаторах SwiftUI (например, `@Binding`). Если просто читаешь — можно оставить без аннотации.

#### Шаг 2.7: Проверь все файлы на использование ObservableObject

Открой все файлы в `Sources/Views/` и убедись, что нигде не используется `@ObservedObject`. Если есть — замени на `@Bindable` или убери аннотацию.

#### Шаг 2.8: Запусти и проверь

Запусти приложение: `swift run CalculatorApp`

Проверь:
1. ✅ Приложение запускается без ошибок компиляции
2. ✅ Все функции работают (ввод, вычисление, история)
3. ✅ Нет предупреждений компилятора

---

## Этап 3: Локализация (English + Russian)

### Почему это важно

Спецификация требует минимум два языка: English и Русский. Сейчас все строки на английском без возможности локализации.

### Что делать (пошагово)

#### Шаг 3.1: Создай структуру для локализации

Создай папку `Sources/Localization/` (если её нет).

#### Шаг 3.2: Создай файл `Sources/Localization/Localizable.swift`

Создай новый файл и вставь этот код:

```swift
import Foundation

// MARK: - Локализация

/// Функция для получения локализованной строки
func L(_ key: String, _ comment: String = "") -> String {
    return NSLocalizedString(key, comment: comment)
}

// MARK: - Кнопки

extension String {
    static let buttonClear = L("button.clear", "Кнопка очистки")
    static let buttonEquals = L("button.equals", "Кнопка равно")
}

// MARK: - Дисплей

extension String {
    static let displayPlaceholder = L("display.placeholder", "0")
}

// MARK: - История

extension String {
    static let historyTitle = L("history.title", "History")
    static let historyEmpty = L("history.empty", "Calculations will appear here")
    static let historyDone = L("history.done", "Done")
    static let historyClear = L("history.clear", "Clear")
}

// MARK: - Ошибки

extension String {
    static let errorInvalidExpression = L("error.invalidExpression", "Invalid expression")
    static let errorDivisionByZero = L("error.divisionByZero", "Division by zero")
    static let errorMissingParenthesis = L("error.missingParenthesis", "Missing closing parenthesis")
    static let errorExtraParenthesis = L("error.extraParenthesis", "Extra closing parenthesis")
    static let errorInvalidCharacter = L("error.invalidCharacter", "Invalid character")
}

// MARK: - Буфер обмена

extension String {
    static let clipboardInsertFailed = L("clipboard.insertFailed", "Cannot evaluate")
}
```

#### Шаг 3.3: Создай файлы локализации

Создай папку `Sources/Localization/en.lproj/` и файл `Localizable.strings`:

```
"button.clear" = "C";
"button.equals" = "=";
"display.placeholder" = "0";
"history.title" = "History";
"history.empty" = "Calculations will appear here";
"history.done" = "Done";
"history.clear" = "Clear";
"error.invalidExpression" = "Invalid expression";
"error.divisionByZero" = "Division by zero";
"error.missingParenthesis" = "Missing closing parenthesis";
"error.extraParenthesis" = "Extra closing parenthesis";
"error.invalidCharacter" = "Invalid character";
"clipboard.insertFailed" = "Cannot evaluate";
```

Создай папку `Sources/Localization/ru.lproj/` и файл `Localizable.strings`:

```
"button.clear" = "C";
"button.equals" = "=";
"display.placeholder" = "0";
"history.title" = "История";
"history.empty" = "Вычисления появятся здесь";
"history.done" = "Готово";
"history.clear" = "Очистить";
"error.invalidExpression" = "Неверное выражение";
"error.divisionByZero" = "Деление на ноль";
"error.missingParenthesis" = "Пропущена закрывающая скобка";
"error.extraParenthesis" = "Лишняя закрывающая скобка";
"error.invalidCharacter" = "Неверный символ";
"clipboard.insertFailed" = "Невозможно вычислить";
```

#### Шаг 3.4: Замени захардкоженные строки в коде

Открой файлы и замени все строковые литералы на вызовы `L()`:

**Файл: `Sources/Views/HistoryPanelView.swift`**

Замени (строка 12-14):
```swift
ContentUnavailableView(
    "No History",
    systemImage: "clock",
    description: Text("Calculations will appear here")
)
```

На:
```swift
ContentUnavailableView(
    L("history.empty"),
    systemImage: "clock",
    description: Text(L("history.empty"))
)
```

Замени (строка 42):
```swift
.navigationTitle("History")
```

На:
```swift
.navigationTitle(L("history.title"))
```

Замени (строка 45):
```swift
Button("Done") { dismiss() }
```

На:
```swift
Button(L("history.done")) { dismiss() }
```

Замени (строка 50):
```swift
Button("Clear") {
```

На:
```swift
Button(L("history.clear")) {
```

**Файл: `Sources/ViewModels/CalculatorViewModel.swift`**

Замени (строка 121):
```swift
errorMessage = "Cannot evaluate"
```

На:
```swift
errorMessage = L("clipboard.insertFailed")
```

**Файл: `Sources/CalculatorEngine/Errors/CalculatorError.swift`**

Замени все строки в `errorDescription` на вызовы `L()`:

**Было (строка 17-36):**
```swift
var errorDescription: String? {
    switch self {
    case .divisionByZero:
        return "Division by zero"
    case .invalidExpression(let msg):
        return msg
    case .missingClosingParenthesis:
        return "Missing closing parenthesis"
    case .extraClosingParenthesis:
        return "Extra closing parenthesis"
    case .invalidCharacter(let char):
        return "Invalid character: \(char)"
    case .emptyExpression:
        return "Empty expression"
    case .numberOverflow:
        return "Number too large"
    case .invalidNumber(let num):
        return "Invalid number: \(num)"
    case .doubleOperator:
        return "Double operator"
    case .multipleDecimalSeparators:
        return "Multiple decimal separators"
    }
}
```

**Стало:**
```swift
var errorDescription: String? {
    switch self {
    case .divisionByZero:
        return L("error.divisionByZero")
    case .invalidExpression(let msg):
        return msg
    case .missingClosingParenthesis:
        return L("error.missingParenthesis")
    case .extraClosingParenthesis:
        return L("error.extraParenthesis")
    case .invalidCharacter(let char):
        return L("error.invalidCharacter") + ": \(char)"
    case .emptyExpression:
        return L("error.invalidExpression")
    case .numberOverflow:
        return L("error.numberTooLarge")
    case .invalidNumber(let num):
        return L("error.invalidNumber") + ": \(num)"
    case .doubleOperator:
        return L("error.doubleOperator")
    case .multipleDecimalSeparators:
        return L("error.multipleDecimals")
    }
}
```

**Важно:** Добавь новые ключи в файлы `Localizable.strings`:

В `en.lproj/Localizable.strings` добавь:
```
"error.numberTooLarge" = "Number too large";
"error.invalidNumber" = "Invalid number";
"error.doubleOperator" = "Double operator";
"error.multipleDecimals" = "Multiple decimal separators";
```

В `ru.lproj/Localizable.strings` добавь:
```
"error.numberTooLarge" = "Число слишком большое";
"error.invalidNumber" = "Некорректное число";
"error.doubleOperator" = "Двойной оператор";
"error.multipleDecimals" = "Несколько десятичных разделителей";
```

#### Шаг 3.5: Запусти и проверь

1. Переключись на русский язык в системе (Системные настройки → Язык и регион)
2. Запусти приложение: `swift run CalculatorApp`
3. Проверь, что все строки переведены на русский

---

## Этап 4: Сохранение состояния между запусками

### Почему это важно

Спецификация требует сохранять:
- Размер окна
- Позицию окна
- Историю вычислений

Сейчас история теряется при закрытии приложения.

### Что делать (пошагово)

#### Шаг 4.1: Создай сервис для сохранения настроек

Создай файл `Sources/Services/UserDefaultsService.swift`:

```swift
import Foundation

final class UserDefaultsService {
    static let shared = UserDefaultsService()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - История
    
    func saveHistory(_ entries: [HistoryEntry]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(entries) {
            defaults.set(data, forKey: "history")
        }
    }
    
    func loadHistory() -> [HistoryEntry] {
        guard let data = defaults.data(forKey: "history"),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }
    
    // MARK: - Размер окна
    
    func saveWindowSize(_ size: CGSize) {
        defaults.set(size.width, forKey: "windowWidth")
        defaults.set(size.height, forKey: "windowHeight")
    }
    
    func loadWindowSize() -> CGSize? {
        guard let width = defaults.double(forKey: "windowWidth"),
              let height = defaults.double(forKey: "windowHeight") else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
    
    // MARK: - Позиция окна
    
    func saveWindowPosition(_ point: NSPoint) {
        defaults.set(point.x, forKey: "windowX")
        defaults.set(point.y, forKey: "windowY")
    }
    
    func loadWindowPosition() -> NSPoint? {
        guard let x = defaults.double(forKey: "windowX"),
              let y = defaults.double(forKey: "windowY") else {
            return nil
        }
        return NSPoint(x: x, y: y)
    }
}
```

#### Шаг 4.2: Обнови HistoryService для работы с UserDefaults

Открой файл `Sources/Services/HistoryService.swift`

Добавь импорт в начало файла:
```swift
import Foundation
import Coding
```

Замени метод `init`:

**Было:**
```swift
public init(maxEntries: Int = 50) {
    self.maxEntries = maxEntries
}
```

**Стало:**
```swift
public init(maxEntries: Int = 50) {
    self.maxEntries = maxEntries
    loadFromStorage()
}

private func loadFromStorage() {
    let saved = UserDefaultsService.shared.loadHistory()
    if !saved.isEmpty {
        entries = saved
    }
}

private func saveToStorage() {
    UserDefaultsService.shared.saveHistory(entries)
}
```

Добавь вызов `saveToStorage()` в методы `add` и `clear`:

**В методе `add` (после defer { lock.unlock() }):**
```swift
saveToStorage()
```

**В методе `clear` (после defer { lock.unlock() }):**
```swift
saveToStorage()
```

#### Шаг 4.3: Добавь сохранение размера/позиции окна

Открой файл `Sources/App/CalculatorApp.swift`

Добавь наблюдение за изменением размера окна:

```swift
@main
struct CalculatorApp: App {
    @StateObject private var viewModel = CalculatorViewModel()
    
    var body: some Scene {
        WindowGroup {
            CalculatorContentView(viewModel: viewModel)
                .preferredColorScheme(nil)
                .frameObserver { size, position in
                    UserDefaultsService.shared.saveWindowSize(size)
                    if let position {
                        UserDefaultsService.shared.saveWindowPosition(position)
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 350, height: 520)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

// MARK: - Frame Observer Modifier

struct FrameObserver: ViewModifier {
    let onChange: (CGSize, NSPoint?) -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: SizePreferenceKey.self, value: geometry.size)
                }
            )
            .onPreferenceChange(SizePreferenceKey.self) { size in
                onChange(size, nil)
            }
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    func frameObserver(_ onChange: @escaping (CGSize, NSPoint?) -> Void) -> some View {
        modifier(FrameObserver(onChange: onChange))
    }
}
```

**Важно:** Этот код может потребовать доработки в зависимости от версии SwiftUI. Если не работает, используй упрощённую версию:

```swift
.frame(minWidth: 320, maxWidth: 400, minHeight: 500, maxHeight: 600)
```

И добавь сохранение в `CalculatorView`:

```swift
.onChange(of: viewModel.expression) { _ in
    // Сохраняем состояние при изменении выражения
}
```

#### Шаг 4.4: Запусти и проверь

1. Запусти приложение
2. Выполни несколько вычислений
3. Закрой приложение (⌘Q)
4. Открой снова
5. Проверь, что история сохранилась

---

## Этап 5: Настройки (минимальные)

### Почему это важно

Спецификация требует минимальные настройки:
- Автоматически копировать результат
- Показывать разделители тысяч
- Максимальное количество знаков после запятой

### Что делать (пошагово)

#### Шаг 5.1: Создай модель настроек

Создай файл `Sources/Models/AppSettings.swift`:

```swift
import Foundation

struct AppSettings: Codable {
    var autoCopyResult: Bool = false
    var showThousandsSeparator: Bool = true
    var maxFractionDigits: Int = 10
    
    static let defaultsKey = "appSettings"
    
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
```

#### Шаг 5.2: Добавь настройки в ViewModel

Открой файл `Sources/ViewModels/CalculatorViewModel.swift`

Добавь свойство:
```swift
private var settings = AppSettings.load()
```

Добавь метод для обновления настроек:
```swift
func updateSettings(_ newSettings: AppSettings) {
    settings = newSettings
    settings.save()
}
```

#### Шаг 5.3: Создай панель настроек (опционально)

Если хочешь добавить UI для настроек, создай файл `Sources/Views/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Binding var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("Result") {
                Toggle("Auto-copy result", isOn: $settings.autoCopyResult)
            }
            
            Section("Number Format") {
                Toggle("Show thousands separator", isOn: $settings.showThousandsSeparator)
                
                Picker("Max decimal places", selection: $settings.maxFractionDigits) {
                    ForEach(0...20, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
```

#### Шаг 5.4: Запусти и проверь

1. Запусти приложение
2. Проверь, что настройки загружаются корректно
3. Измени настройки и перезапусти приложение — они должны сохраниться

---

## Этап 6: Анимации и микровзаимодействия

### Почему это важно

Спецификация требует:
- Нажатие кнопки: scale 0.95, длительность 0.1 с
- Появление результата: fade in, длительность 0.2 с
- Переходы: ease-in-out, длительность 0.15 с

### Что делать (пошагово)

#### Шаг 6.1: Добавь анимацию нажатия кнопок

Открой файл `Sources/Views/CalculatorButton.swift`

Найди свойство `body` и добавь анимацию:

**Было:**
```swift
var body: some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 24, weight: .regular))
            .frame(maxWidth: isWide ? .infinity : nil)
            .frame(height: 60)
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
}
```

**Стало:**
```swift
var body: some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 24, weight: .regular))
            .frame(maxWidth: isWide ? .infinity : nil)
            .frame(height: 60)
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(.easeInOut(duration: 0.1), value: isPressed)
    .accessibilityLabel(title)
}
```

Добавь свойство для отслеживания нажатия:
```swift
@State private var isPressed = false

init(title: String, type: ButtonType, isWide: Bool = false, action: @escaping () -> Void) {
    self.title = title
    self.type = type
    self.isWide = isWide
    self.action = action
    
    // Подписываемся на события нажатия
    let recognizer = NSPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
    // Примечание: для SwiftUI нужно использовать другой подход
}

@objc private func handlePress(_ sender: NSPressGestureRecognizer) {
    isPressed = sender.state == .began
}
```

**Важно:** Для SwiftUI лучше использовать `Button` с кастомным стилем. Если вышеуказанный код не работает, используй упрощённую версию без анимации нажатия.

#### Шаг 6.2: Добавь анимацию появления результата

Открой файл `Sources/Views/DisplayView.swift`

Найди отображение результата и добавь анимацию:

**Было:**
```swift
if let result = result {
    Text(result)
        .font(autoSizedFont(for: result))
        .foregroundStyle(Color.primary)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 4)
}
```

**Стало:**
```swift
if let result = result {
    Text(result)
        .font(autoSizedFont(for: result))
        .foregroundStyle(Color.primary)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 4)
        .opacity(resultOpacity)
        .animation(.easeIn(duration: 0.2), value: result)
}
```

Добавь свойство для анимации:
```swift
@State private var resultOpacity: Double = 1.0

// В CalculatorViewModel добавь метод:
func showResult() {
    resultOpacity = 0.0
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        resultOpacity = 1.0
    }
}
```

#### Шаг 6.3: Добавь анимацию ошибок

В `DisplayView.swift` найди отображение ошибки и добавь анимацию:

**Было:**
```swift
if let error = errorMessage {
    Text(error)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color.red)
        .lineLimit(2)
        .padding(.horizontal, 4)
}
```

**Стало:**
```swift
if let error = errorMessage {
    Text(error)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color.red)
        .lineLimit(2)
        .padding(.horizontal, 4)
        .opacity(errorOpacity)
        .animation(.easeIn(duration: 0.2), value: errorMessage)
}
```

#### Шаг 6.4: Запусти и проверь

1. Запусти приложение
2. Нажми на кнопку — должна быть лёгкая анимация scale
3. Вычисли выражение — результат должен плавно появляться
4. Вызови ошибку — сообщение должно плавно появиться

---

## Этап 7: Клавиатурная навигация и Accessibility

### Почему это важно

Спецификация требует:
- Полноценную клавиатурную навигацию (Tab, Shift+Tab)
- Accessibility (VoiceOver, Reduce Motion, Dynamic Type)

### Что делать (пошагово)

#### Шаг 7.1: Добавь клавиатурную навигацию по кнопкам

Открой файл `Sources/Views/CalculatorView.swift`

Добавь состояние для отслеживания фокуса:
```swift
@State private var focusedButtonIndex: Int? = nil
```

Добавь обработку клавиш Tab и Shift+Tab в `KeyHandlerNSView`:

**В методе `keyDown` добавь:**
```swift
case 48: // Tab
    if event.modifierFlags.contains(.shift) {
        focusedButtonIndex = max(0, (focusedButtonIndex ?? 0) - 1)
    } else {
        focusedButtonIndex = min(buttons.count - 1, (focusedButtonIndex ?? 0) + 1)
    }
    return
```

#### Шаг 7.2: Добавь Accessibility labels

Открой файл `Sources/Views/CalculatorButton.swift`

Улучши accessibilityLabel:
```swift
.accessibilityLabel(title)
.accessibilityHint(isWide ? "Wide button" : nil)
```

#### Шаг 7.3: Добавь поддержку Reduce Motion

В `CalculatorButton.swift` добавь проверку на Reduce Motion:
```swift
@Environment(\.reduceMotion) private var reduceMotion

var body: some View {
    Button(action: action) {
        // ... существующий код
    }
    .buttonStyle(.plain)
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(reduceMotion ? .none : .easeInOut(duration: 0.1), value: isPressed)
    .accessibilityLabel(title)
}
```

#### Шаг 7.4: Запусти и проверь

1. Запусти приложение
2. Нажми Tab — фокус должен перемещаться между кнопками
3. Включи VoiceOver (⌘F5) — кнопки должны озвучиваться
4. Включи Reduce Motion (Системные настройки → Специальные возможности → Экран) — анимации должны отключиться

---

## Этап 8: Обработка специальных случаев ввода

### Почему это важно

Спецификация (раздел 39) требует обработку:
- "1,5" как десятичного разделителя (для европейских локалей)
- "pi" как константы π
- Корректной обработки "5%+" и других edge cases

### Что делать (пошагово)

#### Шаг 8.1: Добавь поддержку "pi" как константы π

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

Найди обработку символа 'π' (строка 78) и добавь поддержку латинского "pi":

**Было:**
```swift
if char == "\u{03C0}" || char == "π" || char.lowercased() == "pi" {
    tokens.append(.number(Decimal.pi))
    advance(&i, in: cleaned)
    continue
}
```

**Стало:**
```swift
// Проверка на π (символ или слово "pi")
if char == "\u{03C0}" || char == "π" {
    tokens.append(.number(Decimal.pi))
    advance(&i, in: cleaned)
    continue
}

// Проверка на слово "pi" (только если это отдельное слово)
if char.lowercased() == "p" {
    let nextIndex = cleaned.index(after: i)
    if nextIndex < cleaned.endIndex, cleaned[nextIndex] == "i" {
        let afterI = cleaned.index(after: nextIndex)
        if afterI >= cleaned.endIndex || !cleaned[afterI].isLetter {
            tokens.append(.number(Decimal.pi))
            i = afterI
            continue
        }
    }
}
```

#### Шаг 8.2: Добавь поддержку "1,5" как десятичного разделителя

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

В методе `preprocess` добавь обработку запятой как десятичного разделителя:

**После существующей обработки запятых (после строки 143) добавь:**
```swift
// Проверка на десятичную запятую (европейский формат)
if trimmed.contains(",") && !trimmed.contains(".") {
    // Если есть запятая и нет точки, считаем запятую десятичным разделителем
    result = result.replacingOccurrences(of: ",", with: ".")
}
```

**Важно:** Эта логика может конфликтовать с разделителями тысяч. Нужно добавить проверку:
- Если запятая стоит перед 1-3 цифрами в конце → десятичный разделитель
- Если запятая стоит перед 3 цифрами → разделитель тысяч

#### Шаг 8.3: Добавь обработку "5%+" (процент после оператора)

Открой файл `Sources/CalculatorEngine/Tokenizer/Tokenizer.swift`

В методе `validateTokenSequence` добавь проверку:

**После существующей проверки процента (после строки 319) добавь:**
```swift
// Процент не может быть followed by binary operator (кроме унарного минуса)
if i + 1 < tokens.endIndex {
    let nextToken = tokens[i + 1]
    if case .binaryOperator(_) = nextToken {
        throw CalculatorError.doubleOperator
    }
}
```

#### Шаг 8.4: Запусти и проверь

1. Запусти приложение
2. Введи "pi" — должно вычислиться как π
3. Введи "1,5" (если система в европейской локали) — должно вычислиться как 1.5
4. Введи "5%+" — должна быть ошибка

---

## Этап 9: UI Tests и очистка кода

### Почему это важно

Спецификация требует:
- UI Tests (сейчас только Unit Tests)
- Нет мёртвого кода

### Что делать (пошагово)

#### Шаг 9.1: Удали мёртвый код из тестов

Открой файл `Tests/Unit/CalculatorEngineTests.swift`

Найди мёртвый код (строки 97-174 содержат остатки TestRunnerMain.main()):

**Удали:**
```swift
    func testEvaluate_LongExpressionWithSpaces() throws {
        let result = try engine.evaluate("(15 +16+17 ) /4")
        XCTAssertEqual(result, Decimal(string: "12.5")!)
    }

    // MARK: - Percent

    func testEvaluate_Percent() throws {
        let result = try engine.evaluate("50%")
        XCTAssertEqual(result, Decimal(string: "0.5")!)
    }

    func testEvaluate_PercentHundred() throws {
        let result = try engine.evaluate("100%")
        XCTAssertEqual(result, Decimal(string: "1.0")!)
    }

    func testEvaluate_PercentWithMultiplication() throws {
        let result = try engine.evaluate("100*5%")
        XCTAssertEqual(result, 5) // 100 * (5/100) = 5
    }

    func testEvaluate_PercentWithDivision() throws {
        let result = try engine.evaluate("100/5%")
        XCTAssertEqual(result, 2000) // 100 / (5/100) = 2000
    }

    func testEvaluate_PercentWithAddition() throws {
        let result = try engine.evaluate("100+5%")
        XCTAssertEqual(result, Decimal(string: "100.05")!) // 100 + (5/100) = 100.05
    }

    func testEvaluate_PercentWithSubtraction() throws {
        let result = try engine.evaluate("100-5%")
        XCTAssertEqual(result, Decimal(string: "99.95")!) // 100 - (5/100) = 99.95
    }

    func testEvaluate_PercentAfterParentheses() throws {
        let result = try engine.evaluate("(50+10)%")
        XCTAssertEqual(result, Decimal(string: "0.6")!) // (50+10)/100 = 0.6
    }

    // MARK: - Special Cases from Section 39

    func testSpecialCase_HexNumber() throws {
        let result = try engine.evaluate("0xFF")
        XCTAssertEqual(result, 255)
    }

    func testSpecialCase_BinaryNumber() throws {
        let result = try engine.evaluate("0b1010")
        XCTAssertEqual(result, 10)
    }

    func testSpecialCase_OctalNumber() throws {
        let result = try engine.evaluate("0o77")
        XCTAssertEqual(result, 63)
    }

    func testSpecialCase_ExponentialNotation() throws {
        let result = try engine.evaluate("1.5e3")
        XCTAssertEqual(result, 1500)
    }

    func testSpecialCase_Pi() throws {
        let result = try engine.evaluate("π")
        XCTAssertTrue(result.description.hasPrefix("3.14159265358979"))
    }

    func testSpecialCase_PiMultiplication() throws {
        let result = try engine.evaluate("π*2")
        XCTAssertTrue(result.description.hasPrefix("6.28318530717958"))
    }

    func testSpecialCase_EulerNumber() throws {
        let result = try engine.evaluate("e")
        XCTAssertTrue(result.description.hasPrefix("2.71828182845905"))
    }

    func testSpecialCase_ThousandsSeparator() throws {
        let result = try engine.evaluate("1,000,000")
        XCTAssertEqual(result, 1000000)
    }

    func testSpecialCase_EqualsAtEnd() throws {
        let result = try engine.evaluate("(15+16)/4=")
        XCTAssertEqual(result, Decimal(string: "7.75")!)
    }

    func testSpecialCase_MultipleLines() throws {
        let result = try engine.evaluate("15+16\n20+30")
        XCTAssertEqual(result, 31) // Only first line processed
    }

    // MARK: - Error Cases

    func testError_DivisionByZero() {
        XCTAssertThrowsError(try engine.evaluate("1/0"))
    }

    func testError_InvalidCharacter() {
        XCTAssertThrowsError(try engine.evaluate("15+a"))
    }

    func testError_MissingParenthesis() {
        XCTAssertThrowsError(try engine.evaluate("(15+16"))
    }

    func testError_ExtraParenthesis() {
        XCTAssertThrowsError(try engine.evaluate("15+16)"))
    }

    func testError_NaN() {
        XCTAssertThrowsError(try engine.evaluate("NaN"))
    }

    func testError_Infinity() {
        XCTAssertThrowsError(try engine.evaluate("Infinity"))
    }

    func testError_DoubleOperator() {
        XCTAssertThrowsError(try engine.evaluate("5++3"))
    }

    func testError_EmptyExpression() {
        XCTAssertThrowsError(try engine.evaluate(""))
    }

    func testError_InvalidPercent() {
        XCTAssertThrowsError(try engine.evaluate("%*"))
    }

    // MARK: - Integration Tests

    func testEvaluate_MainScenario() throws {
        let result = try engine.evaluate("(15+16+17+18)/4")
        XCTAssertEqual(result, Decimal(string: "16.5")!)
    }

    func testEvaluate_AllSpecialCases() throws {
        let cases: [(String, Decimal?)] = [
            ("15+16", 31),
            ("(15+16)*5", 155),
            ("-5+12", 7),
            ("-(15+16)", -31),
            ("3.1415*5", Decimal(string: "15.7075")!),
            ("50%", Decimal(string: "0.5")!),
            ("100 * 5%", 5),
            ("100 / 5%", 2000),
            ("0xFF", 255),
            ("0b1010", 10),
            ("0o77", 63),
            ("1.5e3", 1500),
        ]

        for (expression, expected) in cases {
            let result = try? engine.evaluate(expression)
            XCTAssertEqual(result, expected, "Failed for: \(expression)")
        }
    }

    func testEvaluate_AllErrorCases() {
        let cases = [
            "1/0",
            "15+a",
            "(15+16",
            "15+16)",
            "NaN",
            "Infinity",
        ]

        for expression in cases {
            let result = try? engine.evaluate(expression)
            XCTAssertNil(result, "Should fail for: \(expression)")
        }
    }
}
```

**Важно:** Этот код дублирует тесты из других файлов. Оставь только уникальные тесты или удали полностью, если они есть в других файлах.

#### Шаг 9.2: Создай UI Tests (опционально)

Создай папку `Tests/UI/` и файл `CalculatorUITests.swift`:

```swift
import XCTest

final class CalculatorUITests: XCTestCase {
    
    func testApplicationLaunch() throws {
        // Тест на запуск приложения
        let app = XCUIApplication()
        app.launch()
        
        // Проверь, что приложение запустилось
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
    
    func testBasicCalculation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Введи "1+1=" и проверь результат "2"
        // Примечание: этот тест требует Xcode для запуска
    }
}
```

**Важно:** UI Tests требуют Xcode для полноценной работы. Если у тебя только Command Line Tools, этот этап можно пропустить.

#### Шаг 9.3: Запусти все тесты

```bash
swift test
```

Проверь, что все тесты проходят.

---

## Финальная проверка

### Чеклист перед завершением

Пройдись по этому списку и убедись, что всё сделано:

- [ ] Цвета используют системные semantic colors (не захардкожены)
- [ ] Light/Dark Mode работает автоматически
- [ ] Используется @Observable вместо ObservableObject
- [ ] Есть локализация (English + Russian)
- [ ] История сохраняется между запусками
- [ ] Размер/позиция окна сохраняются (если реализовано)
- [ ] Есть минимальные настройки (если реализовано)
- [ ] Анимации нажатия кнопок работают (если реализовано)
- [ ] Анимация появления результата работает (если реализовано)
- [ ] Клавиатурная навигация (Tab/Shift+Tab) работает (если реализовано)
- [ ] Accessibility labels есть у всех кнопок
- [ ] Reduce Motion учитывается (если реализовано)
- [ ] "pi" распознаётся как константа π
- [ ] "1,5" обрабатывается корректно (если реализовано)
- [ ] Нет мёртвого кода в тестах
- [ ] Все тесты проходят (`swift test`)
- [ ] Приложение компилируется без предупреждений

### Команды для проверки

```bash
# Собрать проект
swift build

# Запустить тесты
swift test

# Запустить приложение
swift run CalculatorApp

# Запустить TestRunner
swift run TestRunner
```

---

## Что делать, если что-то не работает

### Частые проблемы и решения

1. **Ошибка компиляции: "Cannot find '@Observable' in scope"**
   - Решение: Убедись, что используешь Swift 6+ и импортируешь `import Observation`

2. **Цвета не меняются при переключении Light/Dark Mode**
   - Решение: Проверь, что используешь `Color(.systemGroupedBackground)` а не `Color.black`

3. **Локализация не работает**
   - Решение: Проверь, что файлы `Localizable.strings` находятся в правильных папках (`en.lproj/`, `ru.lproj/`)

4. **История не сохраняется**
   - Решение: Проверь, что `UserDefaultsService` вызывается в методах `add` и `clear`

5. **Анимации не работают**
   - Решение: Проверь, что используешь `.animation()` правильно и свойства наблюдаемые

---

## Итоговое время выполнения

| Этап | Описание | Время |
|------|----------|-------|
| 1 | Цветовая система | 1-2 часа |
| 2 | @Observable | 30 минут |
| 3 | Локализация | 1-2 часа |
| 4 | Сохранение состояния | 1-2 часа |
| 5 | Настройки | 1-2 часа (опционально) |
| 6 | Анимации | 2-3 часа |
| 7 | Accessibility | 1-2 часа |
| 8 | Спец. случаи ввода | 1-2 часа |
| 9 | Тесты и очистка | 1 час |
| **Итого** | | **10-17 часов** |

---

## Заключение

Этот план превратит рабочий прототип калькулятора в production-ready приложение, соответствующее спецификации SRS v1.1. После выполнения всех этапов приложение будет:

- Выглядеть как нативное macOS приложение (адаптивные цвета, анимации)
- Поддерживать два языка (English + Russian)
- Сохранять состояние между запусками
- Быть доступным для пользователей с ограниченными возможностями
- Иметь чистый, современный код (Swift 6, @Observable)

Удачи в реализации! 🚀
