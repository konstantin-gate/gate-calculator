import Foundation

// MARK: - HistoryService

/// Сервис хранения истории вычислений.
///
/// Потокобезопасность: обеспечена встроенным Swift 6 `actor`.
/// Все операции выполняются изолированно в контексте актора.
///
/// - Precondition: `maxEntries >= 0` (отрицательные значения приводятся к 0).
///
/// ОСОЗНАННОЕ РЕШЕНИЕ: Записи истории хранятся только в оперативной памяти (массив entries).
/// При перезапуске приложения история теряется. Персистентность через UserDefaults или файл
/// не реализована намеренно для минимизации зависимостей и ускорения работы сервиса.
public actor HistoryService {

    public static let shared = HistoryService()

    private var entries: [HistoryEntry] = []
    private let maxEntries: Int

    public init(maxEntries: Int = 50) {
        self.maxEntries = max(0, maxEntries)
    }

    /// Добавляет запись в историю.
    ///
    /// - Precondition: `maxEntries >= 0` (проверяется в init).
    public func add(expression: String, result: Decimal, formattedResult: String) {
        guard maxEntries > 0 else { return }

        let entry = HistoryEntry(expression: expression, result: result, formattedResult: formattedResult)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    /// Возвращает копию всех записей истории (новейшие первые).
    ///
    /// - Возвращает массив-копию: изменения возвращённого значения не влияют на сервис.
    public func getEntries() -> [HistoryEntry] {
        return entries
    }

    /// Очищает всю историю.
    public func clear() {
        entries.removeAll()
    }

    /// Возвращает текущее количество записей.
    public func count() -> Int {
        return entries.count
    }
}
