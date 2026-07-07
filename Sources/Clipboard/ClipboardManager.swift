import AppKit
import Foundation

/// Менеджер буфера обмена.
///
/// Предоставляет единый интерфейс для чтения и записи строк в системный
/// буфер обмена через NSPasteboard.
public final class ClipboardManager: @unchecked Sendable {

    /// Общий экземпляр менеджера.
    public static let shared = ClipboardManager()

    private init() {}

    // ИСПРАВЛЕНИЕ C-14, M-06: добавлен NSLock для синхронизации доступа к NSPasteboard
    private let lock = NSLock()

    /// Получает строку из буфера обмена.
    public func getString() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return NSPasteboard.general.string(forType: .string)
    }

    /// Помещает строку в буфер обмена.
    public func setString(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
