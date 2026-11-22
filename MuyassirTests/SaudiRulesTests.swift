import XCTest
@testable import Muyassir

/// Hand-worked examples for the Saudi rules (Labor Law arts. 75–77, 84–85, 92; GOSI M/273 schedule).
final class SaudiRulesTests: XCTestCase {
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Riyadh")!; return c.date(from: DateComponents(year: y, month: m, day: day, hour: 12))! }

    func testGosiSchedule() {
        XCTAssertEqual(SaudiRules.newPensionRate(d(2025, 6, 30)), 9); XCTAssertEqual(SaudiRules.newPensionRate(d(2025, 7, 1)), 9.5)
        XCTAssertEqual(SaudiRules.newPensionRate(d(2026, 11, 22)), 10); XCTAssertEqual(SaudiRules.newPensionRate(d(2030, 1, 1)), 11)
    }
    func testServiceSpan() { let s = SaudiRules.service(d(2020, 1, 15), d(2026, 3, 10)); XCTAssertEqual(s.years, 6); XCTAssertEqual(s.months, 1); XCTAssertEqual(s.days, 23) }
    func testNotice() {
        let n = SaudiRules.notice(.open, .employer, monthlyPaid: true, given: 20, wage: 9000)
        XCTAssertEqual(n.requiredDays, 60); XCTAssertEqual(n.missingDays, 40); XCTAssertEqual(n.amount, 12000, accuracy: 0.01)
        XCTAssertEqual(SaudiRules.notice(.fixed, .employer, monthlyPaid: true, given: 0, wage: 9000).amount, 0)
    }
    func testArticle77() {
        XCTAssertEqual(SaudiRules.art77(.open, years: 1, remainingMonths: 0, wage: 10000), 20000, accuracy: 0.01)
        XCTAssertEqual(SaudiRules.art77(.open, years: 10, remainingMonths: 0, wage: 10000), 50000, accuracy: 0.01)
        XCTAssertEqual(SaudiRules.art77(.fixed, years: 3, remainingMonths: 7, wage: 10000), 70000, accuracy: 0.01)
    }
    func testDeductionCap() { XCTAssertEqual(SaudiRules.deduction(wage: 8000, requested: 6000).allowed, 4000) }
    func testSettlementResignation() {
        let l = SaudiRules.settlement(wage: 10000, start: d(2020, 1, 1), end: d(2026, 1, 1), reason: .resignation, contract: .open, unpaidDays: 10, leaveDays: 15, noticeGiven: 30, remainingMonths: 0)
        XCTAssertEqual(l.first { $0.label == "مكافأة نهاية الخدمة" }!.amount, 35000 * 2 / 3, accuracy: 60)
        XCTAssertEqual(l.first { $0.label == "بدل رصيد الإجازة" }!.amount, 5000, accuracy: 0.01)
    }
    func testArticle80AndSources() {
        let l = SaudiRules.settlement(wage: 6000, start: d(2015, 1, 1), end: d(2026, 1, 1), reason: .art80, contract: .open, unpaidDays: 0, leaveDays: 0, noticeGiven: 0, remainingMonths: 0)
        XCTAssertEqual(l.first { $0.label == "مكافأة نهاية الخدمة" }!.amount, 0)
        for r in SaudiRules.rules.values { XCTAssertTrue(r.sourceURL.hasPrefix("https://") && !r.reviewed.isEmpty, r.id) }
        XCTAssertEqual(SaudiRules.Country.allCases.filter(\.enabled), [.sa])
    }
}
