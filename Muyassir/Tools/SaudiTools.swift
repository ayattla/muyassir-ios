import SwiftUI

struct VatTool: View {
    let tool: Tool; @EnvironmentObject var store: Store
    @State var amount = ""; @State var mode = 0; @State var rate = "15"
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { Seg(options: ["إضافة الضريبة", "استخراج من مبلغ شامل"], selection: $mode)
                NumField(label: mode == 0 ? "المبلغ قبل الضريبة" : "المبلغ شامل الضريبة", text: $amount, suffix: "ريال"); NumField(label: "نسبة الضريبة", text: $rate, suffix: "%") }
            if amount.num > 0 {
                let r = Calc.vat(amount.num, rate: rate.num, inclusive: mode == 1)
                ResultCard(main: ("الإجمالي شامل الضريبة", money(r.total)), rows: [("قبل الضريبة", money(r.net)), ("قيمة الضريبة (\(fmt(rate.num))%)", money(r.vat))])
                    .onAppear { store.used(tool.id) }
            }
            Hint(text: "النسبة الأساسية لضريبة القيمة المضافة في المملكة 15% وفق هيئة الزكاة والضريبة والجمارك.")
        }
    }
}

struct SalaryTool: View {
    let tool: Tool
    @State var basic = ""; @State var housing = ""; @State var transport = ""; @State var other = ""; @State var ded = ""; @State var saudi = 0; @State var sys = 0
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Seg(options: ["سعودي", "غير سعودي"], selection: $saudi)
                if saudi == 0 { Text("نظام التأمينات").font(.plex(.subheadline, .semibold)); Seg(options: ["مسجل قبل 3 يوليو 2024", "النظام الجديد"], selection: $sys) }
                NumField(label: "الراتب الأساسي", text: $basic, suffix: "ريال"); NumField(label: "بدل السكن", text: $housing, suffix: "ريال")
                NumField(label: "بدل النقل", text: $transport, suffix: "ريال"); NumField(label: "بدلات أخرى", text: $other, suffix: "ريال")
                NumField(label: "استقطاعات أخرى (سلف، غياب…)", text: $ded, suffix: "ريال")
            }
            if basic.num > 0 {
                let sy: Calc.GosiSystem = sys == 0 ? .legacy : .new
                let s = Calc.salary(basic: basic.num, housing: housing.num, transport: transport.num, other: other.num, saudi: saudi == 0, system: sy, deductions: ded.num)
                let g = Calc.gosi(basic: basic.num, housing: housing.num, saudi: saudi == 0, system: sy)
                ResultCard(main: ("صافي الراتب الشهري", money(s.net)), rows: [("إجمالي الراتب", money(s.gross)), ("خصم التأمينات (\(fmt(g.employeeRate))%)", money(s.gosi)),
                    ("الأجر الخاضع للاشتراك", money(g.base)), ("حصة صاحب العمل (\(fmt(g.employerRate))%)", money(g.employer)), ("صافي سنوي", money(s.net * 12))])
            }
            Hint(text: "الأجر الخاضع = الأساسي + السكن بحد أقصى 45,000 ريال. للسعودي في النظام السابق: 9% معاشات + 0.75% ساند على الموظف، ويضيف صاحب العمل 2% أخطار مهنية. في النظام الجديد ترتفع نسبة المعاشات 0.5% كل يوليو (9.5% في 2026). تحقق من تطبيق «تأميناتي» لمعرفة نظامك.")
        }
    }
}

struct EosTool: View {
    let tool: Tool; @State var wage = ""; @State var y = ""; @State var m = ""; @State var d = ""; @State var how = 0
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { NumField(label: "آخر أجر شهري (الأساسي + البدلات الثابتة)", text: $wage, suffix: "ريال")
                HStack { NumField(label: "سنوات", text: $y); NumField(label: "أشهر", text: $m); NumField(label: "أيام", text: $d) }
                Seg(options: ["انتهاء العقد/إنهاء من صاحب العمل", "استقالة"], selection: $how) }
            if wage.num > 0 && y.num + m.num + d.num > 0 {
                let r = Calc.endOfService(wage: wage.num, years: Int(y.num), months: Int(m.num), days: Int(d.num), how: how == 0 ? .termination : .resignation)
                ResultCard(main: ("المكافأة المستحقة", money(r.payable)), rows: [("مدة الخدمة", "\(fmt(r.years)) سنة"), ("المكافأة الكاملة", money(r.fullAward)),
                    ("نسبة الاستحقاق", r.share == 1 ? "كاملة" : r.share == 0 ? "لا تستحق" : "\(fmt(r.share * 100, 0))%")])
            }
            Hint(text: "المادة 84: نصف أجر شهر عن كل سنة من الخمس الأولى، وأجر شهر عن كل سنة بعدها. المادة 85 للاستقالة: لا شيء قبل سنتين، الثلث من 2 إلى 5، الثلثان من 5 إلى 10، وكاملة بعد 10 سنوات. النتيجة تقديرية.")
        }
    }
}

struct LeaveTool: View {
    let tool: Tool; @State var years = ""; @State var months = "12"; @State var used = "0"; @State var wage = ""
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { NumField(label: "سنوات الخدمة", text: $years); NumField(label: "الأشهر المنقضية من سنة الاستحقاق", text: $months)
                NumField(label: "الأيام المستخدمة", text: $used, suffix: "يوم"); NumField(label: "الأجر الشهري", text: $wage, suffix: "ريال") }
            if !years.isEmpty {
                let r = Calc.leave(serviceYears: years.num, monthsThisYear: months.num, usedDays: used.num, wage: wage.num)
                ResultCard(main: ("الرصيد المتبقي", "\(fmt(r.remaining, 1)) يوم"), rows: [("الاستحقاق السنوي", "\(r.entitlement) يومًا"), ("المستحق حتى الآن", "\(fmt(r.accrued, 1)) يوم"), ("قيمة الرصيد", money(r.value))])
            }
            Hint(text: "المادة 109 من نظام العمل: 21 يومًا سنويًا، تزيد إلى 30 يومًا بعد خمس سنوات متصلة لدى صاحب العمل.")
        }
    }
}

struct FinanceTool: View {
    let tool: Tool; @State var amount = ""; @State var rate = ""; @State var months = "60"; @State var type = 0; @State var down = "0"
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { Seg(options: ["نسبة ثابتة (Flat)", "متناقصة"], selection: $type)
                NumField(label: "مبلغ التمويل أو سعر السلعة", text: $amount, suffix: "ريال"); NumField(label: "الدفعة الأولى", text: $down, suffix: "ريال")
                NumField(label: type == 0 ? "نسبة الربح السنوية الثابتة" : "النسبة السنوية", text: $rate, suffix: "%"); NumField(label: "المدة", text: $months, suffix: "شهر") }
            let p = amount.num - down.num, n = Int(months.num)
            if p > 0 && n > 0 {
                let r = type == 0 ? Calc.flatLoan(p, annualFlat: rate.num, months: n) : Calc.reducingLoan(p, annualRate: rate.num, months: n)
                ResultCard(main: ("القسط الشهري", money(r.monthly)), rows: [("مبلغ التمويل", money(p)), ("إجمالي الأرباح", money(r.profit)), ("إجمالي المدفوع", money(r.totalPaid + down.num)), ("النسبة السنوية الفعلية (APR)", "\(fmt(r.apr))%")])
            }
            Hint(text: "العروض بنسبة ثابتة تبدو أقل من حقيقتها؛ قارن العروض بالنسبة السنوية الفعلية (APR) التي يلزم البنك المركزي السعودي بالإفصاح عنها.")
        }
    }
}

struct DiscountTool: View {
    let tool: Tool; @State var price = ""; @State var d1 = ""; @State var d2 = ""; @State var vat = false
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { NumField(label: "السعر الأصلي", text: $price, suffix: "ريال"); NumField(label: "نسبة الخصم", text: $d1, suffix: "%"); NumField(label: "خصم إضافي (اختياري)", text: $d2, suffix: "%")
                Toggle("إضافة ضريبة 15% بعد الخصم", isOn: $vat).font(.plex(.subheadline)) }
            if price.num > 0 {
                let r = Calc.discount(price.num, [d1.num, d2.num])
                ResultCard(main: ("السعر بعد الخصم", money(vat ? r.final * 1.15 : r.final)), rows: [("التوفير", money(r.saving)), ("الخصم الفعلي", "\(fmt(r.effectivePct))%")] + (vat ? [("قبل الضريبة", money(r.final))] : []),
                           note: d2.num > 0 ? "خصمان متتاليان لا يُجمعان: \(fmt(d1.num))% ثم \(fmt(d2.num))% = \(fmt(r.effectivePct))%" : nil)
            }
        }
    }
}

struct HijriTool: View {
    let tool: Tool
    @State var dir = 0
    @State var y = String(Calendar(identifier: .gregorian).component(.year, from: Date()))
    @State var m = String(Calendar(identifier: .gregorian).component(.month, from: Date()))
    @State var d = String(Calendar(identifier: .gregorian).component(.day, from: Date()))
    var body: some View {
        ToolScreen(tool: tool) {
            let h = Hijri.today()
            ResultCard(main: ("اليوم", "\(h.d) \(Hijri.months[h.m - 1]) \(h.y) هـ"))
            Panel {
                Seg(options: ["ميلادي ← هجري", "هجري ← ميلادي"], selection: $dir)
                HStack { NumField(label: "اليوم", text: $d); NumField(label: "الشهر", text: $m); NumField(label: "السنة", text: $y) }
            }
            .onChange(of: dir) { _, v in
                let g = Calendar(identifier: .gregorian)
                if v == 1 { y = "\(h.y)"; m = "\(h.m)"; d = "\(h.d)" } else { y = "\(g.component(.year, from: Date()))"; m = "\(g.component(.month, from: Date()))"; d = "\(g.component(.day, from: Date()))" }
            }
            if let r = (dir == 0 ? Hijri.toHijri(Int(y.num), Int(m.num), Int(d.num)) : Hijri.toGregorian(Int(y.num), Int(m.num), Int(d.num))), (1...12).contains(Int(m.num)) {
                ResultCard(main: ("النتيجة", "\(Hijri.days[r.weekday - 1]) \(r.d) \(dir == 0 ? Hijri.months[r.m - 1] : Hijri.gMonths[r.m - 1]) \(r.y) \(dir == 0 ? "هـ" : "م")"))
            }
            Hint(text: "وفق تقويم أم القرى المعتمد في المملكة. بدايات الأشهر الشرعية تُعلن رسميًا بالرؤية وقد تختلف بيوم.")
        }
    }
}

struct GovDirectory: View {
    let tool: Tool
    private let groups: [(String, [(String, String, String)])] = [
        ("الهوية والخدمات العامة", [("المنصة الوطنية GOV.SA", "دليل جميع الخدمات الحكومية", "https://my.gov.sa"), ("أبشر", "الجوازات والأحوال المدنية والمرور", "https://www.absher.sa"),
            ("النفاذ الوطني الموحد", "الدخول الموحد للمنصات", "https://www.iam.gov.sa"), ("توكلنا", "الوثائق الرقمية والخدمات", "https://ta.sdaia.gov.sa")]),
        ("العمل والتأمينات", [("قوى", "عقود العمل وخدمات القطاع الخاص", "https://www.qiwa.sa"), ("التأمينات الاجتماعية", "الاشتراكات والمعاشات وساند", "https://www.gosi.gov.sa"),
            ("مساند", "العمالة المنزلية", "https://www.musaned.com.sa"), ("وزارة الموارد البشرية", "خدمات العمل والتنمية الاجتماعية", "https://www.hrsd.gov.sa")]),
        ("المال والتجارة", [("هيئة الزكاة والضريبة والجمارك", "الضريبة والفوترة الإلكترونية", "https://zatca.gov.sa"), ("المركز السعودي للأعمال", "السجلات والتراخيص", "https://business.sa"),
            ("وزارة التجارة", "البلاغات وحماية المستهلك", "https://mc.gov.sa"), ("حساب المواطن", "الدعم والاستحقاق", "https://www.ca.gov.sa")]),
        ("الصحة والتعليم والعدل", [("وزارة الصحة", "الخدمات الصحية وتطبيق صحتي", "https://www.moh.gov.sa"), ("مدرستي", "منصة التعليم", "https://schools.madrasati.sa"),
            ("ناجز", "الخدمات العدلية", "https://najiz.sa"), ("إيجار", "عقود الإيجار", "https://www.ejar.sa")]),
    ]
    var body: some View {
        ToolScreen(tool: tool) {
            Hint(text: "روابط مباشرة للمواقع الرسمية. مُيسّر لا ينفذ معاملات حكومية ولا يطلب بيانات دخولك.")
            ForEach(groups, id: \.0) { g in
                Panel(title: g.0) {
                    ForEach(g.1, id: \.0) { l in
                        Link(destination: URL(string: l.2)!) {
                            HStack { VStack(alignment: .leading) { Text(l.0).font(.plex(.subheadline, .semibold)).foregroundStyle(.primary); Text(l.1).font(.plex(.caption)).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "arrow.up.forward.square") }
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
}

struct EmergencyTool: View {
    let tool: Tool
    private let nums = [("911", "الطوارئ الموحد (الرياض، مكة المكرمة، المدينة المنورة، الشرقية)"), ("999", "الشرطة"), ("997", "الإسعاف — الهلال الأحمر"), ("998", "الدفاع المدني"),
        ("993", "حوادث المرور"), ("996", "أمن الطرق"), ("112", "طوارئ دون شريحة"), ("937", "وزارة الصحة — استشارات"), ("933", "طوارئ الكهرباء"), ("994", "حرس الحدود"),
        ("995", "مكافحة المخدرات (بلاغات سرية)"), ("920000560", "نجم — حوادث المركبات المؤمّنة")]
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                ForEach(nums, id: \.0) { n in
                    Link(destination: URL(string: "tel:\(n.0)")!) {
                        HStack { Text(n.0).font(.plex(.title2, .bold)).foregroundStyle(.red).frame(width: 130, alignment: .leading); Text(n.1).font(.plex(.subheadline)).foregroundStyle(.primary); Spacer(); Image(systemName: "phone.fill").foregroundStyle(Brand.mint) }
                    }
                    Divider()
                }
            }
            Hint(text: "المصدر: قوائم الطوارئ في المنصة الوطنية وشركات الاتصالات. يطلب الجهاز تأكيد الاتصال قبل البدء.")
        }
    }
}
