import XCTest
@testable import Muyassir

final class Phase1Tests: XCTestCase {
    func testZakat() {
        let z = Calc.zakat(cash: 100_000, gold: 0, silver: 0, trade: 0, receivables: 0, debts: 0, nisab: 85 * 400)
        XCTAssertTrue(z.reached); XCTAssertEqual(z.due, 2500, accuracy: 0.001)
        XCTAssertEqual(Calc.zakat(cash: 10_000, gold: 0, silver: 0, trade: 0, receivables: 0, debts: 0, nisab: 34_000).due, 0)
    }
    func testOvertimeArticle107() {
        let o = Calc.overtime(basic: 2400, allowances: 1800, dailyHours: 8, hours: 3)
        XCTAssertEqual(o.perHour, 22.5, accuracy: 0.001); XCTAssertEqual(o.total, 67.5, accuracy: 0.001)
    }
    func testElectricity() {
        let p = Calc.electricity(kwh: 7000, rate1: 18, rate2: 30)
        XCTAssertEqual(p.tier1, 1080, accuracy: 0.001); XCTAssertEqual(p.tier2, 300, accuracy: 0.001); XCTAssertEqual(p.total, 1380 * 1.15, accuracy: 0.01)
    }
    func testDateSpan() {
        let cal = Hijri.greg
        let s = Calc.span(cal.date(from: DateComponents(year: 2000, month: 1, day: 31))!, cal.date(from: DateComponents(year: 2026, month: 11, day: 21))!)
        XCTAssertEqual(s.years, 26); XCTAssertEqual(s.months, 9)
    }
    func testDateFinder() {
        XCTAssertEqual(DateFinder.find("تاريخ الإصدار 2021/03/15 تاريخ الانتهاء 15-03-2031").count, 2)
        let e = DateFinder.expiry("Issue 01.02.2020 Expiry ٢٠٣٠/٠٢/٠١")!
        XCTAssertEqual(Hijri.greg.component(.year, from: e.date), 2030)
        XCTAssertTrue(DateFinder.find("الانتهاء 1450/05/10").first?.hijri ?? false)
    }
    func testRecipes() {
        XCTAssertEqual(Recipes.builtIn.count, 6)
        XCTAssertTrue(Recipes.shared.forKinds(["image"]).contains { $0.id == "doc" })
        XCTAssertEqual(Assistant.recipeFor(["img_pdf", "pdf_compress"]), "doc")
        XCTAssertEqual(Tools.all.count, 92)
    }
    func testRecipeRunsOnRealImages() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rt-\(UUID())"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let imgs = try (1...2).map { i in try ImageEngine.save(TestInputs.image(), .png, quality: 1, to: dir.appendingPathComponent("\(i).png")) }
        let out = dir.appendingPathComponent("out"); try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let r = try Recipes.run(Recipes.builtIn[0], imgs, out: out, p: Progress())
        XCTAssertEqual(r.count, 1); XCTAssertEqual(r[0].pathExtension, "pdf")
    }
}
