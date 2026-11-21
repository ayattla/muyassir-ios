import SwiftUI

struct ZakatTool: View {
    let tool: Tool; @EnvironmentObject var store: Store
    @State var cash = ""; @State var gold = ""; @State var silver = ""; @State var trade = ""; @State var recv = ""; @State var debts = ""
    @State var basis = 0; @State var price = ""
    var body: some View {
        ToolScreen(tool: tool) {
            Panel(title: "أموالك التي حال عليها الحول") {
                NumField(label: "النقد والأرصدة البنكية", text: $cash, suffix: "ريال"); NumField(label: "قيمة الذهب المُدّخر", text: $gold, suffix: "ريال")
                NumField(label: "قيمة الفضة", text: $silver, suffix: "ريال"); NumField(label: "عروض التجارة بسعر اليوم", text: $trade, suffix: "ريال")
                NumField(label: "الديون المرجوّ سدادها لك", text: $recv, suffix: "ريال"); NumField(label: "الديون الحالّة عليك", text: $debts, suffix: "ريال")
            }
            Panel(title: "النصاب") {
                Seg(options: ["بالذهب (85 غرامًا)", "بالفضة (595 غرامًا)"], selection: $basis)
                NumField(label: basis == 0 ? "سعر غرام الذهب عيار 24 اليوم" : "سعر غرام الفضة اليوم", text: $price, suffix: "ريال")
            }
            let nisab = price.num * (basis == 0 ? 85 : 595)
            if cash.num + gold.num + silver.num + trade.num + recv.num > 0 && nisab > 0 {
                let z = Calc.zakat(cash: cash.num, gold: gold.num, silver: silver.num, trade: trade.num, receivables: recv.num, debts: debts.num, nisab: nisab)
                ResultCard(main: (z.reached ? "الزكاة الواجبة" : "لم يبلغ المال النصاب", money(z.due)), rows: [("المال الزكوي", money(z.wealth)), ("النصاب", money(z.nisab)), ("النسبة", "2.5%")])
                    .onAppear { store.used(tool.id) }
            }
            Hint(text: "حساب تقريبي للحالات الشائعة. الأموال الخاصة (الأسهم، المزارع، الأنعام، الحلي المستعمل) لها أحكام تفصيلية؛ راجع هيئة الزكاة والضريبة والجمارك أو من تثق بعلمه.")
        }
    }
}

struct OvertimeTool: View {
    let tool: Tool; @EnvironmentObject var store: Store
    @State var basic = ""; @State var allow = ""; @State var daily = "8"; @State var hours = ""
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                NumField(label: "الراتب الأساسي", text: $basic, suffix: "ريال"); NumField(label: "البدلات الثابتة (سكن، نقل…)", text: $allow, suffix: "ريال")
                NumField(label: "ساعات العمل اليومية", text: $daily, suffix: "ساعة"); NumField(label: "عدد الساعات الإضافية", text: $hours, suffix: "ساعة")
            }
            if basic.num > 0 && hours.num > 0 {
                let o = Calc.overtime(basic: basic.num, allowances: allow.num, dailyHours: daily.num, hours: hours.num)
                ResultCard(main: ("أجر الساعات الإضافية", money(o.total)), rows: [("أجر الساعة الفعلي", money(o.hourly)), ("50% من أجر الساعة الأساسي", money(o.basicHourly * 0.5)), ("أجر الساعة الإضافية", money(o.perHour))])
                    .onAppear { store.used(tool.id) }
            }
            Hint(text: "وفق المادة 107 من نظام العمل: أجر الساعة مضافًا إليه 50% من الأجر الأساسي. أجر الساعة = الأجر الشهري ÷ 30 ÷ ساعات العمل اليومية. يجوز باتفاق الطرفين احتساب أيام راحة تعويضية بدل الأجر.")
        }
    }
}

struct ElectricityTool: View {
    let tool: Tool; @EnvironmentObject var store: Store
    @State var kwh = ""; @State var fixed = ""
    // The residential tariff changes on 1 January 2027 (18/30 → 21/33 halalas per kWh).
    @State var period = Date() >= Date(timeIntervalSince1970: 1_798_750_800) ? 1 : 0
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Seg(options: ["حتى 31 ديسمبر 2026", "من 1 يناير 2027"], selection: $period)
                NumField(label: "الاستهلاك الشهري", text: $kwh, suffix: "ك.و.س"); NumField(label: "الرسوم الثابتة في فاتورتك (اختياري)", text: $fixed, suffix: "ريال")
            }
            let (r1, r2) = period == 0 ? (18.0, 30.0) : (21.0, 33.0)
            if kwh.num > 0 {
                let p = Calc.electricity(kwh: kwh.num, rate1: r1, rate2: r2, fixed: fixed.num)
                ResultCard(main: ("الفاتورة التقديرية", money(p.total)), rows: [("حتى 6,000 ك.و.س (\(fmt(r1, 0)) هللة)", money(p.tier1)), ("ما زاد عن 6,000 (\(fmt(r2, 0)) هللة)", money(p.tier2)), ("الرسوم الثابتة", money(p.fixed)), ("ضريبة القيمة المضافة 15%", money(p.vat))])
                    .onAppear { store.used(tool.id) }
            }
            Hint(text: "للقطاع السكني. ابتداءً من 1 يناير 2027 تصبح التعرفة 21 هللة حتى 6,000 ك.و.س و33 هللة لما زاد، ويُستبدل رسم الخدمة برسم ثابت حسب سعة القاطع؛ أدخل الرسم الظاهر في فاتورتك. التقدير لا يغني عن فاتورة الشركة السعودية للكهرباء.")
        }
    }
}

struct DateDiffTool: View {
    let tool: Tool; @EnvironmentObject var store: Store
    @State var from = Calendar.current.date(byAdding: .year, value: -25, to: Date())!; @State var to = Date()
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { DatePicker("من تاريخ (مثل تاريخ الميلاد)", selection: $from, displayedComponents: .date); DatePicker("إلى تاريخ", selection: $to, displayedComponents: .date) }
            let s = Calc.span(from, to)
            let hf = Hijri.islamic.dateComponents([.year, .month, .day], from: from), ht = Hijri.islamic.dateComponents([.year, .month, .day], from: to)
            ResultCard(main: ("المدة", "\(s.years) سنة و\(s.months) شهر و\(s.days) يوم"), rows: [
                ("إجمالي الأيام", "\(s.totalDays)"), ("بالأسابيع", "\(s.totalDays / 7) أسبوع و\(s.totalDays % 7) يوم"),
                ("من (هجري)", "\(hf.day ?? 0) \(Hijri.months[(hf.month ?? 1) - 1]) \(hf.year ?? 0) هـ"), ("إلى (هجري)", "\(ht.day ?? 0) \(Hijri.months[(ht.month ?? 1) - 1]) \(ht.year ?? 0) هـ"),
            ]).onAppear { store.used(tool.id) }
            Hint(text: "الهجري وفق تقويم أم القرى.")
        }
    }
}
