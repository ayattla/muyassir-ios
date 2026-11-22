import XCTest

/// «مُيسّر بلس»: paywall, free limits and gates through the real UI (debug launch argument `-plus`).
final class PlusFlowTests: XCTestCase {
    var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }

    func launch(_ plus: String, tool: String? = nil, paywall: String? = nil, tab: String? = nil, inputs: String? = nil) {
        app = XCUIApplication()
        var a = ["-plus", plus]
        if let tool { a += ["-tool", tool] }; if let paywall { a += ["-paywall", paywall] }; if let tab { a += ["-tab", tab] }
        app.launchArguments = a
        if let inputs { app.launchEnvironment["MYS_TEST_INPUTS"] = inputs }
        app.launch()
    }
    func waitText(_ s: String, _ t: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let p = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", s, s)
        XCTAssertTrue(app.descendants(matching: .any).matching(p).firstMatch.waitForExistence(timeout: t), "text not shown: \(s)", file: file, line: line)
    }
    func tapAction() {
        let b = app.buttons["action"]
        var n = 0; while !(b.exists && b.isHittable) && n < 10 { app.swipeUp(); n += 1 }
        b.tap()
    }

    func testPaywallShowsPlansTermsRestoreAndCloses() {
        launch("free", paywall: "Menu")
        XCTAssertTrue(app.buttons["plan-yearly"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["plan-monthly"].exists)
        waitText("وفّر"); waitText("استعادة المشتريات"); waitText("ابدأ تجربة مجانية 7 أيام")
        var n = 0; while !app.buttons["شروط الاستخدام"].isHittable && n < 6 { app.swipeUp(); n += 1 }
        XCTAssertTrue(app.buttons["شروط الاستخدام"].exists); XCTAssertTrue(app.buttons["سياسة الخصوصية"].exists)
        app.buttons["paywallClose"].tap()
        XCTAssertTrue(app.buttons["plan-yearly"].waitForNonExistence(timeout: 5))
    }

    func testBeforeLaunchPaywallSaysSoon() {
        launch("off", paywall: "Menu")
        waitText("قريبًا"); waitText("نبّهني عند إطلاق بلس")
        XCTAssertFalse(app.buttons["subscribe"].exists)
    }

    func testDailyLimitOpensPaywall() {
        launch("free-used", tool: "pdf_compress", inputs: "pdf1")
        waitText("انتهت عملياتك المجانية")
        tapAction()
        waitText("استخدمت عملياتك المجانية لليوم")
    }

    func testMoreThanFiveFilesNeedsPlus() {
        launch("free", tool: "img_compress", inputs: "png,png,png,png,png,png")
        tapAction()
        waitText("المعالجة الدفعية")
    }

    func testTemplatesLockedForFree() {
        launch("free", tool: "invoice")
        let t = app.buttons["layout-1"]
        var n = 0; while !(t.exists && t.isHittable) && n < 12 { app.swipeUp(); n += 1 }
        t.tap()
        waitText("القوالب الاحترافية")
    }

    func testSettingsPlusCardOpensPaywall() {
        launch("free", tab: "settings")
        let c = app.buttons["plusCard"]
        XCTAssertTrue(c.waitForExistence(timeout: 10)); c.tap()
        XCTAssertTrue(app.buttons["plan-yearly"].waitForExistence(timeout: 5))
    }

    func testSchoolCodeIsCheckedOnTheServer() {
        launch("off", paywall: "Menu")
        let b = app.buttons["schoolCode"]; XCTAssertTrue(b.waitForExistence(timeout: 10))
        var n = 0; while !b.isHittable && n < 8 { app.swipeUp(); n += 1 }
        b.tap()
        let f = app.textFields["schoolCodeField"]; XCTAssertTrue(f.waitForExistence(timeout: 5)); f.tap(); f.typeText("MSR-AAAA-AAAA")
        app.buttons["redeemCode"].firstMatch.tap()
        let err = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "الكود غير صحيح")).firstMatch
        XCTAssertTrue(err.waitForExistence(timeout: 30), "the server did not reject an unknown code")
    }

    func testSchoolLicenceOpensPlusAndNamesTheSchool() {
        launch("school", paywall: "Menu")
        XCTAssertTrue(app.staticTexts["schoolActive"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["schoolActive"].label.contains("مدارس الاختبار"))
        XCTAssertFalse(app.buttons["schoolCode"].exists)
    }
}
