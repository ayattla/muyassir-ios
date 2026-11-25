import Foundation

/// Saudi cities for prayer times, offline (no location permission needed). Same list as Android.
enum Cities {
    struct City: Identifiable, Hashable { let id: String; let name: String; let lat: Double; let lng: Double }
    static let all: [City] = [
        City(id: "riyadh", name: "الرياض", lat: 24.7136, lng: 46.6753), City(id: "jeddah", name: "جدة", lat: 21.4858, lng: 39.1925),
        City(id: "makkah", name: "مكة المكرمة", lat: 21.4225, lng: 39.8262), City(id: "madinah", name: "المدينة المنورة", lat: 24.4686, lng: 39.6142),
        City(id: "dammam", name: "الدمام", lat: 26.4207, lng: 50.0888), City(id: "khobar", name: "الخبر", lat: 26.2172, lng: 50.1971),
        City(id: "dhahran", name: "الظهران", lat: 26.2361, lng: 50.0393), City(id: "qatif", name: "القطيف", lat: 26.5196, lng: 50.0115),
        City(id: "jubail", name: "الجبيل", lat: 27.0046, lng: 49.6460), City(id: "ahsa", name: "الأحساء", lat: 25.3833, lng: 49.5864),
        City(id: "taif", name: "الطائف", lat: 21.2703, lng: 40.4158), City(id: "buraidah", name: "بريدة", lat: 26.3592, lng: 43.9818),
        City(id: "unaizah", name: "عنيزة", lat: 26.0843, lng: 43.9935), City(id: "hail", name: "حائل", lat: 27.5114, lng: 41.7208),
        City(id: "tabuk", name: "تبوك", lat: 28.3835, lng: 36.5662), City(id: "abha", name: "أبها", lat: 18.2164, lng: 42.5053),
        City(id: "khamis", name: "خميس مشيط", lat: 18.3000, lng: 42.7333), City(id: "jazan", name: "جازان", lat: 16.8892, lng: 42.5511),
        City(id: "najran", name: "نجران", lat: 17.5656, lng: 44.2289), City(id: "baha", name: "الباحة", lat: 20.0129, lng: 41.4677),
        City(id: "yanbu", name: "ينبع", lat: 24.0895, lng: 38.0618), City(id: "arar", name: "عرعر", lat: 30.9753, lng: 41.0381),
        City(id: "sakaka", name: "سكاكا", lat: 29.9697, lng: 40.2064), City(id: "kharj", name: "الخرج", lat: 24.1556, lng: 47.3120),
        City(id: "hafar", name: "حفر الباطن", lat: 28.4328, lng: 45.9708), City(id: "qurayyat", name: "القريات", lat: 31.3318, lng: 37.3428),
        City(id: "bisha", name: "بيشة", lat: 20.0005, lng: 42.6052), City(id: "majmaah", name: "المجمعة", lat: 25.9039, lng: 45.3456),
        City(id: "dawadmi", name: "الدوادمي", lat: 24.5077, lng: 44.3924), City(id: "rabigh", name: "رابغ", lat: 22.7986, lng: 39.0349),
    ]
    static func byId(_ id: String) -> City { all.first { $0.id == id } ?? all[0] }
}

/// Riyadh-time calendar shared by «يومي».
enum KSA {
    static var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Riyadh")!; return c }
    static func ymd(_ d: Date) -> (Int, Int, Int) { let c = cal.dateComponents([.year, .month, .day], from: d); return (c.year!, c.month!, c.day!) }
    static func minuteOfDay(_ d: Date) -> Int { let c = cal.dateComponents([.hour, .minute], from: d); return c.hour! * 60 + c.minute! }
    static func hour(_ d: Date) -> Int { cal.component(.hour, from: d) }
    static func weekday(_ d: Date) -> Int { cal.component(.weekday, from: d) }   // 1 = Sunday … 7 = Saturday
}

/// Prayer times by the Umm al-Qura method used in Saudi Arabia: Fajr at 18.5°, Isha 90 minutes after Maghrib
/// (120 in Ramadan), Asr at one shadow length, with the calendar's 2-minute precaution on Maghrib. Accurate to ±2 minutes.
enum PrayerTimes {
    static let names = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
    private static func pmod(_ a: Double, _ b: Double) -> Double { let r = a.truncatingRemainder(dividingBy: b); return r < 0 ? r + b : r }

    /// Minutes after local midnight for [fajr, sunrise, dhuhr, asr, maghrib, isha].
    static func minutes(_ y: Int, _ m: Int, _ d: Int, lat: Double, lng: Double, tz: Double = 3, ramadan: Bool = false) -> [Int] {
        let (y2, m2) = m <= 2 ? (y - 1, m + 12) : (y, m)
        let a = y2 / 100, b = 2 - a + a / 4
        let jd = Double(Int(365.25 * Double(y2 + 4716))) + Double(Int(30.6001 * Double(m2 + 1))) + Double(d + b) - 1524.5 - lng / 360
        let n = jd - 2451545.0
        let g = pmod(357.529 + 0.98560028 * n, 360), q = pmod(280.459 + 0.98564736 * n, 360)
        let l = pmod(q + 1.915 * sin(rad(g)) + 0.020 * sin(rad(2 * g)), 360)
        let e = 23.439 - 0.00000036 * n
        let ra = pmod(deg(atan2(cos(rad(e)) * sin(rad(l)), cos(rad(l)))) / 15, 24)
        let decl = deg(asin(sin(rad(e)) * sin(rad(l))))
        let eqt = pmod(q / 15 - ra + 12, 24) - 12
        let noon = 12 + tz - lng / 15 - eqt
        func span(_ angle: Double) -> Double {
            let x = (-sin(rad(angle)) - sin(rad(lat)) * sin(rad(decl))) / (cos(rad(lat)) * cos(rad(decl)))
            return deg(acos(min(max(x, -1), 1))) / 15
        }
        let asrAngle = -deg(atan(1 / (1 + tan(rad(abs(lat - decl))))))
        let maghrib = noon + span(0.833) + 2.0 / 60
        let hours = [noon - span(18.5), noon - span(0.833), noon + 1.0 / 60, noon + span(asrAngle), maghrib, maghrib + (ramadan ? 2.0 : 1.5)]
        return hours.map { Int(($0 * 60).rounded()) }
    }

    static func today(_ city: Cities.City, _ now: Date = Date()) -> [Int] {
        let (y, m, d) = KSA.ymd(now)
        var u = Calendar(identifier: .islamicUmmAlQura); u.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let ramadan = KSA.cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12)).map { u.component(.month, from: $0) == 9 } ?? false
        return minutes(y, m, d, lat: city.lat, lng: city.lng, ramadan: ramadan)
    }

    /// The next of the five prayers (sunrise skipped): index into `names` and minutes left. After Isha, tomorrow's Fajr.
    static func next(_ times: [Int], nowMin: Int, tomorrowFajr: Int) -> (Int, Int) {
        for i in [0, 2, 3, 4, 5] where times[i] > nowMin { return (i, times[i] - nowMin) }
        return (0, 24 * 60 - nowMin + tomorrowFajr)
    }

    static func clock(_ min: Int) -> String { let h = (min / 60) % 24; return "\(h % 12 == 0 ? 12 : h % 12):\(String(format: "%02d", min % 60))" }
    static func left(_ min: Int) -> String { min < 60 ? "\(min) دقيقة" : "\(min / 60):\(String(format: "%02d", min % 60))" }
}

/// Official monthly payment days (Gregorian), with the published weekend rules.
enum PayDays {
    struct Rule: Equatable { let id: String; let title: String; let day: Int; let friday: Int; let saturday: Int; let source: String }
    // Government salaries: day 27; Friday → Thursday before, Saturday → Sunday after (Ministry of Finance).
    // Citizen Account: day 10; Friday → 9, Saturday → 11. Social security and pensions: day 1, same weekend rule.
    static let gov = Rule(id: "gov", title: "راتب الدولة", day: 27, friday: -1, saturday: 1, source: "وزارة المالية")
    static let citizen = Rule(id: "citizen", title: "حساب المواطن", day: 10, friday: -1, saturday: 1, source: "برنامج حساب المواطن")
    static let pension = Rule(id: "pension", title: "التقاعد والضمان", day: 1, friday: -1, saturday: 1, source: "المؤسسة العامة للتأمينات والضمان الاجتماعي")
    /// Dates the Ministry of Finance moved away from the rule (holidays), id:yyyy-mm → day.
    private static let overrides = ["gov:2026-05": 24]

    static func custom(_ day: Int) -> Rule { Rule(id: "custom", title: "راتبي", day: min(max(day, 1), 31), friday: 0, saturday: 0, source: "الموعد الذي حددته") }

    /// The payment date for that month (noon, Riyadh time).
    static func inMonth(_ r: Rule, _ y: Int, _ m: Int) -> Date {
        let cal = KSA.cal
        let first = cal.date(from: DateComponents(year: y, month: m, day: 1, hour: 12))!
        if let o = overrides["\(r.id):\(y)-\(String(format: "%02d", m))"] { return cal.date(from: DateComponents(year: y, month: m, day: o, hour: 12))! }
        let last = cal.range(of: .day, in: .month, for: first)!.count
        var d = cal.date(from: DateComponents(year: y, month: m, day: min(r.day, last), hour: 12))!
        switch cal.component(.weekday, from: d) {
        case 6: d = cal.date(byAdding: .day, value: r.friday, to: d)!
        case 7: d = cal.date(byAdding: .day, value: r.saturday, to: d)!
        default: break
        }
        return d
    }

    /// Days from `today` to the next payment, and its date (today counts as 0).
    static func next(_ r: Rule, _ today: Date = Date()) -> (Int, Date) {
        let cal = KSA.cal
        let t0 = cal.startOfDay(for: today)
        var (y, m, _) = KSA.ymd(today)
        for _ in 0..<3 {
            let d = inMonth(r, y, m)
            let days = cal.dateComponents([.day], from: t0, to: cal.startOfDay(for: d)).day!
            if days >= 0 { return (days, d) }
            m += 1; if m == 13 { m = 1; y += 1 }
        }
        let d = inMonth(r, y, m); return (cal.dateComponents([.day], from: t0, to: cal.startOfDay(for: d)).day!, d)
    }
}

/// Islamic occasions on the Umm al-Qura calendar: days from today to the next one (0 = today). Same list as Android.
enum Occasions {
    struct O: Equatable { let title: String; let days: Int }
    private static let fixed: [(Int, Int, String)] = [(9, 1, "رمضان"), (10, 1, "عيد الفطر"), (12, 9, "يوم عرفة"), (12, 10, "عيد الأضحى"), (1, 1, "السنة الهجرية"), (1, 10, "عاشوراء")]
    private static var hcal: Calendar { var u = Calendar(identifier: .islamicUmmAlQura); u.timeZone = TimeZone(identifier: "Asia/Riyadh")!; return u }

    static func upcoming(_ today: Date, within: Int = 90) -> [O] {
        let g = KSA.cal, u = hcal
        let t0 = g.startOfDay(for: today)
        let h = u.dateComponents([.year, .month, .day], from: g.date(byAdding: .hour, value: 12, to: t0)!)
        func to(_ y: Int, _ m: Int, _ d: Int) -> Int {
            guard let date = u.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) else { return -1 }
            return g.dateComponents([.day], from: t0, to: g.startOfDay(for: date)).day ?? -1
        }
        let (y, m, d) = (h.year!, h.month!, h.day!)
        var out = fixed.map { fm, fd, title -> O in var n = to(y, fm, fd); if n < 0 { n = to(y + 1, fm, fd) }; return O(title: title, days: n) }
        let white = (13...15).contains(d) ? 0 : d < 13 ? to(y, m, 13) : (m == 12 ? to(y + 1, 1, 13) : to(y, m + 1, 13))
        out.append(O(title: "الأيام البيض", days: white))
        return out.filter { (0...within).contains($0.days) }.sorted { $0.days < $1.days }
    }
}
