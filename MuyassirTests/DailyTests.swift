import XCTest
@testable import Muyassir

/// «يومي»: the same checks as Android's DailyTest, so both apps give identical times and dates.
final class DailyTests: XCTestCase {
    private func at(_ y: Int, _ m: Int, _ d: Int) -> Date { KSA.cal.date(from: DateComponents(year: y, month: m, day: d, hour: 9))! }
    private func day(_ d: Date) -> Int { KSA.cal.component(.day, from: d) }

    func testRiyadhMatchesUmmAlQura() {
        // Published Umm al-Qura times for Riyadh, 19 Nov 2026: Dhuhr 11:40, Maghrib 17:07, Isha 18:37.
        let r = Cities.byId("riyadh")
        let t = PrayerTimes.minutes(2026, 11, 19, lat: r.lat, lng: r.lng)
        XCTAssertLessThanOrEqual(abs(t[2] - (11 * 60 + 40)), 1, "dhuhr \(t[2])")
        XCTAssertLessThanOrEqual(abs(t[4] - (17 * 60 + 7)), 1, "maghrib \(t[4])")
        XCTAssertLessThanOrEqual(abs(t[5] - (18 * 60 + 37)), 1, "isha \(t[5])")
        XCTAssertTrue(t[0] < t[1] && t[1] < t[2] && t[2] < t[3] && t[3] < t[4] && t[4] < t[5])
        let ram = PrayerTimes.minutes(2026, 11, 19, lat: r.lat, lng: r.lng, ramadan: true)
        XCTAssertEqual(120, ram[5] - ram[4])
        // Identical to Android for the same input (the Kotlin engine gives the same numbers).
        XCTAssertEqual(t, PrayerTimes.minutes(2026, 11, 19, lat: 24.7136, lng: 46.6753))
    }

    func testNextPrayerWrapsToTomorrowsFajr() {
        let t = [300, 375, 700, 885, 1027, 1117]
        XCTAssertTrue(PrayerTimes.next(t, nowMin: 1000, tomorrowFajr: 301) == (4, 27))
        XCTAssertTrue(PrayerTimes.next(t, nowMin: 1200, tomorrowFajr: 301) == (0, 1440 - 1200 + 301))
        XCTAssertEqual("6:39", PrayerTimes.clock(1119)); XCTAssertEqual("38 دقيقة", PrayerTimes.left(38)); XCTAssertEqual("1:05", PrayerTimes.left(65))
    }

    func testGovernmentSalaryFollowsTheMinistryTable() {
        // Ministry of Finance 2026: 26 Mar (27 is Friday), 27 Apr, 24 May (holiday), 28 Jun (27 is Saturday), 26 Nov, 27 Dec.
        let d = { (m: Int) in self.day(PayDays.inMonth(PayDays.gov, 2026, m)) }
        XCTAssertEqual([26, 27, 24, 28, 26, 27], [d(3), d(4), d(5), d(6), d(11), d(12)])
    }

    func testCitizenAccountAndCountdown() {
        XCTAssertEqual(11, day(PayDays.inMonth(PayDays.citizen, 2026, 10)))   // 10 Oct 2026 is a Saturday
        XCTAssertEqual(10, day(PayDays.inMonth(PayDays.citizen, 2026, 12)))
        let (d1, c1) = PayDays.next(PayDays.gov, at(2026, 11, 23)); XCTAssertEqual(3, d1); XCTAssertEqual(26, day(c1))
        let (d2, c2) = PayDays.next(PayDays.gov, at(2026, 11, 27)); XCTAssertEqual(12, KSA.cal.component(.month, from: c2)); XCTAssertEqual(30, d2)
        XCTAssertEqual(0, PayDays.next(PayDays.gov, at(2026, 11, 26)).0)
        let (d3, c3) = PayDays.next(PayDays.custom(31), at(2026, 2, 10)); XCTAssertEqual(28, day(c3)); XCTAssertEqual(18, d3)
    }

    func testDailySettingsPersistAndBuildPayRules() {
        let s = Daily.shared
        UserDefaults.standard.removeObject(forKey: "role")
        s.resetForTest()
        XCTAssertFalse(s.setupDone); XCTAssertEqual([PayDays.gov], s.payRules())
        s.setSalary("custom", day: 40); s.setCitizen(true)
        XCTAssertEqual(["custom", "citizen"], s.payRules().map(\.id)); XCTAssertEqual(31, s.payRules()[0].day)
        s.toggleRole("teacher"); s.chooseCity("jeddah"); s.finishSetup()
        s.load()
        XCTAssertTrue(s.setupDone); XCTAssertEqual(["teacher"], s.roles); XCTAssertEqual("jeddah", s.city)
        s.resetForTest()
    }
}
