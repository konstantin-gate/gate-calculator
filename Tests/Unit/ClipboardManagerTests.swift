import XCTest
import AppKit
@testable import CalculatorApp

/// Unit-тесты для менеджера буфера обмена ClipboardManager.
@MainActor
final class ClipboardManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Очищаем буфер обмена перед каждым тестом для изоляции
        NSPasteboard.general.clearContents()
    }

    /// Проверяет, что setString сохраняет строковое значение в буфер обмена и getString его возвращает.
    func testSetString_StoresValue() {
        let testString = "12345"
        ClipboardManager.shared.setString(testString)

        let retrieved = ClipboardManager.shared.getString()
        XCTAssertEqual(retrieved, testString)
    }

    /// Проверяет, что getString возвращает nil при пустом буфере обмена.
    func testGetString_EmptyClipboard_ReturnsNil() {
        NSPasteboard.general.clearContents()
        let result = ClipboardManager.shared.getString()
        XCTAssertNil(result)
    }

    /// Проверяет, что повторный setString перезаписывает предыдущее значение.
    func testSetString_ReplacesPreviousValue() {
        ClipboardManager.shared.setString("first")
        ClipboardManager.shared.setString("second")

        let retrieved = ClipboardManager.shared.getString()
        XCTAssertEqual(retrieved, "second")
    }

    /// Проверяет, что установка пустой строки корректно сохраняется в буфер обмена.
    func testSetString_EmptyString_ClearsClipboard() {
        ClipboardManager.shared.setString("some value")
        ClipboardManager.shared.setString("")

        let retrieved = ClipboardManager.shared.getString()
        XCTAssertEqual(retrieved, "")
    }

    /// Проверяет, что getString считывает данные, помещённые напрямую через NSPasteboard.
    func testGetString_ReturnsSystemPasteboardValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("external", forType: .string)

        let retrieved = ClipboardManager.shared.getString()
        XCTAssertEqual(retrieved, "external")
    }
}
