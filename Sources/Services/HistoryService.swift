import Foundation

public final class HistoryService: @unchecked Sendable {

    public static let shared = HistoryService()

    private var entries: [HistoryEntry] = []
    private let maxEntries: Int
    private let lock = NSLock()

    public init(maxEntries: Int = 50) {
        self.maxEntries = maxEntries
    }

    public func add(expression: String, result: Decimal) {
        lock.lock()
        defer { lock.unlock() }

        let entry = HistoryEntry(expression: expression, result: result)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    public func getEntries() -> [HistoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    public func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}
