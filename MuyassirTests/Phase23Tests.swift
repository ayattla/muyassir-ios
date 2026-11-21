import XCTest
@testable import Muyassir

final class Phase23Tests: XCTestCase {
    let text = """
    الخلية هي الوحدة الأساسية في بناء جميع الكائنات الحية. تحتوي الخلية على النواة التي تتحكم في أنشطتها الحيوية.
    يحيط بالخلية غشاء خلوي ينظم دخول المواد وخروجها. تقوم الميتوكوندريا بإنتاج الطاقة اللازمة للخلية.
    تحتوي الخلية النباتية على جدار خلوي وبلاستيدات خضراء تقوم بعملية البناء الضوئي. البناء الضوئي يحول ضوء الشمس إلى طاقة كيميائية.
    الرايبوسومات مسؤولة عن تصنيع البروتينات داخل الخلية. تختلف الخلايا في أشكالها وأحجامها حسب وظائفها في الجسم.
    """

    func testSummaryKeepsOrderAndShrinks() {
        let all = TextAi.sentences(text), s = TextAi.summarize(text)
        XCTAssertTrue((3..<all.count).contains(s.count))
        XCTAssertEqual(s, s.sorted { all.firstIndex(of: $0)! < all.firstIndex(of: $1)! })
    }

    func testQuizHasAnswerAmongOptions() {
        let qs = TextAi.quiz(text, count: 5)
        XCTAssertFalse(qs.isEmpty)
        for q in qs { XCTAssertTrue(q.options.contains(q.answer)); XCTAssertTrue(q.text.contains("……")); XCTAssertEqual(Set(q.options).count, q.options.count) }
    }

    func testBackupRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("bk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try Data("مرحبا".utf8).write(to: dir.appendingPathComponent("list_notes.json"))
        try Data([1, 2, 3]).write(to: dir.appendingPathComponent("sub/x.bin"))
        let enc = try Backup.encrypt(Backup.pack(dir), password: "password123")
        XCTAssertThrowsError(try Backup.decrypt(enc, password: "wrong-pass"))
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("bk-out-\(UUID().uuidString)")
        try Backup.unpack(try Backup.decrypt(enc, password: "password123"), into: out)
        XCTAssertEqual(try String(contentsOf: out.appendingPathComponent("list_notes.json"), encoding: .utf8), "مرحبا")
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("sub/x.bin")), Data([1, 2, 3]))
        XCTAssertThrowsError(try Backup.decrypt(Data("not a backup at all, definitely not".utf8), password: "x"))
    }
}
