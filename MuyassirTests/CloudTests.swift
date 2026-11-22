import XCTest
@testable import Muyassir

final class CloudTests: XCTestCase {
    func testMapsEveryAutoGradedType() {
        let qs: [Rec] = [
            ["type": 0, "q": "كم عدد أيام الأسبوع؟", "opts": ["خمسة", "سبعة", "", ""], "ans": 1, "mark": "2"],
            ["type": 1, "q": "الشمس نجم", "ans": 0],
            ["type": 2, "q": "اشرح دورة الماء"],
            ["type": 3, "q": "يغلي الماء عند ___ درجة", "answer": "100"],
            ["type": 4, "q": "", "pairs": "الرياض = السعودية\nالقاهرة = مصر"],
            ["type": 0, "q": "ناقص", "opts": ["واحد", "", "", ""], "ans": 0],
        ]
        let m = Cloud.toActivity(title: "اختبار", qs: qs, minutes: 15, days: 3)
        let a = m.activity["questions"] as! [Rec]
        XCTAssertEqual(a.count, 4); XCTAssertEqual(m.skipped, 2)
        XCTAssertEqual(a[0].s("type"), "choice"); XCTAssertEqual(a[0].s("answer"), "سبعة"); XCTAssertEqual(a[0]["mark"] as? Double, 2)
        XCTAssertEqual(a[1].s("answer"), "صح")
        XCTAssertEqual(a[2].s("text"), "يغلي الماء عند ...... درجة")
        XCTAssertEqual(a[3].s("type"), "sort"); XCTAssertEqual(a[3]["answer"] as? [String], ["السعودية", "مصر"])
        XCTAssertTrue(a[3].s("text").contains("1) الرياض"))
        XCTAssertEqual(m.activity["minutes"] as? Int, 15); XCTAssertEqual(m.activity["closes_in_days"] as? Int, 3)
    }
}
