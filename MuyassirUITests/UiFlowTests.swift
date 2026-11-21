import XCTest

/// Drives the real app: every category and tool screen, back navigation, calculators, records,
/// and every file tool run end-to-end on real sample files (MYS_TEST_INPUTS, debug builds only).
final class UiFlowTests: XCTestCase {
    var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

    func launch(tool: String? = nil, inputs: String? = nil) {
        app = XCUIApplication()
        if let tool { app.launchArguments = ["-tool", tool] }
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
        let e = app.descendants(matching: .any).matching(p).firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: t), "text not shown: \(s)", file: file, line: line)
    }
    func field(_ label: String) -> XCUIElement {
        for q in [app.textFields, app.secureTextFields, app.textViews] { let e = q.matching(identifier: label).firstMatch; if e.exists { return e } }
        return app.textFields.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
    func type(_ label: String, _ v: String, file: StaticString = #filePath, line: UInt = #line) {
        let f = field(label)
        XCTAssertTrue(f.waitForExistence(timeout: 5), "field missing: \(label)", file: file, line: line)
        reveal(f, file: file, line: line); f.tap()
        if let cur = f.value as? String, !cur.isEmpty, cur != label, cur != "0" { f.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: cur.count)) }
        f.typeText(v)
        dismissKeyboard()
    }
    /// Closes the keyboard (toolbar "تم" button, else the return key) so buttons below are reachable.
    func dismissKeyboard() {
        guard app.keyboards.count > 0 else { return }
        let done = app.buttons["تم"].firstMatch
        if done.exists && done.isHittable { done.tap() }
        else { for k in ["Return", "return", "Done", "done"] where app.keyboards.buttons[k].firstMatch.exists { app.keyboards.buttons[k].firstMatch.tap(); break } }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
    }
    func back() { app.navigationBars.buttons.element(boundBy: 0).tap() }

    // MARK: navigation
    func testEveryCategoryShowsItsToolsAndEveryToolOpens() {
        launch()
        var problems: [String] = []
        for c in Tools.categories {
            let card = app.buttons["cat-\(c.id)"]
            while !card.isHittable { app.swipeUp() }
            card.tap()
            XCTAssertTrue(app.navigationBars[c.title].waitForExistence(timeout: 5), "category \(c.id) did not open")
            let tools = Tools.inCat(c.id)
            if tools.isEmpty { problems.append("\(c.id) empty") }
            for t in tools {
                let row = app.buttons["tool-\(t.id)"]
                var n = 0; while !(row.exists && row.isHittable) && n < 12 { app.swipeUp(); n += 1 }
                guard row.exists else { problems.append("\(c.id)/\(t.id): not listed"); continue }
                row.tap()
                if !app.navigationBars[t.title].waitForExistence(timeout: 5) { problems.append("\(t.id): screen did not open") }
                else if !app.buttons["إضافة إلى المفضلة"].exists && !app.buttons["إزالة من المفضلة"].exists { problems.append("\(t.id): no tool toolbar") }
                back()
                if !app.navigationBars[c.title].waitForExistence(timeout: 5) { problems.append("\(t.id): back failed") }
                while !app.buttons["tool-\(tools[0].id)"].isHittable && app.buttons["tool-\(tools[0].id)"].exists { app.swipeDown() }
            }
            back()
            while !app.buttons["cat-\(Tools.categories[0].id)"].isHittable { app.swipeDown() }
        }
        XCTAssert(problems.isEmpty, problems.joined(separator: "\n"))
    }

    func testSearchFindsToolByPurpose() {
        launch()
        app.tabBars.buttons["البحث"].tap()
        let s = app.searchFields.firstMatch; XCTAssertTrue(s.waitForExistence(timeout: 5)); s.tap(); s.typeText("تصغير ملف")
        waitText("ضغط PDF"); waitText("ضغط الصور")
        let r = app.buttons["result-pdf_compress"]; XCTAssertTrue(r.waitForExistence(timeout: 5)); r.tap()
        XCTAssertTrue(app.navigationBars["ضغط PDF"].waitForExistence(timeout: 5))
    }

    func testAssistantSuggestsStepsInOrder() {
        launch()
        app.tabBars.buttons["المساعد"].tap()
        type("طلبك", "أريد تحويل خمس صور إلى PDF وتقليل حجمه")
        app.buttons["اقترح الأدوات"].firstMatch.tap()
        waitText("صور إلى PDF"); waitText("ضغط PDF")
    }

    func testTabsAndDarkMode() {
        launch()
        app.tabBars.buttons["نشاطي"].tap(); XCTAssertTrue(app.navigationBars["نشاطي"].waitForExistence(timeout: 5))
        app.tabBars.buttons["الإعدادات"].tap(); XCTAssertTrue(app.navigationBars["الإعدادات"].waitForExistence(timeout: 5))
        app.buttons["داكن"].firstMatch.tap(); app.buttons["فاتح"].firstMatch.tap()
        app.tabBars.buttons["الرئيسية"].tap(); XCTAssertTrue(app.buttons["home-search"].waitForExistence(timeout: 5))
    }

    // MARK: calculators
    func testVat() { launch(tool: "vat"); type("المبلغ قبل الضريبة", "100"); waitText("115.00") }
    func testSalary() { launch(tool: "salary"); type("الراتب الأساسي", "8000"); type("بدل السكن", "2000"); waitText("975") }
    func testEndOfService() { launch(tool: "eos"); type("آخر أجر شهري (الأساسي + البدلات الثابتة)", "10000"); type("سنوات", "10"); waitText("75,000") }
    func testDiscount() { launch(tool: "discount"); type("السعر الأصلي", "200"); type("نسبة الخصم", "10"); waitText("180") }
    func testFinance() { launch(tool: "finance"); type("مبلغ التمويل أو سعر السلعة", "100000"); waitText("القسط الشهري") }
    func testPercent() { launch(tool: "percent"); type("درجتك", "45"); type("الدرجة الكاملة", "50"); waitText("90%") }
    func testUnits() { launch(tool: "units"); type("القيمة", "3"); waitText("3,000") }
    func testScientific() {
        launch(tool: "scientific")
        for k in ["2", "+", "3", "×", "4", "="] { app.buttons[k].firstMatch.tap() }
        waitText("14")
    }
    func testWordCount() { launch(tool: "word_count"); type("الصق النص هنا", "مرحبا بك في ميسر"); waitText("4") }
    func testQrMake() { launch(tool: "qr_make"); type("النص أو الرابط", "https://example.com"); let b = app.buttons["حفظ صورة PNG"]; reveal(b); b.tap(); waitText("الناتج") }
    func testNotesPersist() {
        launch(tool: "notes"); app.buttons["إضافة"].firstMatch.tap(); type("العنوان", "ملاحظة اختبار"); app.buttons["حفظ"].firstMatch.tap(); waitText("ملاحظة اختبار")
        app.terminate(); launch(tool: "notes"); waitText("ملاحظة اختبار")
    }

    // MARK: file tools on real files
    func run(_ id: String, _ inputs: String, timeout: TimeInterval = 60, fill: () -> Void = {}) {
        launch(tool: id, inputs: inputs)
        fill()
        let a = app.buttons["action"]; reveal(a); a.tap()
        let ok = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'الناتج'")).firstMatch
        let err = app.staticTexts["error"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline && !ok.exists && !err.exists { _ = ok.waitForExistence(timeout: 1) }
        if err.exists { XCTFail("\(id) failed: \(err.label)") }
        XCTAssertTrue(ok.exists, "\(id): no result")
    }
    // MARK: failure handling
    func testUnsupportedFileShowsClearError() {
        launch(tool: "pdf_merge", inputs: "png")
        let a = app.buttons["action"]; reveal(a); a.tap()
        XCTAssertTrue(app.staticTexts["error"].waitForExistence(timeout: 30), "a PNG given to PDF merge must show an error")
        XCTAssertTrue(app.buttons["action"].exists, "the user can retry")
    }
    func testCurrencyOfflinePeggedRate() { launch(tool: "currency"); waitText("3.75") }

    func testPdfToWord() { run("pdf_word", "pdf2") }
    func testWordToPdf() { run("word_pdf", "docx") }
    func testPdfToExcel() { run("pdf_excel", "pdf1") }
    func testExcelToPdf() { run("excel_pdf", "xlsx") }
    func testPdfToPpt() { run("pdf_ppt", "pdf2") }
    func testPptToPdf() { run("ppt_pdf", "pptx") }
    func testPdfToImages() { run("pdf_img", "pdf2") }
    func testImagesToPdf() { run("img_pdf", "png,png") }
    func testPdfMerge() { run("pdf_merge", "pdf2,pdf1") }
    func testPdfSplit() { run("pdf_split", "pdf3") }
    func testPdfCompress() { run("pdf_compress", "pdf2") }
    func testPdfReorder() { run("pdf_reorder", "pdf3") { type("الترتيب الجديد مثل: 3, 1, 2, 4-10", "3, 1, 2") } }
    func testPdfDelete() { run("pdf_delete", "pdf3") { type("الصفحات المطلوب حذفها مثل: 2, 5-7", "2") } }
    func testPdfExtract() { run("pdf_extract", "pdf3") { type("الصفحات المطلوبة مثل: 1, 4-6", "1, 3") } }
    func testPdfRotate() { run("pdf_rotate", "pdf2") }
    func testPdfProtect() { run("pdf_protect", "pdf1") { type("كلمة المرور", "1234"); type("تأكيد كلمة المرور", "1234") } }
    func testPdfUnlock() { run("pdf_unlock", "locked") { type("كلمة مرور الملف", "1234") } }
    func testOcr() { run("ocr", "png", timeout: 120) }
    func testZip() { run("zip", "pdf1,png") }
    func testUnzip() { run("unzip", "zip") }
    func testImgConvert() { run("img_convert", "png") }
    func testImgCompress() { run("img_compress", "png") }
    func testImgResize() { run("img_resize", "png") }
    func testImgCrop() { run("img_crop", "png") }
    func testImgRotate() { run("img_rotate", "png") }
    func testImgEnhance() { run("img_enhance", "png") }
    func testImgBatch() { run("img_batch", "png,png,png") }
    func testIdPhoto() { run("id_photo", "person") }
    func testImgBackground() throws {
        #if targetEnvironment(simulator)
        // Apple's subject-lifting and person-segmentation models need a real device (Neural Engine); in the Simulator
        // Vision returns no subject. The tool screen itself is covered by the navigation test.
        throw XCTSkip("Vision subject lifting is not available in the iOS Simulator")
        #else
        run("img_bg", "person", timeout: 120)
        #endif
    }
}
