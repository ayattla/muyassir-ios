import Foundation

/// Versioned rules behind every Saudi calculator: formula, article, official source and last review date.
/// Other Gulf countries are declared but stay disabled until their rules are reviewed.
enum SaudiRules {
    enum Country: String, CaseIterable { case sa = "السعودية", ae = "الإمارات", kw = "الكويت", qa = "قطر", bh = "البحرين", om = "عمان"
        var enabled: Bool { self == .sa } }

    struct Rule { let id, title, formula, articles, source, sourceURL, reviewed: String }
    static let labor = "https://www.hrsd.gov.sa/knowledge-centre/نظام-العمل"
    static let gosiURL = "https://awareness.gosi.gov.sa/pdf/Contributions.pdf"
    static let reviewed = "22 نوفمبر 2026"

    static let rules: [String: Rule] = Dictionary(uniqueKeysWithValues: [
        Rule(id: "eos", title: "مكافأة نهاية الخدمة", formula: "نصف أجر شهر عن كل سنة من الخمس الأولى، وأجر شهر عن كل سنة بعدها، وتحسب كسور السنة بنسبتها. عند الاستقالة: لا شيء قبل سنتين، ثلث المكافأة من 2 إلى أقل من 5، ثلثاها من 5 إلى أقل من 10، وكاملة بعد 10 سنوات.", articles: "المادتان 84 و85 من نظام العمل", source: "وزارة الموارد البشرية — نظام العمل", sourceURL: labor, reviewed: reviewed),
        Rule(id: "leave", title: "رصيد الإجازة السنوية", formula: "21 يوما سنويا، و30 يوما إذا أمضى العامل خمس سنوات متصلة لدى صاحب العمل. قيمة الرصيد = الأيام المتبقية × (الأجر الشهري ÷ 30)، ويستحق العامل أجر ما لم يتمتع به عند انتهاء العقد.", articles: "المادتان 109 و111 من نظام العمل", source: "وزارة الموارد البشرية — نظام العمل", sourceURL: labor, reviewed: reviewed),
        Rule(id: "salary", title: "اشتراكات التأمينات الاجتماعية", formula: "الأجر الخاضع = الأساسي + السكن (بحد أعلى 45,000 ريال). السعودي في النظام السابق: 9% معاشات + 0.75% ساند على الموظف. النظام الجديد (المسجلون لأول مرة من 3 يوليو 2024): المعاشات 9.5% من 1 يوليو 2025، و10% من 1 يوليو 2026، و10.5% من 1 يوليو 2027، و11% من 1 يوليو 2028، على كل من الموظف وصاحب العمل، إضافة إلى ساند 0.75%. غير السعودي: 2% أخطار مهنية على صاحب العمل فقط.", articles: "نظام التأمينات الاجتماعية (م/273)", source: "المؤسسة العامة للتأمينات الاجتماعية — نسب الاشتراك", sourceURL: gosiURL, reviewed: reviewed),
        Rule(id: "overtime", title: "أجر العمل الإضافي", formula: "أجر الساعة الإضافية = أجر الساعة الفعلي + 50% من أجر الساعة الأساسي. أجر الساعة = الأجر الشهري ÷ 30 ÷ ساعات العمل اليومية.", articles: "المادة 107 من نظام العمل", source: "وزارة الموارد البشرية — نظام العمل", sourceURL: labor, reviewed: reviewed),
        Rule(id: "service", title: "مدة الخدمة", formula: "الفرق بين تاريخ المباشرة وتاريخ انتهاء العلاقة بالسنوات والأشهر والأيام، وهو أساس المكافأة والإجازة والتعويض.", articles: "المادة 84 (حساب المدة)", source: "وزارة الموارد البشرية — نظام العمل", sourceURL: labor, reviewed: reviewed),
        Rule(id: "notice", title: "التعويض عن مهلة الإشعار", formula: "في العقد غير محدد المدة وأجره شهري: مهلة 30 يوما إن أنهاه العامل، و60 يوما إن أنهاه صاحب العمل؛ ولغير الشهري 30 يوما. من لم يلتزم بالمهلة يدفع للطرف الآخر أجر العامل عن المهلة أو ما تبقى منها. العقد محدد المدة لا مهلة إشعار فيه.", articles: "المادتان 75 و76 من نظام العمل (بعد تعديل م/44 النافذ في 19 فبراير 2025)", source: "وزارة الموارد البشرية — نظام العمل", sourceURL: labor, reviewed: reviewed),
        Rule(id: "art77", title: "تعويض الإنهاء لسبب غير مشروع", formula: "ما لم يحدد العقد تعويضا: أجر 15 يوما عن كل سنة خدمة في العقد غير محدد المدة، وأجر المدة الباقية في العقد محدد المدة، وبحد أدنى أجر شهرين في الحالتين. يضاف إلى المكافأة ولا يحل محلها.", articles: "المادة 77 من نظام العمل", source: "وزارة الموارد البشرية — نظام العمل", sourceURL: labor, reviewed: reviewed),
        Rule(id: "deduct", title: "الاستقطاع من الأجر", formula: "لا يجوز أن يزيد ما يستقطع من أجر العامل وفاء للقروض والجزاءات ونحوها على نصف الأجر المستحق. للنظام استثناءات محددة (مثل دين النفقة) تراجع فيها المادة نفسها.", articles: "المادة 92 من نظام العمل", source: "وزارة الموارد البشرية — نظام العمل", sourceURL: labor, reviewed: reviewed),
        Rule(id: "vat", title: "ضريبة القيمة المضافة", formula: "النسبة الأساسية 15%. السعر شامل الضريبة = السعر × 1.15، والضريبة من سعر شامل = السعر × 15 ÷ 115.", articles: "نظام ضريبة القيمة المضافة", source: "هيئة الزكاة والضريبة والجمارك", sourceURL: "https://zatca.gov.sa", reviewed: reviewed),
    ].map { ($0.id, $0) })

    private static var riyadh: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Riyadh")!; return c }
    private static func day(_ y: Int, _ m: Int, _ d: Int) -> Date { riyadh.date(from: DateComponents(year: y, month: m, day: d))! }

    /// The new-system pension share on a date (GOSI's published schedule).
    static func newPensionRate(_ at: Date = Date()) -> Double {
        if at < day(2025, 7, 1) { return 9 }
        if at < day(2026, 7, 1) { return 9.5 }
        if at < day(2027, 7, 1) { return 10 }
        if at < day(2028, 7, 1) { return 10.5 }
        return 11
    }

    struct Span { let years, months, days: Int; let totalDays: Int; var asYears: Double { Double(totalDays) / 365 } }
    static func service(_ start: Date, _ end: Date) -> Span {
        let a = min(start, end), b = max(start, end), c = Calendar(identifier: .gregorian)
        let k = c.dateComponents([.year, .month, .day], from: a, to: b)
        return Span(years: k.year ?? 0, months: k.month ?? 0, days: k.day ?? 0, totalDays: c.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    enum Contract { case open, fixed }
    enum By { case employer, worker }
    struct Notice { let requiredDays, missingDays: Int; let amount: Double }
    static func notice(_ contract: Contract, _ by: By, monthlyPaid: Bool, given: Int, wage: Double) -> Notice {
        guard contract == .open else { return Notice(requiredDays: 0, missingDays: 0, amount: 0) }
        let req = !monthlyPaid ? 30 : by == .employer ? 60 : 30, miss = max(0, req - given)
        return Notice(requiredDays: req, missingDays: miss, amount: Double(miss) * wage / 30)
    }
    static func art77(_ contract: Contract, years: Double, remainingMonths: Double, wage: Double) -> Double {
        max(contract == .open ? years * wage / 2 : remainingMonths * wage, wage * 2)
    }
    struct Deduct { let requested, allowed, cap: Double }
    static func deduction(wage: Double, requested: Double) -> Deduct { let cap = wage / 2; return Deduct(requested: requested, allowed: min(requested, cap), cap: cap) }

    enum Reason: String, CaseIterable, Identifiable {
        case contractEnd = "انتهاء مدة العقد", employerLawful = "إنهاء من صاحب العمل بسبب مشروع (مادة 75)", employerUnlawful = "إنهاء من صاحب العمل دون سبب مشروع"
        case resignation = "استقالة العامل", art81 = "ترك العامل العمل وفق المادة 81", art80 = "فسخ صاحب العمل وفق المادة 80"
        var id: String { rawValue }
    }
    struct Line { let label: String; let amount: Double; let note: String }
    static func settlement(wage: Double, start: Date, end: Date, reason: Reason, contract: Contract, unpaidDays: Double, leaveDays: Double, noticeGiven: Int, remainingMonths: Double) -> [Line] {
        let years = service(start, end).asYears; var out: [Line] = []
        if unpaidDays > 0 { out.append(Line(label: "أجر الأيام غير المدفوعة", amount: unpaidDays * wage / 30, note: "\(fmt(unpaidDays)) يوم × الأجر ÷ 30")) }
        if leaveDays > 0 { out.append(Line(label: "بدل رصيد الإجازة", amount: leaveDays * wage / 30, note: "المادة 111: \(fmt(leaveDays)) يوم")) }
        let full = min(years, 5) * wage / 2 + max(years - 5, 0) * wage
        let share: Double = reason == .art80 ? 0 : reason == .resignation ? (years < 2 ? 0 : years < 5 ? 1.0 / 3 : years < 10 ? 2.0 / 3 : 1) : 1
        out.append(Line(label: "مكافأة نهاية الخدمة", amount: full * share, note: share < 1 ? "المادة 85: \(share == 0 ? "لا تستحق" : share < 0.5 ? "الثلث" : "الثلثان")" : "المادة 84: كاملة"))
        if reason == .employerLawful || reason == .employerUnlawful {
            if reason == .employerUnlawful { out.append(Line(label: "تعويض الإنهاء غير المشروع", amount: art77(contract, years: years, remainingMonths: remainingMonths, wage: wage), note: "المادة 77، بحد أدنى أجر شهرين")) }
            let n = notice(contract, .employer, monthlyPaid: true, given: noticeGiven, wage: wage)
            if n.amount > 0 { out.append(Line(label: "تعويض مهلة الإشعار", amount: n.amount, note: "المادة 76: \(n.missingDays) يوما من \(n.requiredDays)")) }
        }
        return out
    }
}
