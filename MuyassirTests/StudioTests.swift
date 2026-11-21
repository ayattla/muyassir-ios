import XCTest
@testable import Muyassir

final class StudioTests: XCTestCase {
    private func line(_ y: CGFloat, _ h: CGFloat, _ ws: [(String, CGFloat)]) -> [Layout.Word] {
        ws.map { t, x in Layout.Word(text: t, left: x - CGFloat(t.count) * 10, top: y, right: x, bottom: y + h) }
    }

    func testHeadingParagraphAndTable() {
        let words = line(0, 40, [("تقرير", 900), ("المبيعات", 820)]) + line(70, 20, [("هذا", 900), ("نص", 860), ("عادي", 830)]) + line(100, 20, [("يكمل", 900), ("الفقرة", 850)])
            + line(160, 20, [("المنتج", 900), ("الكمية", 600), ("السعر", 300)]) + line(190, 20, [("قلم", 900), ("5", 600), ("10", 300)]) + line(220, 20, [("دفتر", 900), ("2", 600), ("15", 300)])
        let r = Layout.analyze(words)
        XCTAssertEqual(r.blocks[0], .heading("تقرير المبيعات"))
        XCTAssertEqual(r.blocks[1], .para("هذا نص عادي يكمل الفقرة"))
        XCTAssertEqual(r.blocks[2], .table([["المنتج", "الكمية", "السعر"], ["قلم", "5", "10"], ["دفتر", "2", "15"]]))
    }

    func testUnsureWordsAndEditedText() {
        let r = Layout.analyze([Layout.Word(text: "واضح", left: 0, top: 0, right: 50, bottom: 20, conf: 95), Layout.Word(text: "غامض", left: 60, top: 0, right: 110, bottom: 20, conf: 30)])
        XCTAssertEqual(r.unsure, ["غامض"])
        let e = Layout.fromText("العنوان\n\nفقرة أولى من النص.\n\nأ | ب\n1 | 2")
        XCTAssertEqual(e.blocks[2], .table([["أ", "ب"], ["1", "2"]]))
    }

    func testExamParser() {
        let qs = ExamParser.parse("١) ما عاصمة المملكة العربية السعودية؟\nأ) جدة\nب) الرياض\nج) الدمام\n2- الشمس كوكب. ( )\n3) اشرح دورة الماء في الطبيعة\n4. ناتج 2 + 2 يساوي: (أ) 3 (ب) 4 (ج) 5")
        XCTAssertEqual(qs.count, 4)
        XCTAssertEqual(qs[0].choices, ["جدة", "الرياض", "الدمام"])
        XCTAssertEqual(qs[1].kind, .trueFalse); XCTAssertEqual(qs[2].kind, .open)
        XCTAssertEqual(qs[3].choices, ["3", "4", "5"]); XCTAssertEqual(qs[3].text, "ناتج 2 + 2 يساوي:")
    }

    func testBankImportAndPairs() {
        let qs = Edu.importRows([
            ["السؤال", "النوع", "أ", "ب", "ج", "د", "الإجابة", "الدرجة", "المادة", "الصف", "الدرس", "الصعوبة"],
            ["عاصمة السعودية؟", "", "جدة", "الرياض", "مكة", "", "ب", "2", "اجتماعيات", "الرابع", "مدن المملكة", "سهل"],
            ["الشمس نجم", "صح وخطأ", "", "", "", "", "صح", "1", "علوم", "الخامس", "", "متوسط"],
            ["الماء يغلي عند ___ درجة", "", "", "", "", "", "100", "1", "علوم", "", "", ""],
        ])
        XCTAssertEqual(qs.count, 3)
        XCTAssertEqual(qs[0]["type"] as? Int, 0); XCTAssertEqual(qs[0]["ans"] as? Int, 1); XCTAssertEqual(qs[0].s("grade"), "الرابع")
        XCTAssertEqual(qs[1]["type"] as? Int, 1); XCTAssertEqual(qs[2]["type"] as? Int, 3); XCTAssertEqual(qs[2].s("answer"), "100")
        XCTAssertEqual(Edu.pairs("الرياض = السعودية\nالقاهرة = مصر\nبلا علامة").map(\.0), ["الرياض", "القاهرة"])
        XCTAssertTrue(Strategies.all.count >= 13)
    }
}
