import AppKit

/// Менеджер буфера обмена, изолированный на главном акторе.
///
/// Предоставляет единый интерфейс для чтения и записи строк в системный
/// буфер обмена через NSPasteboard.
///
/// Потокобезопасность обеспечивается `@MainActor`: NSPasteboard — AppKit API,
/// безопасный только на главном потоке. NSLock не требуется.
@MainActor
public final class ClipboardManager {

    /// Общий экземпляр менеджера.
    public static let shared = ClipboardManager()

    private init() {}

    /// Получает строку из буфера обмена. Вызов изолирован главным актором.
    public func getString() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    /// Помещает строку в буфер обмена. Вызов изолирован главным актором.
    public func setString(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
