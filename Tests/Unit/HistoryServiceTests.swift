import XCTest
@testable import CalculatorApp

// MARK: - Тесты HistoryService

final class HistoryServiceTests: XCTestCase {

    // MARK: - Тесты добавления записей

    func testAdd_SingleEntry() {
        let service = HistoryService(maxEntries: 3)
        service.add(expression: "2+2", result: 4)
        XCTAssertEqual(service.getEntries().count, 1)
        let entry = service.getEntries()[0]
        XCTAssertEqual(entry.expression, "2+2")
        XCTAssertEqual(entry.result, 4)
        XCTAssertNotNil(entry.id)
        XCTAssertLessThan(entry.timestamp, Date())
        XCTAssertGreaterThan(entry.timestamp, Date().addingTimeInterval(-1))
    }

    func testAdd_MultipleEntries_ReversedOrder() {
        let service = HistoryService(maxEntries: 3)
        service.add(expression: "1", result: 1)
        service.add(expression: "2", result: 2)
        service.add(expression: "3", result: 3)
        XCTAssertEqual(service.getEntries()[0].expression, "3")
        XCTAssertEqual(service.getEntries()[1].expression, "2")
        XCTAssertEqual(service.getEntries()[2].expression, "1")
    }

    // MARK: - Тесты ограничения размера

    func testAdd_MaxEntriesLimit_CapsAtThree() {
        let service = HistoryService(maxEntries: 3)
        for i in 1...5 {
            service.add(expression: "\(i)", result: Decimal(i))
        }
        XCTAssertEqual(service.getEntries().count, 3)
        XCTAssertEqual(service.getEntries()[0].expression, "5")
        XCTAssertEqual(service.getEntries()[1].expression, "4")
        XCTAssertEqual(service.getEntries()[2].expression, "3")
    }

    func testAdd_MaxEntriesBoundary_ExactCount() {
        let service = HistoryService(maxEntries: 3)
        for i in 1...3 {
            service.add(expression: "\(i)", result: Decimal(i))
        }
        XCTAssertEqual(service.getEntries().count, 3)
        XCTAssertEqual(service.getEntries()[0].expression, "3")
        XCTAssertEqual(service.getEntries()[1].expression, "2")
        XCTAssertEqual(service.getEntries()[2].expression, "1")
    }

    func testAdd_MaxEntriesZero_NeverStoresEntries() {
        let service = HistoryService(maxEntries: 0)
        service.add(expression: "1+1", result: Decimal(2))
        XCTAssertEqual(service.count(), 0)
        XCTAssertTrue(service.getEntries().isEmpty)
    }

    func testAdd_MaxEntriesNegative_NeverStoresEntries() {
        let service = HistoryService(maxEntries: -1)
        service.add(expression: "2+2", result: Decimal(4))
        XCTAssertEqual(service.count(), 0)
        XCTAssertTrue(service.getEntries().isEmpty)
    }

    // MARK: - Тесты очистки

    func testClear_EmptyHistory_NoCrash() {
        let service = HistoryService(maxEntries: 3)
        service.clear()
        XCTAssertEqual(service.getEntries().count, 0)
    }

    func testClear_RemovesAllEntries() {
        let service = HistoryService(maxEntries: 3)
        service.add(expression: "1", result: 1)
        service.add(expression: "2", result: 2)
        service.add(expression: "3", result: 3)
        service.clear()
        XCTAssertEqual(service.getEntries().count, 0)
        XCTAssertTrue(service.getEntries().isEmpty)
    }

    // MARK: - Тесты подсчёта

    func testCount_AfterAdd() {
        let service = HistoryService(maxEntries: 3)
        service.add(expression: "1", result: 1)
        service.add(expression: "2", result: 2)
        XCTAssertEqual(service.count(), 2)
    }

    func testCount_AfterClear() {
        let service = HistoryService(maxEntries: 3)
        service.add(expression: "1", result: 1)
        service.add(expression: "2", result: 2)
        service.clear()
        XCTAssertEqual(service.count(), 0)
    }

    func testCount_EmptyService() {
        let service = HistoryService(maxEntries: 3)
        XCTAssertEqual(service.count(), 0)
    }

    // MARK: - Тест изоляции копии

    func testGetEntries_ReturnsCopy() {
        let service = HistoryService(maxEntries: 3)
        service.add(expression: "1+1", result: 2)
        var entries = service.getEntries()
        entries.removeAll()
        XCTAssertEqual(service.count(), 1, "Копия не влияет на сервис")
    }

    // MARK: - Тест потокобезопасности

    func testAdd_ConcurrentAccess() {
        let concurrentService = HistoryService(maxEntries: 200)
        let iterations = 100
        let group = DispatchGroup()

        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                concurrentService.add(expression: "\(i)", result: Decimal(i))
                group.leave()
            }
        }

        group.wait()
        XCTAssertEqual(concurrentService.count(), iterations)
    }
}
