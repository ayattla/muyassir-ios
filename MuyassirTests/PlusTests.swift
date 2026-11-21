import XCTest
@testable import Muyassir

/// The free / Plus rules from the monetization plan.
@MainActor
final class PlusTests: XCTestCase {
    let mb: Int64 = 1024 * 1024
    let plus = Plus.shared
    override func tearDown() async throws { await MainActor.run { plus.testState("off"); plus.paywall = nil } }

    func testBeforeLaunchEverythingIsOpen() {
        plus.testState("off")
        XCTAssertTrue(plus.unlocked)
        XCTAssertNil(plus.check("pdf_merge", sizes: Array(repeating: 300 * mb, count: 60)))
        for _ in 0..<20 { plus.counted("pdf_merge") }
        XCTAssertNil(plus.check("pdf_merge", sizes: [mb]))
        XCTAssertEqual(plus.ocrPages, .max)
    }

    func testFreeLimits() {
        plus.testState("free")
        XCTAssertFalse(plus.unlocked)
        XCTAssertNil(plus.check("pdf_merge", sizes: Array(repeating: 20 * mb, count: 5)))
        XCTAssertEqual(plus.check("pdf_merge", sizes: Array(repeating: mb, count: 6)), .files)
        XCTAssertEqual(plus.check("img_compress", sizes: [21 * mb]), .size)
        XCTAssertEqual(plus.ocrPages, 3)
        XCTAssertEqual(Templates.current, 0)
    }

    func testFiveOperationsPerDay() {
        plus.testState("free")
        for _ in 0..<Plus.freeOpsPerDay { XCTAssertNil(plus.check("pdf_compress", sizes: [mb])); plus.counted("pdf_compress") }
        XCTAssertEqual(plus.check("pdf_compress", sizes: [mb]), .daily)
        XCTAssertEqual(plus.opsLeft, 0)
    }

    func testUnmeteredToolsAreAlwaysFree() {
        plus.testState("free-used")
        for id in ["vat", "salary", "gpa", "notes", "qr_make", "cv", "invoice", "scientific"] {
            XCTAssertNil(plus.check(id, sizes: [900 * mb])); XCTAssertFalse(Plus.metered.contains(id))
        }
    }

    func testPlusLimits() {
        plus.testState("plus")
        XCTAssertTrue(plus.unlocked)
        for _ in 0..<50 { plus.counted("pdf_merge") }
        XCTAssertNil(plus.check("pdf_merge", sizes: Array(repeating: 400 * mb, count: 100)))
        XCTAssertEqual(plus.check("pdf_merge", sizes: Array(repeating: mb, count: 101)), .files)
        XCTAssertEqual(plus.check("pdf_merge", sizes: [501 * mb]), .size)
    }

    func testGatesAndFooter() {
        plus.testState("free")
        XCTAssertFalse(plus.allow(.template)); XCTAssertEqual(plus.paywall, .template)
        XCTAssertEqual(Templates.apply(DocBuilder()).footer, Plus.footer)
        plus.paywall = nil; plus.testState("plus")
        XCTAssertTrue(plus.allow(.template)); XCTAssertNil(plus.paywall)
        XCTAssertNil(Templates.apply(DocBuilder()).footer)
    }

    func testEveryTemplateRendersAPdf() throws {
        plus.testState("plus")
        XCTAssertEqual(Templates.count, 24)
        let dir = FileManager.default.temporaryDirectory
        for i in 0..<Templates.count {
            Templates.selected = i
            let b = Templates.apply(DocBuilder())
            b.add([.title("فاتورة", sub: "منشأة تجريبية"), .heading("البنود"), .table(header: ["#", "الوصف"], rows: [["1", "خدمة"]])])
            let u = try b.save(to: dir.appendingPathComponent("t\(i).pdf"))
            XCTAssertGreaterThan((try FileManager.default.attributesOfItem(atPath: u.path)[.size] as? Int) ?? 0, 500)
        }
        Templates.selected = 0
    }
}
