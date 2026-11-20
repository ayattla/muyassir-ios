import Foundation

enum Units {
    struct U: Hashable { let name: String; let toBase: Double }
    struct Kind: Hashable { let name: String; let units: [U] }

    static let kinds: [Kind] = [
        Kind(name: "الطول", units: [U(name: "مليمتر", toBase: 0.001), U(name: "سنتيمتر", toBase: 0.01), U(name: "متر", toBase: 1), U(name: "كيلومتر", toBase: 1000), U(name: "بوصة", toBase: 0.0254), U(name: "قدم", toBase: 0.3048), U(name: "ياردة", toBase: 0.9144), U(name: "ميل", toBase: 1609.344)]),
        Kind(name: "الوزن", units: [U(name: "جرام", toBase: 0.001), U(name: "كيلوجرام", toBase: 1), U(name: "طن", toBase: 1000), U(name: "أونصة", toBase: 0.0283495), U(name: "رطل", toBase: 0.453592)]),
        Kind(name: "المساحة", units: [U(name: "متر مربع", toBase: 1), U(name: "كيلومتر مربع", toBase: 1e6), U(name: "هكتار", toBase: 10000), U(name: "دونم", toBase: 1000), U(name: "قدم مربع", toBase: 0.092903), U(name: "فدان", toBase: 4046.86)]),
        Kind(name: "الحجم", units: [U(name: "مليلتر", toBase: 0.001), U(name: "لتر", toBase: 1), U(name: "متر مكعب", toBase: 1000), U(name: "جالون أمريكي", toBase: 3.78541), U(name: "كوب", toBase: 0.24)]),
        Kind(name: "السرعة", units: [U(name: "متر/ث", toBase: 1), U(name: "كم/س", toBase: 1 / 3.6), U(name: "ميل/س", toBase: 0.44704), U(name: "عقدة", toBase: 0.514444)]),
        Kind(name: "البيانات", units: [U(name: "بايت", toBase: 1), U(name: "كيلوبايت", toBase: 1024), U(name: "ميجابايت", toBase: 1048576), U(name: "جيجابايت", toBase: 1073741824), U(name: "تيرابايت", toBase: 1099511627776)]),
        Kind(name: "الوقت", units: [U(name: "ثانية", toBase: 1), U(name: "دقيقة", toBase: 60), U(name: "ساعة", toBase: 3600), U(name: "يوم", toBase: 86400), U(name: "أسبوع", toBase: 604800)]),
        Kind(name: "الحرارة", units: [U(name: "مئوية", toBase: 1), U(name: "فهرنهايت", toBase: 1), U(name: "كلفن", toBase: 1)]),
    ]

    static func convert(_ k: Kind, _ v: Double, from: U, to: U) -> Double {
        if k.name == "الحرارة" {
            let c = from.name == "فهرنهايت" ? (v - 32) * 5 / 9 : from.name == "كلفن" ? v - 273.15 : v
            return to.name == "فهرنهايت" ? c * 9 / 5 + 32 : to.name == "كلفن" ? c + 273.15 : c
        }
        return v * from.toBase / to.toBase
    }

    struct Shape: Hashable {
        let name: String; let fields: [String]; let volume: Bool; let id: Int
        static func == (a: Shape, b: Shape) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
        func calc(_ v: [Double]) -> Double {
            switch id {
            case 0: return v[0] * v[1]; case 1: return v[0] * v[0]; case 2: return .pi * v[0] * v[0]; case 3: return v[0] * v[1] / 2
            case 4: return (v[0] + v[1]) / 2 * v[2]; case 5: return v[0] * v[1]; case 6: return pow(v[0], 3); case 7: return v[0] * v[1] * v[2]
            case 8: return .pi * v[0] * v[0] * v[1]; case 9: return 4.0 / 3 * .pi * pow(v[0], 3); case 10: return .pi * v[0] * v[0] * v[1] / 3
            default: return v[0] * v[1] / 3
            }
        }
    }
    static let shapes: [Shape] = [
        Shape(name: "مستطيل", fields: ["الطول", "العرض"], volume: false, id: 0), Shape(name: "مربع", fields: ["الضلع"], volume: false, id: 1),
        Shape(name: "دائرة", fields: ["نصف القطر"], volume: false, id: 2), Shape(name: "مثلث", fields: ["القاعدة", "الارتفاع"], volume: false, id: 3),
        Shape(name: "شبه منحرف", fields: ["القاعدة الأولى", "القاعدة الثانية", "الارتفاع"], volume: false, id: 4), Shape(name: "متوازي أضلاع", fields: ["القاعدة", "الارتفاع"], volume: false, id: 5),
        Shape(name: "مكعب", fields: ["الضلع"], volume: true, id: 6), Shape(name: "متوازي مستطيلات", fields: ["الطول", "العرض", "الارتفاع"], volume: true, id: 7),
        Shape(name: "أسطوانة", fields: ["نصف القطر", "الارتفاع"], volume: true, id: 8), Shape(name: "كرة", fields: ["نصف القطر"], volume: true, id: 9),
        Shape(name: "مخروط", fields: ["نصف القطر", "الارتفاع"], volume: true, id: 10), Shape(name: "هرم", fields: ["مساحة القاعدة", "الارتفاع"], volume: true, id: 11),
    ]
}

enum Hijri {
    static let months = ["محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"]
    static let gMonths = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
    static let days = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
    static var islamic: Calendar { var c = Calendar(identifier: .islamicUmmAlQura); c.timeZone = TimeZone(identifier: "Asia/Riyadh")!; return c }
    static var greg: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Riyadh")!; return c }

    struct D { let y, m, d, weekday: Int }
    static func toHijri(_ y: Int, _ m: Int, _ d: Int) -> D? {
        guard let date = greg.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) else { return nil }
        let c = islamic.dateComponents([.year, .month, .day, .weekday], from: date)
        return D(y: c.year!, m: c.month!, d: c.day!, weekday: c.weekday!)
    }
    static func toGregorian(_ y: Int, _ m: Int, _ d: Int) -> D? {
        guard let date = islamic.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) else { return nil }
        let c = greg.dateComponents([.year, .month, .day, .weekday], from: date)
        return D(y: c.year!, m: c.month!, d: c.day!, weekday: c.weekday!)
    }
    static func today() -> D { let c = islamic.dateComponents([.year, .month, .day, .weekday], from: Date()); return D(y: c.year!, m: c.month!, d: c.day!, weekday: c.weekday!) }
}
