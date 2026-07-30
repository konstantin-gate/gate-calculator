import XCTest
@testable import CalculatorApp

// MARK: - Тесты HistoryService

@MainActor
final class HistoryServiceTests: XCTestCase {

    // MARK: - Тесты добавления записей

    func testAdd_SingleEntry() async {
        let service = HistoryService(maxEntries: 3)
        await service.add(expression: "2+2", result: 4, formattedResult: "4")
        let entries = await service.getEntries()
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.expression, "2+2")
        XCTAssertEqual(entry.result, 4)
        XCTAssertNotNil(entry.id)
        XCTAssertLessThan(entry.timestamp, Date())
        XCTAssertGreaterThan(entry.timestamp, Date().addingTimeInterval(-1))
    }

    func testAdd_MultipleEntries_ReversedOrder() async {
        let service = HistoryService(maxEntries: 3)
        await service.add(expression: "1", result: 1, formattedResult: "1")
        await service.add(expression: "2", result: 2, formattedResult: "2")
        await service.add(expression: "3", result: 3, formattedResult: "3")
        let entries = await service.getEntries()
        XCTAssertEqual(entries[0].expression, "3")
        XCTAssertEqual(entries[1].expression, "2")
        XCTAssertEqual(entries[2].expression, "1")
    }

    // MARK: - Тесты ограничения размера

    func testAdd_MaxEntriesLimit_CapsAtThree() async {
        let service = HistoryService(maxEntries: 3)
        for i in 1...5 {
            await service.add(expression: "\(i)", result: Decimal(i), formattedResult: NumberFormatterService.shared.format(Decimal(i)))
        }
        let entries = await service.getEntries()
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].expression, "5")
        XCTAssertEqual(entries[1].expression, "4")
        XCTAssertEqual(entries[2].expression, "3")
    }

    func testAdd_MaxEntriesBoundary_ExactCount() async {
        let service = HistoryService(maxEntries: 3)
        for i in 1...3 {
            await service.add(expression: "\(i)", result: Decimal(i), formattedResult: NumberFormatterService.shared.format(Decimal(i)))
        }
        let entries = await service.getEntries()
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].expression, "3")
        XCTAssertEqual(entries[1].expression, "2")
        XCTAssertEqual(entries[2].expression, "1")
    }

    func testAdd_MaxEntriesZero_NeverStoresEntries() async {
        let service = HistoryService(maxEntries: 0)
        await service.add(expression: "1+1", result: Decimal(2), formattedResult: "2")
        let count = await service.count()
        XCTAssertEqual(count, 0)
        let entries = await service.getEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testAdd_MaxEntriesNegative_NeverStoresEntries() async {
        let service = HistoryService(maxEntries: -1)
        await service.add(expression: "2+2", result: Decimal(4), formattedResult: "4")
        let count = await service.count()
        XCTAssertEqual(count, 0)
        let entries = await service.getEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Тесты очистки

    func testClear_EmptyHistory_NoCrash() async {
        let service = HistoryService(maxEntries: 3)
        await service.clear()
        let entries = await service.getEntries()
        XCTAssertEqual(entries.count, 0)
    }

    func testClear_RemovesAllEntries() async {
        let service = HistoryService(maxEntries: 3)
        await service.add(expression: "1", result: 1, formattedResult: "1")
        await service.add(expression: "2", result: 2, formattedResult: "2")
        await service.add(expression: "3", result: 3, formattedResult: "3")
        await service.clear()
        let entries = await service.getEntries()
        XCTAssertEqual(entries.count, 0)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Тесты подсчёта

    func testCount_AfterAdd() async {
        let service = HistoryService(maxEntries: 3)
        await service.add(expression: "1", result: 1, formattedResult: "1")
        await service.add(expression: "2", result: 2, formattedResult: "2")
        let count = await service.count()
        XCTAssertEqual(count, 2)
    }

    func testCount_AfterClear() async {
        let service = HistoryService(maxEntries: 3)
        await service.add(expression: "1", result: 1, formattedResult: "1")
        await service.add(expression: "2", result: 2, formattedResult: "2")
        await service.clear()
        let count = await service.count()
        XCTAssertEqual(count, 0)
    }

    func testCount_EmptyService() async {
        let service = HistoryService(maxEntries: 3)
        let count = await service.count()
        XCTAssertEqual(count, 0)
    }

    // MARK: - Тест изоляции копии

    func testGetEntries_ReturnsCopy() async {
        let service = HistoryService(maxEntries: 3)
        await service.add(expression: "1+1", result: 2, formattedResult: "2")
        var entries = await service.getEntries()
        entries.removeAll()
        let count = await service.count()
        XCTAssertEqual(count, 1, "Копия не влияет на сервис")
    }

    // MARK: - Тест потокобезопасности

    func testAdd_ConcurrentAccess() async {
        let concurrentService = HistoryService(maxEntries: 200)
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    await concurrentService.add(expression: "\(i)", result: Decimal(i), formattedResult: NumberFormatterService.shared.format(Decimal(i)))
                }
            }
        }

        let count = await concurrentService.count()
        XCTAssertEqual(count, iterations)
    }
}
