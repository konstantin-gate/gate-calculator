import Foundation

// MARK: - HistoryService

/// Сервис хранения истории вычислений.
///
/// Потокобезопасность: каждая операция защищена `NSLock`.
/// Lock освобождается через `defer` для гарантии высвобождения даже при throws.
/// Внутри методов НЕ выполняются внешние callback-и — взаимных блокировок нет.
///
/// - Precondition: `maxEntries >= 0` (отрицательные значения приводятся к 0).
///
/// ОСОЗНАННОЕ РЕШЕНИЕ: Записи истории хранятся только в оперативной памяти (массив entries).
/// При перезапуске приложения история теряется. Персистентность через UserDefaults или файл
/// не реализована намеренно для минимизации зависимостей и ускорения работы сервиса.
public final class HistoryService: @unchecked Sendable {

    public static let shared = HistoryService()

    private var entries: [HistoryEntry] = []
    private let maxEntries: Int
    private let lock = NSLock()

    public init(maxEntries: Int = 50) {
        self.maxEntries = max(0, maxEntries)
    }

    /// Добавляет запись в историю.
    ///
    /// - Precondition: `maxEntries >= 0` (проверяется в init).
    /// - Thread-safe: блокировка через NSLock.
    public func add(expression: String, result: Decimal, formattedResult: String) {
        lock.lock()
        defer { lock.unlock() }

        guard maxEntries > 0 else { return }

        let entry = HistoryEntry(expression: expression, result: result, formattedResult: formattedResult)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    /// Возвращает копию всех записей истории (новейшие первые).
    ///
    /// - Thread-safe: блокировка через NSLock.
    /// - Возвращает массив-копию: изменения возвращённого значения не влияют на сервис.
    public func getEntries() -> [HistoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    /// Очищает всю историю.
    ///
    /// - Thread-safe: блокировка через NSLock.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    /// Возвращает текущее количество записей.
    ///
    /// - Thread-safe: блокировка через NSLock.
    public func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}
