import Foundation
import CalculatorEngine

@MainActor
struct TestRunnerMain {
    static var totalTests = 0
    static var passedTests = 0
    static var failedTests = 0

    static func check(_ condition: Bool, _ message: String) {
        totalTests += 1
        if condition {
            passedTests += 1
        } else {
            failedTests += 1
            print("  FAIL: \(message)")
        }
    }

    static func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        totalTests += 1
        if actual == expected {
            passedTests += 1
        } else {
            failedTests += 1
            print("  FAIL: \(message) (expected \(expected), got \(actual))")
        }
    }

    static func main() {
        print("TestRunner started!")

        // MARK: - Tokenizer Tests

        print("\n=== Tokenizer Tests ===")

        let tokenizer = Tokenizer()

        check((try? tokenizer.tokenize(""))?.isEmpty == true, "Empty string")

        let t1 = try! tokenizer.tokenize("15+16")
        check(t1.count == 3, "Simple addition: 3 tokens")

        let t2 = try! tokenizer.tokenize("15 + 16")
        check(t1.count == t2.count, "Whitespace independence")

        let t3 = try! tokenizer.tokenize("15+16=")
        check(t3.count == 3, "Equals sign removal")

        let t4 = try! tokenizer.tokenize("15+16\n20+30")
        check(t4.count == 3, "Multiple lines: only first line")

        let t5 = try! tokenizer.tokenize("1.5e3")
        if case .number(let v) = t5[0] { checkEqual(v, 1500, "Exponential: 1.5e3 = 1500") }

        let t6 = try! tokenizer.tokenize("0xFF")
        if case .number(let v) = t6[0] { checkEqual(v, 255, "Hex: 0xFF = 255") }

        let t7 = try! tokenizer.tokenize("0b1010")
        if case .number(let v) = t7[0] { checkEqual(v, 10, "Binary: 0b1010 = 10") }

        let t8 = try! tokenizer.tokenize("0o77")
        if case .number(let v) = t8[0] { checkEqual(v, 63, "Octal: 0o77 = 63") }

        let t9 = try! tokenizer.tokenize("-5+12")
        check(t9.count == 4, "Unary minus: 4 tokens (unaryMinus, number, add, number)")

        // Tokenizer error cases
        do { _ = try tokenizer.tokenize("15+a"); check(false, "Tokenizer: 15+a should throw") 
            } catch { check(true, "Invalid character throws") }
        do { _ = try tokenizer.tokenize("NaN"); check(false, "Tokenizer: NaN should throw") 
            } catch { check(true, "NaN throws") }
        do { _ = try tokenizer.tokenize("Infinity"); check(false, "Tokenizer: Infinity should throw") 
            } catch { check(true, "Infinity throws") }
        do { _ = try tokenizer.tokenize("5++3"); check(false, "Tokenizer: 5++3 should throw") 
            } catch { check(true, "Double operator throws") }

        let t12 = try! tokenizer.tokenize("1,000,000")
        if case .number(let v) = t12[0] { checkEqual(v, 1000000, "Thousands: 1,000,000 = 1000000") }

        let t13 = try! tokenizer.tokenize("50%")
        check(t13.count == 2, "Percent: 2 tokens")

        let t14 = try! tokenizer.tokenize("((15+16)*5)/3")
        check(t14.count == 11, "Complex expression: 11 tokens")

        let t15 = try! tokenizer.tokenize("(50+10)%")
        check(t15.count == 6, "Percent after paren: 6 tokens")

        // MARK: - CalculatorEngine Integration Tests (covers Parser + Evaluator)

        print("\n=== Engine Integration Tests ===")

        let engine = CalculatorEngine()

        checkEqual(try! engine.evaluate("15+16"), 31, "15+16=31")
        checkEqual(try! engine.evaluate("(15+16)*5"), 155, "(15+16)*5=155")
        checkEqual(try! engine.evaluate("-5+12"), 7, "-5+12=7")
        checkEqual(try! engine.evaluate("-(15+16)"), -31, "-(15+16)=-31")
        checkEqual(try! engine.evaluate("3.1415*5"), Decimal(string: "15.7075")!, "3.1415*5=15.7075")
        checkEqual(try! engine.evaluate("50%"), Decimal(string: "0.5")!, "50%=0.5")
        checkEqual(try! engine.evaluate("100 * 5%"), 5, "100*5%=5")
        checkEqual(try! engine.evaluate("100 / 5%"), 2000, "100/5%=2000")
        checkEqual(try! engine.evaluate("0xFF"), 255, "0xFF=255")
        checkEqual(try! engine.evaluate("0b1010"), 10, "0b1010=10")
        checkEqual(try! engine.evaluate("0o77"), 63, "0o77=63")
        checkEqual(try! engine.evaluate("1.5e3"), 1500, "1.5e3=1500")

        checkEqual(try! engine.evaluate("0.1+0.2"), Decimal(string: "0.3")!, "0.1+0.2=0.3 (Decimal)")

        checkEqual(try! engine.evaluate("(15+16+17+18)/4"), Decimal(string: "16.5")!, "(15+16+17+18)/4=16.5")

        let r1 = try! engine.evaluate("15+16")
        let r2 = try! engine.evaluate("15 + 16")
        checkEqual(r1, r2, "Whitespace independence (engine)")

        let r3 = try! engine.evaluate("15+16=")
        checkEqual(r1, r3, "Equals sign ignored (engine)")

        let r4 = try! engine.evaluate("15+16\n20+30")
        checkEqual(r1, r4, "Newline handling (engine)")

        checkEqual(try! engine.evaluate("5%+10"), Decimal(string: "10.05")!, "5%+10=10.05")
        checkEqual(try! engine.evaluate("(50+10)%"), Decimal(string: "0.6")!, "(50+10)%=0.6")
        checkEqual(try! engine.evaluate("100+5%"), 105, "100+5%=105 (relative)")
        checkEqual(try! engine.evaluate("100-5%"), 95, "100-5%=95 (relative)")
        checkEqual(try! engine.evaluate("100+10%"), 110, "100+10%=110 (relative)")
        checkEqual(try! engine.evaluate("200-10%"), 180, "200-10%=180 (relative)")
        checkEqual(try! engine.evaluate("-100+5%"), -105, "-100+5%=-105 (negative base)")
        checkEqual(try! engine.evaluate("15+16+17+18"), 66, "15+16+17+18=66")
        checkEqual(try! engine.evaluate("5*-3"), -15, "5*-3=-15")

        // MARK: - Тесты европейского формата чисел (разделители тысяч/десятичные запятые)

        print("\n=== European Number Format Tests ===")

        // Баговый кейс из задачи: выражение с пробелами-тысячными и десятичной запятой
        checkEqual(try! engine.evaluate("42600 -37 878,07"), Decimal(string: "4721.93")!,
                     "42600-37878.07=4721.93 (пробелы+запятая)")

        // Пробелы как разделители тысяч в сложном выражении
        checkEqual(try! engine.evaluate("1 000 + 2 500"), Decimal(string: "3500")!,
                     "1000+2500=3500 (пробелы-тысячные)")

        // Смешанный формат: пробел-тысячный + десятичная запятая
        checkEqual(try! engine.evaluate("1 234,56 + 789"), Decimal(string: "2023.56")!,
                     "1234.56+789=2023.56 (смешанный)")

        // Только десятичная запятая без пробелов
        checkEqual(try! engine.evaluate("37 878,07"), Decimal(string: "37878.07")!,
                     "37878.07=37878.07 (запятая)")

        // Разделители тысяч через запятую (без пробелов)
        checkEqual(try! engine.evaluate("1,000+2,500"), Decimal(string: "3500")!,
                     "1000+2500=3500 (запятые-тысячные)")

        // Существующие тесты не должны сломаться
        checkEqual(try! engine.evaluate("15+16"), 31,
                     "Регрессия: 15+16=31")
        checkEqual(try! engine.evaluate("1,000,000"), Decimal(string: "1000000")!,
                     "Регрессия: 1,000,000=1000000")
        checkEqual(try! engine.evaluate("3.1415*5"), Decimal(string: "15.7075")!,
                     "Регрессия: 3.1415*5=15.7075")
        checkEqual(try! engine.evaluate("(15+16+17+18)/4"), Decimal(string: "16.5")!,
                     "Регрессия: (15+16+17+18)/4=16.5")
        checkEqual(try! engine.evaluate("100+5%"), 105, "Регрессия: 100+5%=105")
        checkEqual(try! engine.evaluate("100-5%"), 95, "Регрессия: 100-5%=95")

        // Error cases
        do { _ = try engine.evaluate("1/0"); check(false, "Engine: 1/0 should throw") 
            } catch { check(true, "Engine: 1/0 throws") }
        do { _ = try engine.evaluate("15+a"); check(false, "Engine: 15+a should throw") 
            } catch { check(true, "Engine: 15+a throws") }
        do { _ = try engine.evaluate("(15+16"); check(false, "Engine: (15+16 should throw") 
            } catch { check(true, "Engine: (15+16 throws") }
        do { _ = try engine.evaluate("15+16)"); check(false, "Engine: 15+16) should throw") 
            } catch { check(true, "Engine: 15+16) throws") }
        do { _ = try engine.evaluate("NaN"); check(false, "Engine: NaN should throw") 
            } catch { check(true, "Engine: NaN throws") }
        do { _ = try engine.evaluate("Infinity"); check(false, "Engine: Infinity should throw") 
            } catch { check(true, "Engine: Infinity throws") }
        do { _ = try engine.evaluate(""); check(false, "Engine: empty should throw") 
            } catch { check(true, "Engine: empty throws") }
        do { _ = try engine.evaluate("   "); check(false, "Engine: whitespace only should throw") 
            } catch { check(true, "Engine: whitespace only throws") }

        // Main scenario from SRS
        print("\n=== SRS Main Scenario ===")
        let mainResult = try! engine.evaluate("(15+16+17+18)/4")
        checkEqual(mainResult, Decimal(string: "16.5")!, "SRS main scenario: (15+16+17+18)/4 = 16.5")

        // Summary
        print("\n========================================")
        print("Test Results:")
        print("  Total:  \(totalTests)")
        print("  Passed: \(passedTests)")
        print("  Failed: \(failedTests)")
        print("========================================")

        if failedTests > 0 {
            print("\nSOME TESTS FAILED!")
            exit(1)
        } else {
            print("\nALL TESTS PASSED!")
            exit(0)
        }
    }
}

TestRunnerMain.main()
