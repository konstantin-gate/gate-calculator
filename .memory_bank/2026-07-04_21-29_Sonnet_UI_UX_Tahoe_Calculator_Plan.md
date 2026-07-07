# План переработки UI/UX калькулятора OrnithQ8
# Эталон: Стандартный Calculator.app из macOS Tahoe 26 (26.0)

**Дата:** 2026-07-04  
**Время:** 21:29  
**Автор плана:** Sonnet  
**Статус:** Готов к исполнению (НЕ ЗАПУСКАТЬ — только план)  
**Целевая аудитория:** Junior/Middle Swift-разработчик  
**Ориентировочное время исполнения:** 4–6 рабочих часов  

---

## РАЗДЕЛ 0: Эталонный дизайн — что именно мы воспроизводим

### 0.1 Описание скриншота macOS Tahoe Calculator

На скриншоте (`standardni kalkulator`) показан **Calculator.app в режиме «Научный» (Scientific)** в тёмной теме macOS Tahoe 26. Вот точное описание каждого элемента:

#### Окно

- **Фон окна:** насыщенный тёмно-синий (не чёрный), примерно `#1C2B3A` или системный `windowBackgroundColor` с применением виброэффекта
- **Titlebar:** стандартный macOS с тремя кнопками (красная/жёлтая/зелёная), кнопка раскрытия боковой панели (⊞) и иконка калькулятора справа в toolbar
- **Размер окна:** примерно **700 × 430 пикселей** в научном режиме; в стандартном режиме — примерно **340 × 490 пикселей**

#### Дисплей

- **Расположение:** правый верхний угол, выровнен вправо
- **Число/результат:** белый текст, крупный шрифт (~70pt в стандарте, ~48pt при длинных числах), жирность — thin/light
- **Цвет текста:** чисто белый `Color.white`
- **Отступы:** ~16px от правого края, ~8px от верхнего тулбара до числа

#### Кнопки — три категории цветов

| Категория | Цвет фона | Примеры кнопок |
|-----------|-----------|----------------|
| **Серо-тёмные (функциональные)** | Тёмно-серый, ~`#3A3A3C` | AC, ⌫, %, ( ), mc, m+, m–, mr, 2ⁿᵈ, sin⁻¹, cos⁻¹, … |
| **Оранжевые (арифметические операторы)** | Фирменный оранжевый Apple `#FF9500` | ÷, ×, −, +, = |
| **Средне-серые (цифры и некоторые функции)** | Средне-серый, ~`#505050` | 7, 8, 9, 4, 5, 6, 1, 2, 3, 0, ,, +/− |

#### Форма кнопок

- **Форма:** идеальная окружность (circle), кнопка — `Circle()` или `RoundedRectangle(cornerRadius: .infinity)`
- **Размер кнопок:** в научном режиме примерно **48 × 48 pt**, в стандартном — **66 × 66 pt**
- **Расстояние между кнопками:** ~12 pt в научном режиме, ~16 pt в стандартном

#### Шрифт кнопок

- **Цифры (0–9):** SF Pro Display, ~22pt, weight `.regular`
- **Операторы (+, −, ×, ÷, =):** SF Pro Display, ~24pt, weight `.regular`
- **Функции (sin, cos, mc, m+, …):** SF Pro, ~13–14pt, weight `.regular`, умещается в круг
- **Надстрочные индексы:** sf-символы или Unicode надстрочные символы

#### Сетка кнопок в научном режиме (10 колонок × 5 строк)

```
Строка 1: (   )   mc  m+  m-  mr  [⌫]  AC   %    ÷
Строка 2: 2ⁿᵈ x²  x³  xʸ  yˣ  2ˣ   7    8    9    ×
Строка 3: 1/x ²√x ³√x ʸ√x logᵧ log₂  4    5    6    −
Строка 4: x!  sin⁻¹ cos⁻¹ tan⁻¹ e  EE   1    2    3    +
Строка 5: Rand sinh⁻¹ cosh⁻¹ tanh⁻¹ π Rad +/−   0    ,    =
```

> **Важно:** `=` в научном режиме — отдельная кнопка такого же размера, как и остальные (НЕ широкая).  
> В стандартном режиме (4 колонки × 5 строк) `0` — широкая (занимает 2 колонки), `=` — обычная.

---

## РАЗДЕЛ 1: Анализ текущего состояния (что сделано неправильно)

### 1.1 Текущий вид vs. эталон

| Элемент | Сейчас | Должно быть |
|---------|--------|-------------|
| Форма кнопок | `RoundedRectangle(cornerRadius: 12)` прямоугольники | Идеальные круги |
| Фон кнопок цифр | `Color.gray` — захардкожен | Средне-серый ~`#505050` |
| Фон кнопок операторов | `Color.orange` — захардкожен | Оранжевый #FF9500 с точными значениями |
| Фон кнопок функций (AC, %) | `Color.gray` — захардкожен | Тёмно-серый ~`#3A3A3C` |
| Фон калькулятора | `Color.black` | Тёмно-синий/тёмный (адаптивный) |
| Размер кнопок | Высота 60pt, прямоугольные | Квадратные ~66pt, круглые |
| Режим | Только стандартный (4 кол.) | Стандартный + переключатель в Scientific |
| Дисплей: выражение | Маленький текст 18pt сверху | Нет отдельного поля выражения — только результат |
| Дисплей: результат | Авто-шрифт 24–42pt | Крупный, вплоть до 70pt, thin-weight |
| Кнопка ⌫ (backspace) | Отсутствует на панели | Есть на панели как видимая кнопка |
| Кнопка AC / C | Одна кнопка "C" | "AC" при пустом поле, "C" при наличии текста |
| Кнопка +/− | Отсутствует | Должна быть |
| Символ ÷ | "/" | "÷" (UTF-8 символ) |
| Символ × | "*" | "×" (UTF-8 символ) |
| Символ − | "-" | "−" (UTF-8 минус, не дефис) |
| Запятая | "." | "," (в стандартном — запятая как десятичный разделитель) |
| Режим Light/Dark | Только Dark | Адаптивный |

### 1.2 Затронутые файлы

- `Sources/Theme/CalculatorColors.swift` — полная переработка
- `Sources/Views/CalculatorButton.swift` — форма, анимации, accessibility
- `Sources/Views/CalculatorView.swift` — сетка кнопок, режимы, layout
- `Sources/Views/DisplayView.swift` — шрифты, layout, поведение
- `Sources/App/CalculatorApp.swift` — размер окна, Window settings
- `Sources/ViewModels/CalculatorViewModel.swift` — кнопки AC/C, +/−, обработка ÷ × −

---

## РАЗДЕЛ 2: Этап 1 — Цветовая система (приоритет: критический)

### 2.1 Что нужно сделать

Полностью переписать `Sources/Theme/CalculatorColors.swift`.

Нынешний файл захардкожен в чёрно-серое, без адаптации к Light/Dark Mode.  
macOS Tahoe использует строго определённую палитру.

### 2.2 Анализ цветов эталона (точные значения)

Анализируя скриншот Tahoe Calculator в Dark Mode:

**Фон окна:**
- Dark Mode: тёмно-синий ~`rgb(28, 43, 58)` — это `NSColor.windowBackgroundColor` поверх `.hudWindow` material

**Кнопки-цифры (7,8,9,4,5,6,1,2,3,0,,+/−):**
- Dark Mode: средне-серый ~`rgb(80, 80, 80)` → `#505050`
- Light Mode: белый с лёгкой тенью ~`rgb(255, 255, 255)` → `NSColor.controlBackgroundColor`

**Кнопки функций (AC,⌫,%,(,),mc,m+,m−,mr,2ⁿᵈ,sin⁻¹,…):**
- Dark Mode: тёмно-серый ~`rgb(58, 58, 60)` → `#3A3A3C`
- Light Mode: светло-серый ~`rgb(209, 209, 214)` → `#D1D1D6`

**Кнопки операторов (÷,×,−,+,=):**
- Dark Mode AND Light Mode: оранжевый `#FF9500` (системный `NSColor.systemOrange`)
- Текст на них: всегда белый

**Текст на дисплее:**
- Dark Mode: белый `Color.white`
- Light Mode: чёрный `Color.black`

**Текст кнопок (не-операторы):**
- Dark Mode: белый `Color.white`
- Light Mode: чёрный `Color.black`

### 2.3 Новый код файла `Sources/Theme/CalculatorColors.swift`

**Удали весь текущий код и замени следующим:**

```swift
import SwiftUI
import AppKit

// MARK: - Цветовая система, эталон: Calculator.app macOS Tahoe 26

struct CalculatorColors {

    // MARK: Фон окна/приложения
    /// Основной фон — адаптируется к Light/Dark Mode
    static let background = Color(nsColor: .windowBackgroundColor)

    // MARK: Фон дисплея
    /// Дисплей прозрачный, текст поверх фона окна
    static let displayBackground = Color.clear

    // MARK: Кнопки — цифры и нейтральные (0-9, +/−, запятая)
    /// Dark Mode: ~#505050, Light Mode: белый
    static let buttonDigit = Color(
        light: Color(red: 1.0, green: 1.0, blue: 1.0),
        dark:  Color(red: 0.314, green: 0.314, blue: 0.314)
    )

    // MARK: Кнопки — функциональные (AC/C, ⌫, %, скобки, научные)
    /// Dark Mode: ~#3A3A3C, Light Mode: ~#D1D1D6
    static let buttonFunction = Color(
        light: Color(red: 0.820, green: 0.820, blue: 0.831),
        dark:  Color(red: 0.227, green: 0.227, blue: 0.235)
    )

    // MARK: Кнопки — арифметические операторы (÷, ×, −, +, =)
    /// Всегда оранжевый (#FF9500), независимо от темы
    static let buttonOperator = Color(red: 1.0, green: 0.584, blue: 0.0) // #FF9500

    // MARK: Текст на цифровых и функциональных кнопках
    /// Dark Mode: белый, Light Mode: чёрный
    static let buttonTextPrimary = Color(nsColor: .labelColor)

    // MARK: Текст на кнопках операторов
    /// Всегда белый (контраст на оранжевом)
    static let buttonTextOperator = Color.white

    // MARK: Основной текст дисплея (число/результат)
    /// Dark Mode: белый, Light Mode: чёрный
    static let displayTextPrimary = Color(nsColor: .labelColor)

    // MARK: Вторичный текст дисплея (выражение/история)
    /// Dark Mode: светло-серый, Light Mode: тёмно-серый
    static let displayTextSecondary = Color(nsColor: .secondaryLabelColor)

    // MARK: Цвет ошибки на дисплее
    static let errorText = Color(nsColor: .systemRed)

    // MARK: Нажатое состояние кнопки (highlight)
    /// Светлее исходного цвета на 15–20%
    static func pressedColor(for base: Color) -> Color {
        return base.opacity(0.7)
    }
}

// MARK: - Вспомогательное расширение для Light/Dark инициализации

extension Color {
    /// Создаёт цвет с разными значениями для Light и Dark Mode
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua:
                return NSColor(dark)
            default:
                return NSColor(light)
            }
        })
    }
}
```

### 2.4 Проверка после изменения

1. Запусти приложение (`swift run CalculatorApp` или через Xcode)
2. Переключись в Dark Mode (System Preferences → Appearance → Dark)
3. Убедись, что фон тёмно-серый/синий, НЕ чёрный
4. Переключись в Light Mode → кнопки цифр должны стать белыми/светло-серыми
5. Операторные кнопки должны оставаться оранжевыми в обоих режимах

---

## РАЗДЕЛ 3: Этап 2 — Переработка формы и размеров кнопок (приоритет: критический)

### 3.1 Что нужно сделать

Текущий `CalculatorButton.swift` использует прямоугольники с закруглёнными углами.  
Эталон macOS Tahoe — **идеальные круги**.

### 3.2 Полная замена `Sources/Views/CalculatorButton.swift`

**Удали весь текущий код и замени следующим:**

```swift
import SwiftUI

// MARK: - Типы кнопок калькулятора

enum CalcButtonType {
    /// Цифры (0–9), запятая, +/−
    case digit
    /// Арифметические операторы (÷, ×, −, +, =)
    case `operator`
    /// Функциональные кнопки (AC/C, ⌫, %, скобки, научные функции)
    case function
}

// MARK: - Метка кнопки

enum ButtonLabel {
    // Стандартный режим
    case digit(String)                    // "0"–"9"
    case decimalSeparator                 // ","
    case clear                            // "AC" или "C" — динамически
    case backspace                        // "⌫"
    case plusMinus                        // "+/−"
    case percent                          // "%"
    case divide                           // "÷"
    case multiply                         // "×"
    case subtract                         // "−"
    case add                              // "+"
    case equals                           // "="
    case openParen                        // "("
    case closeParen                       // ")"
    // Научный режим
    case mc, mPlus, mMinus, mR           // память
    case secondFunc                       // "2ⁿᵈ"
    case xSquared                         // "x²"
    case xCubed                           // "x³"
    case xToY                             // "xʸ"
    case yToX                             // "yˣ"
    case twoToX                           // "2ˣ"
    case reciprocal                       // "¹/ₓ"
    case sqrtN(Int)                       // "²√x" (n=2), "³√x" (n=3), "ʸ√x" (n=0)
    case logY                             // "logᵧ"
    case log2                             // "log₂"
    case factorial                        // "x!"
    case sinInv, cosInv, tanInv          // "sin⁻¹", "cos⁻¹", "tan⁻¹"
    case eulerConst                       // "e"
    case ee                               // "EE"
    case rand                             // "Rand"
    case sinhInv, coshInv, tanhInv       // "sinh⁻¹", "cosh⁻¹", "tanh⁻¹"
    case pi                               // "π"
    case rad                              // "Rad"

    var displayTitle: String {
        switch self {
        case .digit(let s):        return s
        case .decimalSeparator:    return ","
        case .clear:               return "AC"   // CalculatorButton.body переопределяет на "C" если нужно
        case .backspace:           return "⌫"
        case .plusMinus:           return "+/−"
        case .percent:             return "%"
        case .divide:              return "÷"
        case .multiply:            return "×"
        case .subtract:            return "−"
        case .add:                 return "+"
        case .equals:              return "="
        case .openParen:           return "("
        case .closeParen:          return ")"
        case .mc:                  return "mc"
        case .mPlus:               return "m+"
        case .mMinus:              return "m−"
        case .mR:                  return "mr"
        case .secondFunc:          return "2ⁿᵈ"
        case .xSquared:            return "x²"
        case .xCubed:              return "x³"
        case .xToY:                return "xʸ"
        case .yToX:                return "yˣ"
        case .twoToX:              return "2ˣ"
        case .reciprocal:          return "¹/ₓ"
        case .sqrtN(let n):        return n == 2 ? "²√x" : n == 3 ? "³√x" : "ʸ√x"
        case .logY:                return "logᵧ"
        case .log2:                return "log₂"
        case .factorial:           return "x!"
        case .sinInv:              return "sin⁻¹"
        case .cosInv:              return "cos⁻¹"
        case .tanInv:              return "tan⁻¹"
        case .eulerConst:          return "e"
        case .ee:                  return "EE"
        case .rand:                return "Rand"
        case .sinhInv:             return "sinh⁻¹"
        case .coshInv:             return "cosh⁻¹"
        case .tanhInv:             return "tanh⁻¹"
        case .pi:                  return "π"
        case .rad:                 return "Rad"
        }
    }

    /// Значение, которое отправляется в ViewModel при нажатии
    var inputValue: String {
        switch self {
        case .decimalSeparator:    return "."
        case .divide:              return "/"
        case .multiply:            return "*"
        case .subtract:            return "-"
        case .add:                 return "+"
        case .openParen:           return "("
        case .closeParen:          return ")"
        case .eulerConst:          return "e"
        case .pi:                  return "π"
        case .xSquared:            return "sq"
        case .xCubed:              return "cube"
        case .xToY:                return "pow"
        case .yToX:                return "pow"
        case .twoToX:              return "exp2"
        case .reciprocal:          return "recip"
        case .sqrtN(let n):        return n == 2 ? "sqrt2" : n == 3 ? "sqrt3" : "sqrty"
        case .logY:                return "logy"
        case .log2:                return "log2"
        case .factorial:           return "fact"
        case .sinInv:              return "asin"
        case .cosInv:              return "acos"
        case .tanInv:              return "atan"
        case .ee:                  return "EE"
        case .sinhInv:             return "asinh"
        case .coshInv:             return "acosh"
        case .tanhInv:             return "atanh"
        default:                   return displayTitle
        }
    }

    /// Описание для VoiceOver / Accessibility
    var accessibilityDescription: String {
        switch self {
        case .divide:              return "Разделить"
        case .multiply:            return "Умножить"
        case .subtract:            return "Минус"
        case .add:                 return "Плюс"
        case .equals:              return "Равно"
        case .clear:               return "Очистить"
        case .backspace:           return "Удалить последний символ"
        case .plusMinus:           return "Изменить знак"
        case .percent:             return "Процент"
        case .decimalSeparator:    return "Десятичная запятая"
        case .pi:                  return "Число Пи"
        case .eulerConst:          return "Число e"
        case .sinInv:              return "Арксинус"
        case .cosInv:              return "Арккосинус"
        case .tanInv:              return "Арктангенс"
        case .factorial:           return "Факториал"
        case .xSquared:            return "В квадрате"
        case .xCubed:              return "В кубе"
        case .reciprocal:          return "Обратная величина"
        case .mc:                  return "Очистить память"
        case .mPlus:               return "Добавить в память"
        case .mMinus:              return "Вычесть из памяти"
        case .mR:                  return "Вспомнить из памяти"
        case .rand:                return "Случайное число"
        case .rad:                 return "Переключить Радианы / Градусы"
        case .ee:                  return "Экспоненциальная запись"
        default:                   return displayTitle
        }
    }
}

// MARK: - Спецификация кнопки

struct ButtonSpec: Identifiable {
    let id = UUID()
    let label: ButtonLabel
    let type: CalcButtonType
    var isWide: Bool = false   // true только для кнопки "0" в стандартном режиме
}

// MARK: - Кнопка калькулятора (круглая, macOS Tahoe style)

struct CalculatorButton: View {

    let spec: ButtonSpec
    let diameter: CGFloat
    let fontSize: CGFloat
    let isAC: Bool              // true → "AC", false → "C" (только для .clear)
    let onTap: (ButtonLabel) -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Цвета

    private var backgroundColor: Color {
        switch spec.type {
        case .digit:     return CalculatorColors.buttonDigit
        case .operator:  return CalculatorColors.buttonOperator
        case .function:  return CalculatorColors.buttonFunction
        }
    }

    private var foregroundColor: Color {
        switch spec.type {
        case .operator:  return CalculatorColors.buttonTextOperator
        default:         return CalculatorColors.buttonTextPrimary
        }
    }

    private var displayText: String {
        if case .clear = spec.label {
            return isAC ? "AC" : "C"
        }
        return spec.label.displayTitle
    }

    // MARK: Body

    var body: some View {
        // Широкая кнопка (capsule): диаметр × 2 + spacing (12)
        let targetWidth: CGFloat = spec.isWide ? diameter * 2 + 12 : diameter

        Button {
            onTap(spec.label)
        } label: {
            Text(displayText)
                .font(.system(size: fontSize, weight: .regular, design: .rounded))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(foregroundColor)
                .frame(width: targetWidth, height: diameter)
                .background(
                    isPressed
                        ? CalculatorColors.pressedColor(for: backgroundColor)
                        : backgroundColor
                )
                .clipShape(
                    spec.isWide
                        ? AnyShape(Capsule())
                        : AnyShape(Circle())
                )
        }
        .buttonStyle(.plain)
        .frame(width: targetWidth, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.08),
            value: isPressed
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .accessibilityLabel(spec.label.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("calc_btn_\(displayText.replacingOccurrences(of: "/", with: "div"))")
    }
}

// MARK: - AnyShape (совместимость)

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { _path = shape.path(in:) }
    func path(in rect: CGRect) -> Path { _path(rect) }
}
```

---

## РАЗДЕЛ 4: Этап 3 — Переработка дисплея (приоритет: высокий)

### 4.1 Что должно быть на дисплее

Анализируя скриншот Tahoe:

1. **Только одна строка числа** — крупный, правовыровненный
2. **Выражение** (вводимое) — мелкий текст сверху (только если идёт ввод)
3. **Нет отдельного «result» поля** — при нажатии "=" число на дисплее сменяется результатом с анимацией
4. **Адаптивный размер шрифта** — уменьшается при длинных числах

### 4.2 Точные параметры дисплея

| Условие | Размер шрифта | Вес |
|---------|---------------|-----|
| Число ≤ 9 символов | 70pt | `.thin` |
| Число 10–12 символов | 56pt | `.thin` |
| Число 13–15 символов | 44pt | `.light` |
| Число > 15 символов | 32pt | `.regular` |
| Выражение (сверху) | 18pt | `.regular` |
| Сообщение об ошибке | 22pt | `.regular` |

### 4.3 Полная замена `Sources/Views/DisplayView.swift`

```swift
import SwiftUI

struct DisplayView: View {
    let expression: String
    let result: String?
    let errorMessage: String?

    @State private var resultOpacity: Double = 1.0
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {

            // --- Строка выражения (показывается только при активном вводе) ---
            if !expression.isEmpty && result == nil && errorMessage == nil {
                Text(formattedExpression)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(CalculatorColors.displayTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 4)

            // --- Главное число / результат / ошибка ---
            Group {
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                        .foregroundStyle(CalculatorColors.errorText)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.7)
                        .offset(x: shakeOffset)
                        .onChange(of: errorMessage) { _, newError in
                            guard newError != nil else { return }
                            // Анимация shake при ошибке
                            withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
                                shakeOffset = 6
                            }
                            Task {
                                try? await Task.sleep(nanoseconds: 350_000_000)
                                shakeOffset = 0
                            }
                        }
                } else {
                    let mainText = result ?? (expression.isEmpty ? "0" : expression)
                    Text(mainText)
                        .font(adaptiveFont(for: mainText))
                        .foregroundStyle(CalculatorColors.displayTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .truncationMode(.middle)
                        .opacity(resultOpacity)
                        .onChange(of: result) { _, newValue in
                            guard newValue != nil else { return }
                            // Flash при появлении результата
                            withAnimation(.easeIn(duration: 0.05)) {
                                resultOpacity = 0.6
                            }
                            withAnimation(.easeOut(duration: 0.12).delay(0.05)) {
                                resultOpacity = 1.0
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.15), value: expression.isEmpty)
        // Accessibility для всего дисплея
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            if let error = errorMessage {
                return "Ошибка: \(error)"
            } else if let result = result {
                return "Результат: \(result)"
            } else {
                return expression.isEmpty ? "Ноль" : "Выражение: \(expression)"
            }
        }())
    }

    // MARK: - Адаптивный шрифт

    private func adaptiveFont(for text: String) -> Font {
        let count = text.count
        switch count {
        case 0...9:   return .system(size: 70, weight: .thin,    design: .rounded)
        case 10...12: return .system(size: 56, weight: .thin,    design: .rounded)
        case 13...15: return .system(size: 44, weight: .light,   design: .rounded)
        default:      return .system(size: 32, weight: .regular, design: .rounded)
        }
    }

    // MARK: - Форматирование выражения для отображения

    private var formattedExpression: String {
        expression
            .replacingOccurrences(of: "/", with: " ÷ ")
            .replacingOccurrences(of: "*", with: " × ")
            .replacingOccurrences(of: "-", with: " − ")
            .replacingOccurrences(of: ".", with: ",")
    }
}
```

---

## РАЗДЕЛ 5: Этап 4 — Переработка сетки кнопок и режимов (приоритет: критический)

### 5.1 Стандартный режим (4 колонки × 5 строк)

```
Строка 1: AC/C   +/−   %    ÷
Строка 2:  7      8     9    ×
Строка 3:  4      5     6    −
Строка 4:  1      2     3    +
Строка 5:  0(wide)      ,    =
```

### 5.2 Научный режим (10 колонок × 5 строк)

```
Строка 1:  (    )   mc   m+   m−   mr   ⌫    AC   %    ÷
Строка 2: 2ⁿᵈ  x²   x³   xʸ   yˣ   2ˣ   7    8    9    ×
Строка 3: ¹/ₓ  ²√x  ³√x  ʸ√x  logᵧ log₂  4    5    6    −
Строка 4:  x!  sin⁻¹ cos⁻¹ tan⁻¹ e  EE   1    2    3    +
Строка 5: Rand sinh⁻¹ cosh⁻¹ tanh⁻¹ π Rad +/−  0    ,    =
```

### 5.3 Полная замена `Sources/Views/CalculatorView.swift`

```swift
import SwiftUI

// MARK: - Режим калькулятора

enum CalculatorMode {
    case standard
    case scientific
}

// MARK: - Главный вид калькулятора

struct CalculatorView: View {

    @Bindable var viewModel: CalculatorViewModel
    @Binding var showHistory: Bool
    @State private var mode: CalculatorMode = .standard

    // Размеры — зависят от режима
    private var buttonDiameter: CGFloat { mode == .standard ? 66 : 48 }
    private var buttonFontSize: CGFloat  { mode == .standard ? 22 : 16 }
    private var buttonSpacing: CGFloat   { mode == .standard ? 14 : 10 }

    // AC или C — зависит от состояния ViewModel
    private var isAC: Bool {
        viewModel.expression.isEmpty && viewModel.result == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            DisplayView(
                expression: viewModel.expression,
                result: viewModel.result,
                errorMessage: viewModel.errorMessage
            )
            .frame(minHeight: 90)

            Divider()
                .opacity(0.3)
                .padding(.horizontal, 12)

            Group {
                if mode == .standard {
                    standardButtonGrid
                } else {
                    scientificButtonGrid
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.easeInOut(duration: 0.25), value: mode)
        }
        .background(CalculatorColors.background)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        mode = (mode == .standard) ? .scientific : .standard
                    }
                } label: {
                    Image(systemName: mode == .standard ? "function" : "number")
                }
                .help(mode == .standard ? "Переключить на научный режим" : "Переключить на стандартный режим")
                .accessibilityLabel(mode == .standard ? "Переключить на научный режим" : "Переключить на стандартный режим")
            }

            ToolbarItem(placement: .automatic) {
                Button { showHistory = true } label: {
                    Image(systemName: "clock")
                }
                .help("История вычислений")
                .accessibilityLabel("История")
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryPanelView(viewModel: viewModel)
                .frame(width: 340, height: 500)
        }
    }

    // MARK: - Стандартная сетка (4 колонки)

    @ViewBuilder
    private var standardButtonGrid: some View {
        VStack(spacing: buttonSpacing) {
            buttonRow([
                ButtonSpec(label: .clear,            type: .function),
                ButtonSpec(label: .plusMinus,         type: .function),
                ButtonSpec(label: .percent,           type: .function),
                ButtonSpec(label: .divide,            type: .operator),
            ])
            buttonRow([
                ButtonSpec(label: .digit("7"), type: .digit),
                ButtonSpec(label: .digit("8"), type: .digit),
                ButtonSpec(label: .digit("9"), type: .digit),
                ButtonSpec(label: .multiply,   type: .operator),
            ])
            buttonRow([
                ButtonSpec(label: .digit("4"), type: .digit),
                ButtonSpec(label: .digit("5"), type: .digit),
                ButtonSpec(label: .digit("6"), type: .digit),
                ButtonSpec(label: .subtract,   type: .operator),
            ])
            buttonRow([
                ButtonSpec(label: .digit("1"), type: .digit),
                ButtonSpec(label: .digit("2"), type: .digit),
                ButtonSpec(label: .digit("3"), type: .digit),
                ButtonSpec(label: .add,        type: .operator),
            ])
            buttonRow([
                ButtonSpec(label: .digit("0"),       type: .digit, isWide: true),
                ButtonSpec(label: .decimalSeparator, type: .digit),
                ButtonSpec(label: .equals,           type: .operator),
            ])
        }
    }

    // MARK: - Научная сетка (10 колонок)

    @ViewBuilder
    private var scientificButtonGrid: some View {
        VStack(spacing: buttonSpacing) {
            buttonRow([
                ButtonSpec(label: .openParen,  type: .function),
                ButtonSpec(label: .closeParen, type: .function),
                ButtonSpec(label: .mc,         type: .function),
                ButtonSpec(label: .mPlus,      type: .function),
                ButtonSpec(label: .mMinus,     type: .function),
                ButtonSpec(label: .mR,         type: .function),
                ButtonSpec(label: .backspace,  type: .function),
                ButtonSpec(label: .clear,      type: .function),
                ButtonSpec(label: .percent,    type: .function),
                ButtonSpec(label: .divide,     type: .operator),
            ])
            buttonRow([
                ButtonSpec(label: .secondFunc, type: .function),
                ButtonSpec(label: .xSquared,   type: .function),
                ButtonSpec(label: .xCubed,     type: .function),
                ButtonSpec(label: .xToY,       type: .function),
                ButtonSpec(label: .yToX,       type: .function),
                ButtonSpec(label: .twoToX,     type: .function),
                ButtonSpec(label: .digit("7"), type: .digit),
                ButtonSpec(label: .digit("8"), type: .digit),
                ButtonSpec(label: .digit("9"), type: .digit),
                ButtonSpec(label: .multiply,   type: .operator),
            ])
            buttonRow([
                ButtonSpec(label: .reciprocal,   type: .function),
                ButtonSpec(label: .sqrtN(2),     type: .function),
                ButtonSpec(label: .sqrtN(3),     type: .function),
                ButtonSpec(label: .sqrtN(0),     type: .function),
                ButtonSpec(label: .logY,         type: .function),
                ButtonSpec(label: .log2,         type: .function),
                ButtonSpec(label: .digit("4"),   type: .digit),
                ButtonSpec(label: .digit("5"),   type: .digit),
                ButtonSpec(label: .digit("6"),   type: .digit),
                ButtonSpec(label: .subtract,     type: .operator),
            ])
            buttonRow([
                ButtonSpec(label: .factorial,    type: .function),
                ButtonSpec(label: .sinInv,       type: .function),
                ButtonSpec(label: .cosInv,       type: .function),
                ButtonSpec(label: .tanInv,       type: .function),
                ButtonSpec(label: .eulerConst,   type: .function),
                ButtonSpec(label: .ee,           type: .function),
                ButtonSpec(label: .digit("1"),   type: .digit),
                ButtonSpec(label: .digit("2"),   type: .digit),
                ButtonSpec(label: .digit("3"),   type: .digit),
                ButtonSpec(label: .add,          type: .operator),
            ])
            buttonRow([
                ButtonSpec(label: .rand,         type: .function),
                ButtonSpec(label: .sinhInv,      type: .function),
                ButtonSpec(label: .coshInv,      type: .function),
                ButtonSpec(label: .tanhInv,      type: .function),
                ButtonSpec(label: .pi,           type: .function),
                ButtonSpec(label: .rad,          type: .function),
                ButtonSpec(label: .plusMinus,    type: .function),
                ButtonSpec(label: .digit("0"),   type: .digit),
                ButtonSpec(label: .decimalSeparator, type: .digit),
                ButtonSpec(label: .equals,       type: .operator),
            ])
        }
    }

    // MARK: - Строка кнопок

    @ViewBuilder
    private func buttonRow(_ specs: [ButtonSpec]) -> some View {
        HStack(spacing: buttonSpacing) {
            ForEach(specs) { spec in
                CalculatorButton(
                    spec: spec,
                    diameter: buttonDiameter,
                    fontSize: buttonFontSize,
                    isAC: isAC
                ) { label in
                    handleButtonPress(label)
                }
            }
        }
    }

    // MARK: - Обработчик нажатий

    private func handleButtonPress(_ label: ButtonLabel) {
        switch label {
        case .clear:
            viewModel.clear()
        case .equals:
            viewModel.evaluate()
        case .backspace:
            viewModel.backspace()
        case .plusMinus:
            viewModel.toggleSign()
        case .percent:
            viewModel.appendCharacter("%")
        case .divide, .multiply, .subtract, .add,
             .openParen, .closeParen:
            viewModel.appendCharacter(label.inputValue)
        case .decimalSeparator:
            viewModel.appendCharacter(".")
        case .pi:
            viewModel.appendCharacter("π")
        case .eulerConst:
            viewModel.appendCharacter("e")
        case .digit(let d):
            viewModel.appendCharacter(d)
        case .mc:
            viewModel.memoryClear()
        case .mPlus:
            viewModel.memoryAdd()
        case .mMinus:
            viewModel.memorySubtract()
        case .mR:
            viewModel.memoryRecall()
        case .rand:
            viewModel.insertRandom()
        case .rad:
            viewModel.toggleRadDeg()
        case .secondFunc:
            break // TODO: переключение режима кнопок (2ⁿᵈ)
        default:
            viewModel.appendFunction(label.inputValue)
        }
    }
}
```

---

## РАЗДЕЛ 6: Этап 5 — Размер окна и App Entry Point (приоритет: высокий)

### 6.1 Правила размеров по эталону

| Режим | Ширина | Высота |
|-------|--------|--------|
| Стандартный | 340 pt | 490 pt |
| Научный | 700 pt | 440 pt |
| Изменение размера | Нет (фиксированный) | Нет |

### 6.2 Обновление `Sources/App/CalculatorApp.swift`

```swift
import SwiftUI

@main
struct CalculatorApp: App {
    @State private var viewModel = CalculatorViewModel()   // @Observable

    var body: some Scene {
        WindowGroup {
            CalculatorContentView(viewModel: viewModel)
                .preferredColorScheme(nil)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)     // окно подстраивается под контент
        .defaultSize(width: 340, height: 490) // стандартный режим
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct CalculatorContentView: View {
    @Bindable var viewModel: CalculatorViewModel  // @Observable
    @State private var showHistory = false

    var body: some View {
        CalculatorView(viewModel: viewModel, showHistory: $showHistory)
            .background(
                KeyHandlerView(viewModel: viewModel)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            )
    }
}

// KeyHandlerView — изменить @ObservedObject на @Bindable:
struct KeyHandlerView: NSViewRepresentable {
    @Bindable var viewModel: CalculatorViewModel    // было: @ObservedObject

    func makeNSView(context: Context) -> KeyHandlerNSView {
        let view = KeyHandlerNSView()
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: KeyHandlerNSView, context: Context) {
        nsView.viewModel = viewModel
    }
}

// KeyHandlerNSView — без изменений (оставить как есть, weak var viewModel: CalculatorViewModel?)
```

### 6.3 Переход на @Observable в ViewModel

В файле `Sources/ViewModels/CalculatorViewModel.swift`:

```swift
// БЫЛО:
import Foundation
@MainActor
final class CalculatorViewModel: ObservableObject {
    @Published var expression: String = ""
    @Published var result: String? = nil
    @Published var errorMessage: String? = nil

// СТАЛО:
import Foundation
import Observation
@MainActor
@Observable
final class CalculatorViewModel {
    var expression: String = ""
    var result: String? = nil
    var errorMessage: String? = nil
```

**Важно:** Убери `: ObservableObject` из объявления класса и все `@Published` перед свойствами.

---

## РАЗДЕЛ 7: Этап 6 — Новые методы ViewModel (приоритет: высокий)

Открой `Sources/ViewModels/CalculatorViewModel.swift` и **добавь** следующие методы:

### 7.1 Метод `toggleSign()`

```swift
/// Инвертирует знак текущего числа/выражения
func toggleSign() {
    if expression.isEmpty {
        if let result, let val = Decimal(string: result) {
            let negated = -val
            expression = negated.description
            self.result = nil
        }
    } else {
        if expression.hasPrefix("-") {
            expression = String(expression.dropFirst())
        } else {
            expression = "-(\(expression))"
        }
    }
    errorMessage = nil
}
```

### 7.2 Методы памяти

```swift
private var memoryValue: Decimal = 0

func memoryClear() {
    memoryValue = 0
}

func memoryAdd() {
    guard let result, let val = Decimal(string: result) else { return }
    memoryValue += val
}

func memorySubtract() {
    guard let result, let val = Decimal(string: result) else { return }
    memoryValue -= val
}

func memoryRecall() {
    expression = memoryValue.description
    result = nil
    errorMessage = nil
}
```

### 7.3 Методы вставки и научных функций

```swift
func insertRandom() {
    let randomDouble = Double.random(in: 0..<1)
    expression = String(format: "%.5f", randomDouble)
    result = nil
    errorMessage = nil
}

private(set) var isRadians: Bool = true

func toggleRadDeg() {
    isRadians.toggle()
    // TODO: передать флаг в CalculatorEngine
}

/// Вставляет научную функцию: func(выражение)
func appendFunction(_ funcName: String) {
    if let result {
        expression = "\(funcName)(\(result))"
        self.result = nil
    } else if !expression.isEmpty {
        expression = "\(funcName)(\(expression))"
    } else {
        expression = "\(funcName)("
    }
    errorMessage = nil
}
```

---

## РАЗДЕЛ 8: Этап 7 — Клавиатурная навигация (приоритет: средний)

Обнови `keyDown` в `KeyHandlerNSView` (файл `Sources/App/CalculatorApp.swift`):

```swift
override func keyDown(with event: NSEvent) {
    guard let viewModel else { return }

    let code = event.keyCode
    let characters = event.charactersIgnoringModifiers ?? ""

    switch code {
    case 53:        // Escape → AC/C
        viewModel.clear()
    case 51:        // Backspace/Delete
        viewModel.backspace()
    case 36, 76:    // Return / Enter → =
        viewModel.evaluate()
    case 75:        // Numpad /
        viewModel.appendCharacter("/")
    case 67:        // Numpad *
        viewModel.appendCharacter("*")
    case 78:        // Numpad −
        viewModel.appendCharacter("-")
    case 69:        // Numpad +
        viewModel.appendCharacter("+")
    default:
        if !characters.isEmpty {
            let char = characters.first ?? " "
            if char.isNumber || "+-*/().%,πe".contains(char) {
                let normalized = char == "," ? "." : String(char)
                viewModel.appendCharacter(normalized)
            }
        }
    }
}
```

---

## РАЗДЕЛ 9: Порядок исполнения (чеклист для разработчика)

Выполняй **строго в этом порядке**:

### Фаза 1: Основа

- [ ] **9.1** Создай новый `CalculatorColors.swift` (Раздел 2.3)
- [ ] **9.2** Создай новый `CalculatorButton.swift` с `ButtonLabel`, `ButtonSpec`, `CalcButtonType` (Раздел 3.2)
- [ ] **9.3** Переведи ViewModel на `@Observable` (Раздел 6.3)
- [ ] **9.4** Добавь новые методы в ViewModel (Раздел 7)
- [ ] **9.5** Создай новый `DisplayView.swift` (Раздел 4.3)
- [ ] **9.6** Создай новый `CalculatorView.swift` (Раздел 5.3)
- [ ] **9.7** Обнови `CalculatorApp.swift` (Раздел 6.2)

**→ Контрольная точка: `swift build` должен пройти без ошибок**

### Фаза 2: Функциональность

- [ ] **9.8** Тест стандартного режима: все 19 кнопок работают
- [ ] **9.9** Тест научного режима: 50 кнопок отображаются и реагируют
- [ ] **9.10** Light/Dark Mode — цвета адаптируются корректно
- [ ] **9.11** Клавиатурный ввод: цифры, Enter, Backspace, Escape

### Фаза 3: Полировка

- [ ] **9.12** Анимации: нажатие кнопок, появление результата, ошибка shake
- [ ] **9.13** Переключение режима анимировано, окно меняет ширину
- [ ] **9.14** `swift test` — все тесты проходят
- [ ] **9.15** Сравнение визуала со скриншотом `standardni kalkulator`

---

## РАЗДЕЛ 10: Частые ошибки и решения

| Ошибка | Решение |
|--------|---------|
| `Cannot find 'CalcButtonType'` | Убедись, что `enum CalcButtonType` объявлен в `CalculatorButton.swift` |
| `@Published` не компилируется с `@Observable` | Удали все `@Published`, оставь просто `var` |
| Кнопки выходят за границы в научном режиме | Уменьши `buttonDiameter` до 46 или `buttonSpacing` до 8 |
| `@ObservedObject` не компилируется | Замени на `@Bindable` (для `@Observable` классов) |
| Цвета не меняются при смене темы | Проверь, нет ли захардкоженных `Color.black/Color.gray` |
| `weak var viewModel: CalculatorViewModel?` — ошибка | Убедись, что ViewModel — класс (`final class`), а не структура |
| Shake-анимация не работает | Используй `Task { try? await Task.sleep(...) }` вместо `DispatchQueue` |
| `.operator` в switch не работает | Экранируй: `case .operator:` → `case .`operator`:` (обратный апостроф) |

---

## РАЗДЕЛ 11: Что НЕ входит в этот план

- Математическая реализация научных функций в CalculatorEngine
- Локализация строк (уже есть в предыдущем плане)
- Сохранение состояния UserDefaults (уже есть в предыдущем плане)
- UI-тесты (уже есть в предыдущем плане)

---

## РАЗДЕЛ 12: Критерий приёмки

Считается выполненным, если:

1. ✅ Кнопки — идеальные круги, как в macOS Tahoe Calculator
2. ✅ Цвета: цифры — #505050 (dark), операторы — #FF9500, функции — #3A3A3C (dark)
3. ✅ Light Mode / Dark Mode адаптируется автоматически
4. ✅ Два режима: стандартный (4×5) и научный (10×5) с переключателем
5. ✅ Переключение режима анимировано, окно меняет ширину
6. ✅ Дисплей: крупный шрифт (до 70pt thin), адаптивный
7. ✅ AC при пустом поле, C при наличии текста
8. ✅ ⌫ Backspace в научном режиме
9. ✅ +/− работает (инвертирует знак)
10. ✅ Символы ÷ × − (не /, *, -)
11. ✅ `swift build` и `swift test` проходят без ошибок
12. ✅ Визуально похоже на скриншот `standardni kalkulator`

---

## Итоговое время

| Этап | Задача | Время |
|------|--------|-------|
| 1 | Цветовая система | 30 мин |
| 2 | CalculatorButton (круги, ButtonLabel) | 45 мин |
| 3 | ViewModel (@Observable + методы) | 45 мин |
| 4 | DisplayView | 30 мин |
| 5 | CalculatorView (сетки, режимы) | 90 мин |
| 6 | CalculatorApp (размер окна) | 15 мин |
| 7 | Клавиатурная навигация | 20 мин |
| 8 | Тестирование и отладка | 60 мин |
| **Итого** | | **~6 часов** |
