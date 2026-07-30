import Foundation

@MainActor
struct MemoryState {
    private(set) var memoryValue: Decimal = 0

    var hasMemory: Bool { memoryValue != 0 }

    mutating func clear() {
        memoryValue = 0
    }

    mutating func add(_ val: Decimal) {
        memoryValue += val
    }

    mutating func subtract(_ val: Decimal) {
        memoryValue -= val
    }

    func displayValue(formatter: NumberFormatterService) -> String? {
        guard memoryValue != 0 else { return nil }
        return formatter.format(memoryValue)
    }

    var valueDescription: String {
        memoryValue.description
    }
}
