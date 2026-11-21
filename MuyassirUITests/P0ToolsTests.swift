import XCTest

/// P0: proves the result of every tool that had only a "screen opens" check before.
final class P0ToolsTests: XCTestCase {
    var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

    let lesson = "الخلية هي الوحدة الأساسية في بناء جميع الكائنات الحية. تحتوي الخلية على النواة التي تتحكم في أنشطتها الحيوية. يحيط بالخلية غشاء خلوي ينظم دخول المواد وخروجها. تقوم الميتوكوندريا بإنتاج الطاقة اللازمة للخلية. تحتوي الخلية النباتية على جدار خلوي وبلاستيدات خضراء تقوم بعملية البناء الضوئي. البناء الضوئي يحول ضوء الشمس إلى طاقة كيميائية. الرايبوسومات مسؤولة عن تصنيع البروتينات داخل الخلية."

    func launch(_ tool: String, inputs: String? = nil, reset: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["-tool", tool]
        if let inputs { app.launchEnvironment["MYS_TEST_INPUTS"] = inputs }
        app.launch()
    }
    func reveal(_ e: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        var n = 0
        while !(e.exists && e.isHittable) && n < 14 { app.swipeUp(velocity: .fast); n += 1 }
        XCTAssertTrue(e.exists && e.isHittable, "not reachable: \(e)", file: file, line: line)
    }
    func waitText(_ s: String, _ t: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let p = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", s, s)
        XCTAssertTrue(app.descendants(matching: .any).matching(p).firstMatch.waitForExistence(timeout: t), "text not shown: \(s)", file: file, line: line)
    }
    func field(_ label: String) -> XCUIElement {
        for q in [app.textFields, app.secureTextFields, app.textViews] { let e = q.matching(identifier: label).firstMatch; if e.exists { return e } }
        let p = NSPredicate(format: "label BEGINSWITH %@ OR placeholderValue BEGINSWITH %@", label, label)
        for q in [app.textFields, app.textViews] { let e = q.matching(p).firstMatch; if e.exists { return e } }
        return app.textFields.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
    func type(_ label: String, _ v: String, file: StaticString = #filePath, line: UInt = #line) {
        let f = field(label)
        XCTAssertTrue(f.waitForExistence(timeout: 5), "field missing: \(label)", file: file, line: line)
        reveal(f, file: file, line: line); f.tap()
        if let cur = f.value as? String, !cur.isEmpty, cur != label, cur != "0" { f.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: cur.count)) }
        f.typeText(v); dismissKeyboard()
    }
    func dismissKeyboard() {
        guard app.keyboards.count > 0 else { return }
        let done = app.buttons["تم"].firstMatch
        if done.exists && done.isHittable { done.tap() }
        else { for k in ["Return", "return", "Done", "done"] where app.keyboards.buttons[k].firstMatch.exists { app.keyboards.buttons[k].firstMatch.tap(); break } }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
    }
    func tap(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR identifier == %@", label, label)).firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: 5), "button missing: \(label)", file: file, line: line)
        reveal(b, file: file, line: line); b.tap()
    }
    func waitResults(_ t: TimeInterval = 60, file: StaticString = #filePath, line: UInt = #line) {
        let ok = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'الناتج'")).firstMatch
        XCTAssertTrue(ok.waitForExistence(timeout: t), "no result file", file: file, line: line)
    }
    func addRecord(_ fields: [(String, String)]) {
        app.buttons["إضافة"].firstMatch.tap()
        for (l, v) in fields { type(l, v) }
        app.buttons["حفظ"].firstMatch.tap()
    }

    // MARK: Saudi services and calculators
    func testLeaveBalance() { launch("leave"); type("سنوات الخدمة", "6"); waitText("30 يومًا") }
    func testZakatDue() { launch("zakat"); type("النقد والأرصدة البنكية", "100000"); type("سعر غرام الذهب عيار 24 اليوم", "300"); waitText("2,500.00") }
    func testOvertimePay() { launch("overtime"); type("الراتب الأساسي", "6000"); type("عدد الساعات الإضافية", "10"); waitText("375.00") }
    func testElectricityBill() { launch("electricity"); app.buttons["حتى 31 ديسمبر 2026"].firstMatch.tap(); type("الاستهلاك الشهري", "1000"); waitText("207.00") }
    func testDateSpan() { launch("date_diff"); waitText("إجمالي الأيام"); waitText("هـ") }
    func testGovDirectory() { launch("gov_dir"); waitText("أبشر") }
    func testEmergencyNumbers() { launch("emergency"); waitText("911"); waitText("997") }
    func testDocumentsSave() { launch("documents"); addRecord([("اسم الوثيقة أو الموعد", "جواز سفر اختبار")]); waitText("جواز سفر اختبار") }

    // MARK: productivity
    func testAreaOfRectangle() { launch("area_volume"); type("الطول", "4"); type("العرض", "5"); waitText("20") }
    func testTextCompare() { launch("text_compare"); type("النص الأول", "مرحبا بك في ميسر"); type("النص الثاني", "مرحبا بكم في ميسر"); waitText("نسبة التطابق") }
    func testRemindersSave() { launch("reminders"); addRecord([("التذكير", "تذكير اختبار")]); waitText("تذكير اختبار") }
    func testExpensesTotal() { launch("expenses"); addRecord([("البند", "قهوة"), ("المبلغ", "25")]); waitText("قهوة"); waitText("مصروف هذا الشهر") }
    func testBudgetRemaining() { launch("budget"); type("الدخل الشهري", "5000"); waitText("المتبقي هذا الشهر") }

    // MARK: study and teacher pack
    func testTimetableCell() {
        launch("timetable"); let c = app.buttons["cell-0-0"]; reveal(c); c.tap()
        let f = app.alerts.textFields.firstMatch; XCTAssertTrue(f.waitForExistence(timeout: 5)); f.tap(); f.typeText("رياضيات")
        app.alerts.buttons["حفظ"].tap(); waitText("رياضيات")
    }
    func testExamsSave() { launch("exams"); addRecord([("المادة", "فيزياء")]); waitText("فيزياء") }
    func testHomeworkSave() { launch("homework"); addRecord([("المادة", "لغتي"), ("الواجب", "تمرين 3")]); waitText("تمرين 3") }
    func testFlashcardsReview() { launch("flashcards"); type("الوجه (سؤال أو كلمة)", "عاصمة السعودية"); type("الظهر (الإجابة)", "الرياض"); tap("إضافة البطاقة"); tap("ابدأ المراجعة"); waitText("عاصمة السعودية") }
    func testStudyTimerCounts() { launch("study_timer"); tap("ابدأ"); waitText("24:5", 6) }
    func testQuizMakerPdf() { launch("quiz_maker"); tap("إضافة سؤال"); type("نص السؤال", "كم عدد أيام الأسبوع؟"); type("الخيار أ", "سبعة"); type("الخيار ب", "خمسة"); tap("إنشاء PDF"); waitResults() }
    func testWorksheetPdf() { launch("worksheet"); tap("إنشاء PDF"); waitResults() }
    func testCertificateSingle() { launch("certificate"); type("اسم المكرَّم", "سارة أحمد"); tap("إنشاء الشهادة"); waitResults() }
    func testCertificateBulk() {
        launch("certificate"); let t = app.switches["bulkToggle"]; reveal(t); t.tap()
        type("الأسماء (اسم في كل سطر)", "سارة\nمحمد\nنورة"); tap("إنشاء الشهادات"); waitResults(); waitText("شهادات-")
    }
    func testAttendanceSession() { launch("attendance"); type("اسم الطالب (أو عدة أسماء بفاصلة)", "خالد"); app.buttons["إضافة"].firstMatch.tap(); tap("حفظ الحصة"); waitText("حضور") }
    func testGradesTotals() {
        launch("grades"); type("اسم الطالب أو عدة أسماء بفاصلة", "ريم\(Int.random(in: 100...999))"); app.buttons["addStudent"].tap()
        let item = "اختبار \(Int.random(in: 100...999))"; type("اسم التقييم (اختبار 1، مشاركة…)", item); type("الدرجة العظمى", "50"); tap("addItem")
        let chip = app.buttons[item]; reveal(chip); chip.tap()
        type("من 50", "45"); waitText("45 / 50")
    }
    func testQuizGenerator() { launch("quiz_gen"); type("ملاحظاتك أو درسك", lesson); tap("action"); waitText("سؤالًا", 20) }
    func testSummarizer() { launch("summarize"); type("النص المراد تلخيصه", lesson); tap("action"); waitText("الملخص", 20) }

    // MARK: documents
    func testQuotePdf() { launch("quote"); type("الوصف", "تصميم شعار"); type("الكمية", "1"); type("السعر", "500"); tap("إنشاء عرض السعر"); waitResults() }
    func testLetterPdf() { launch("letter"); type("الموضوع", "طلب إجازة"); type("نص الخطاب", "أرجو الموافقة على إجازتي."); tap("إنشاء الخطاب PDF"); waitResults() }
    func testTextToPdf() { launch("text_pdf"); type("النص", "فقرة عربية للاختبار"); tap("تحويل إلى PDF"); waitResults() }
    func testSignPdf() {
        launch("sign_pdf", inputs: "pdf1")
        let pad = app.otherElements["signPad"]; reveal(pad)
        pad.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).press(forDuration: 0.1, thenDragTo: pad.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        tap("action"); waitResults()
    }
    func testPdfEditAddsText() {
        launch("pdf_edit", inputs: "pdf2"); type("النص", "تمت المراجعة")
        let page = app.descendants(matching: .any)["pagePreview"]; reveal(page); page.tap()
        tap("action"); waitResults()
    }

    // MARK: smart tools
    func testQrReadFromImage() { launch("qr_read", inputs: "qr"); waitText("ayattla.com/muyassir") }

    // MARK: broken and large inputs
    func expectError(_ tool: String, _ input: String, file: StaticString = #filePath, line: UInt = #line) {
        launch(tool, inputs: input); tap("action")
        let err = app.staticTexts["error"]
        let ok = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'الناتج'")).firstMatch
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline && !err.exists && !ok.exists { _ = err.waitForExistence(timeout: 1) }
        XCTAssertTrue(err.exists, "\(tool) gave no clear message for a broken file", file: file, line: line)
    }
    func testBrokenPdfIsRejected() { expectError("pdf_word", "bad-pdf") }
    func testBrokenWordIsRejected() { expectError("word_pdf", "bad-docx") }
    func testBrokenExcelIsRejected() { expectError("excel_pdf", "bad-xlsx") }
    func testBrokenZipIsRejected() { expectError("unzip", "bad-zip") }
    func testBrokenImageIsRejected() { expectError("img_compress", "bad-png") }
    func testLargePdfMergeAndCompress() {
        let t0 = Date(); launch("pdf_merge", inputs: "pdf60,pdf2"); tap("action"); waitResults(180)
        let merge = Date().timeIntervalSince(t0)
        let t1 = Date(); launch("pdf_compress", inputs: "pdf60"); tap("action"); waitResults(300)
        print("MuyassirTiming merge 62 pages: \(Int(merge * 1000)) ms, compress 60 pages: \(Int(Date().timeIntervalSince(t1) * 1000)) ms")
    }
}
