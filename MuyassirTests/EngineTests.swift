import XCTest
import PDFKit
@testable import Muyassir

final class CalcTests: XCTestCase {
    func near(_ e: Double, _ a: Double, _ d: Double = 0.01, file: StaticString = #filePath, line: UInt = #line) { XCTAssertEqual(e, a, accuracy: d, file: file, line: line) }

    func testVat() {
        near(115, Calc.vat(100, inclusive: false).total); near(100, Calc.vat(115, inclusive: true).net); near(15, Calc.vat(115, inclusive: true).vat)
    }
    func testGosi() {
        let g = Calc.gosi(basic: 8000, housing: 2000, saudi: true); near(975, g.employee); near(1175, g.employer)
        near(45000 * 0.0975, Calc.gosi(basic: 60000, housing: 10000, saudi: true).employee)
        near(0, Calc.gosi(basic: 5000, housing: 0, saudi: false).employee); near(100, Calc.gosi(basic: 5000, housing: 0, saudi: false).employer)
        near(10000 * 0.1025, Calc.gosi(basic: 10000, housing: 0, saudi: true, system: .new, newPension: 9.5).employee)
    }
    func testEndOfService() {
        near(75000, Calc.endOfService(wage: 10000, years: 10, months: 0, days: 0, how: .termination).payable)
        near(5000, Calc.endOfService(wage: 10000, years: 3, months: 0, days: 0, how: .resignation).payable)
        near(0, Calc.endOfService(wage: 10000, years: 1, months: 11, days: 0, how: .resignation).payable)
        near(30000, Calc.endOfService(wage: 10000, years: 7, months: 0, days: 0, how: .resignation).payable)
    }
    func testLeave() {
        XCTAssertEqual(21, Calc.leave(serviceYears: 2, monthsThisYear: 12, usedDays: 0, wage: 0).entitlement)
        let l = Calc.leave(serviceYears: 6, monthsThisYear: 6, usedDays: 5, wage: 0); XCTAssertEqual(30, l.entitlement); near(10, l.remaining)
    }
    func testLoans() {
        let f = Calc.flatLoan(100000, annualFlat: 3, months: 60); near(15000, f.profit); near(1916.67, f.monthly); XCTAssert(f.apr > 5.5 && f.apr < 5.8)
        near(1887.12, Calc.reducingLoan(100000, annualRate: 5, months: 60).monthly)
    }
    func testDiscountAndGpa() {
        near(28, Calc.discount(100, [20, 10]).effectivePct)
        let g = Calc.gpa([Calc.Course(points: 5, hours: 3), Calc.Course(points: 4, hours: 3)], prevGpa: 4, prevHours: 30)
        near(4.5, g.0); near((4.5 * 6 + 4 * 30) / 36, g.1)
        near(4.75, Calc.points("A", scale5: true))
    }
    func testExpressions() throws {
        near(14, try Expr.eval("2+3*4")); near(20, try Expr.eval("(2+3)*4")); near(1, try Expr.eval("sin(90)")); near(120, try Expr.eval("5!"))
        near(512, try Expr.eval("2^3^2")); near(-4, try Expr.eval("-2^2")); near(0.5, try Expr.eval("2^-1")); near(0.5, try Expr.eval("50%")); near(3, try Expr.eval("√(9)"))
        XCTAssertThrowsError(try Expr.eval("2+"))
    }
    func testUnits() {
        let len = Units.kinds.first { $0.name == "الطول" }!
        near(1000, Units.convert(len, 1, from: len.units.first { $0.name == "كيلومتر" }!, to: len.units.first { $0.name == "متر" }!))
        let t = Units.kinds.first { $0.name == "الحرارة" }!; near(212, Units.convert(t, 100, from: t.units[0], to: t.units[1]))
    }
    func testTextTools() {
        XCTAssertEqual(4, TextTools.count("مرحبا بك في مُيسّر").words)
        XCTAssertEqual(1, TextTools.dedupe("أ\nب\nأ", ignoreCase: true, trim: true, keepBlank: false).1)
        XCTAssertEqual([.same, .removed, .added, .same], TextTools.diff("a b c", "a x c", byWord: true).map { $0.op })
    }
    func testHijri() {
        let h = Hijri.toHijri(2026, 11, 20)!; XCTAssertEqual(1448, h.y)
        let g = Hijri.toGregorian(h.y, h.m, h.d)!; XCTAssertEqual([2026, 11, 20], [g.y, g.m, g.d])
    }
}

final class FileEngineTests: XCTestCase {
    var dir: URL!
    override func setUpWithError() throws { dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func testOfficeRoundTrip() throws {
        let docx = dir.appendingPathComponent("t.docx")
        try Office.writeDocx(docx, [.text("عنوان", heading: 1), .text("سطر عربي & <رمز>"), .table([["أ", "ب"]])])
        let p = try Office.readDocx(docx); XCTAssertEqual("عنوان", p[0]); XCTAssertEqual("سطر عربي & <رمز>", p[1]); XCTAssertEqual("أ\tب", p[2])
        let xlsx = dir.appendingPathComponent("t.xlsx")
        try Office.writeXlsx(xlsx, [("ورقة", [["الاسم", "المبلغ"], ["سارة", "120.5"], ["خالد", "007"]])])
        let s = try Office.readXlsx(xlsx); XCTAssertEqual("ورقة", s[0].0); XCTAssertEqual(["سارة", "120.5"], s[0].1[1]); XCTAssertEqual("007", s[0].1[2][1])
        let pptx = dir.appendingPathComponent("t.pptx")
        try Office.writePptx(pptx, [Office.Slide(title: "الشريحة الأولى", body: "نقطة 1\nنقطة 2"), Office.Slide(title: "الثانية")])
        let sl = try Office.readPptx(pptx); XCTAssertEqual(2, sl.count); XCTAssert(sl[0].contains("نقطة 2"))
    }
    func testZip() throws {
        let u = dir.appendingPathComponent("a.zip"); let big = Data(repeating: 65, count: 100_000)
        try Zip.write([("ملف.txt", Data("مرحبا".utf8)), ("big.bin", big)], to: u)
        let e = try Zip.read(u); XCTAssertEqual("ملف.txt", e[0].0); XCTAssertEqual("مرحبا", String(data: e[0].1, encoding: .utf8)); XCTAssertEqual(big, e[1].1)
        XCTAssertLessThan(FilesX.size(u), 5000)
        XCTAssertEqual(0xCBF43926, Zip.crc32(Data("123456789".utf8)))
    }
    func makePdf(_ pages: Int) throws -> URL {
        let b = DocBuilder(); for i in 1...pages { b.add(.title("صفحة \(i)")); if i < pages { b.add(.pageBreak) } }
        return try b.save(to: dir.appendingPathComponent("p\(pages)-\(UUID().uuidString).pdf"))
    }
    func testPdfOps() throws {
        let a = try makePdf(3), b = try makePdf(2)
        XCTAssertEqual(3, try PdfEngine.open(a).pageCount)
        XCTAssertEqual([0, 2, 1], PdfEngine.parseRanges("1,3,2", count: 3)); XCTAssertEqual([1, 2], PdfEngine.parseRanges("2-3", count: 3))
        XCTAssertEqual(5, try PdfEngine.merge([a, b]).pageCount)
        XCTAssertEqual(2, PdfEngine.select(try PdfEngine.open(a), [0, 2]).pageCount)
        let locked = try PdfEngine.protect(a, password: "1234", to: dir.appendingPathComponent("l.pdf"))
        XCTAssert(PDFDocument(url: locked)!.isLocked)
        XCTAssertThrowsError(try PdfEngine.unlock(locked, password: "0000", to: dir.appendingPathComponent("x.pdf")))
        let open = try PdfEngine.unlock(locked, password: "1234", to: dir.appendingPathComponent("u.pdf")); XCTAssertFalse(PDFDocument(url: open)!.isLocked)
        let img = PdfEngine.render(try PdfEngine.open(a).page(at: 0)!, dpi: 72); XCTAssertGreaterThan(img.size.width, 100)
        XCTAssertEqual(2, PDFDocument(url: try PdfEngine.fromImages([img, img], a4: true, to: dir.appendingPathComponent("i.pdf")))!.pageCount)
        let stamped = try PdfEngine.stamp(a, page: 2, image: img, rx: 0.5, ry: 0.5, rw: 0.3, to: dir.appendingPathComponent("s.pdf")); XCTAssertEqual(3, PDFDocument(url: stamped)!.pageCount)
        XCTAssert((PDFDocument(url: a)!.string ?? "").contains("صفحة"))
    }
    func testImagesAndQr() throws {
        let q = ImageEngine.qr("https://example.com/مُيسّر")
        XCTAssertEqual(["https://example.com/مُيسّر"], try ImageEngine.readCodes(q))
        let big = ImageEngine.resize(q, w: 400, h: 400, keep: true); XCTAssertEqual(400, big.size.width, accuracy: 1)
        XCTAssertEqual(400, ImageEngine.rotate(ImageEngine.resize(q, w: 400, h: 200, keep: false), degrees: 90).size.height, accuracy: 1)
        let j = try ImageEngine.compressToSize(ImageEngine.autoEnhance(big), kb: 30, to: dir.appendingPathComponent("c.jpg")); XCTAssertLessThan(FilesX.size(j), 31 * 1024)
    }
}
