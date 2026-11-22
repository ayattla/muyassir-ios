import SwiftUI

/// How the result was calculated: formula, article, official source, last review date and the estimate warning.
struct RulePanel: View {
    let ids: [String]
    init(_ ids: String...) { self.ids = ids }
    @State private var open = false
    @Environment(\.openURL) private var openURL
    var body: some View {
        Panel {
            HStack { Text("طريقة الحساب والمصدر الرسمي").font(.plex(.subheadline, .semibold)); Spacer(); Button(open ? "إخفاء" : "عرض") { withAnimation { open.toggle() } }.accessibilityIdentifier("ruleToggle") }
            if open {
                ForEach(ids.compactMap { SaudiRules.rules[$0] }, id: \.id) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(r.title).font(.plex(.subheadline, .semibold))
                        Text(r.formula).font(.plex(.footnote))
                        Text("\(r.articles) • آخر مراجعة \(r.reviewed)").font(.plex(.caption)).foregroundStyle(Brand.text2)
                        if let u = URL(string: r.sourceURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") { Button(r.source) { openURL(u) }.font(.plex(.caption, .semibold)) }
                    }
                }
            }
            Text("النتيجة تقديرية للحالات الشائعة ولا تُعد فتوى نظامية؛ العقد والأحكام القضائية واللوائح قد تغيّرها. راجع الجهة المختصة قبل الاعتماد عليها.").font(.plex(.caption)).foregroundStyle(Brand.text2)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("rulePanel")
    }
}

struct ServiceTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var start = Calendar.current.date(byAdding: .year, value: -3, to: Date())!; @State var end = Date()
    var body: some View {
        let s = SaudiRules.service(start, end)
        ToolScreen(tool: tool) {
            Panel { DatePicker("تاريخ المباشرة", selection: $start, displayedComponents: .date); DatePicker("تاريخ انتهاء العلاقة", selection: $end, displayedComponents: .date) }
            ResultCard(main: ("مدة الخدمة", "\(s.years) سنة و\(s.months) شهر و\(s.days) يوم"), rows: [("بالأيام", "\(s.totalDays) يوم"), ("بالسنوات", fmt(s.asYears, 2))])
            RulePanel("service")
        }
        .onAppear { store.used(tool.id) }
    }
}

struct NoticeTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var contract = 0; @State var by = 0; @State var monthly = 0; @State var given = "0"; @State var wage = ""
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Text("نوع العقد").font(.plex(.caption, .medium)); Seg(options: ["غير محدد المدة", "محدد المدة"], selection: $contract)
                Text("من أنهى العقد").font(.plex(.caption, .medium)); Seg(options: ["صاحب العمل", "العامل"], selection: $by)
                Text("طريقة دفع الأجر").font(.plex(.caption, .medium)); Seg(options: ["شهري", "غير شهري"], selection: $monthly)
                NumField(label: "أيام الإشعار التي أُعطيت", text: $given, suffix: "يوم")
                NumField(label: "الأجر الشهري", text: $wage, suffix: "ريال")
            }
            if wage.num > 0 {
                let n = SaudiRules.notice(contract == 0 ? .open : .fixed, by == 0 ? .employer : .worker, monthlyPaid: monthly == 0, given: Int(given.num), wage: wage.num)
                if contract == 1 { ResultCard(main: ("لا مهلة إشعار في العقد محدد المدة", money(0)), note: "إنهاؤه مبكرًا دون سبب مشروع يرتب تعويض المادة 77.") }
                else { ResultCard(main: ("التعويض عن المهلة", money(n.amount)), rows: [("المهلة النظامية", "\(n.requiredDays) يومًا"), ("الأيام الناقصة", "\(n.missingDays) يومًا"), ("يدفعه", by == 0 ? "صاحب العمل للعامل" : "العامل لصاحب العمل")]) }
            }
            RulePanel("notice", "art77")
        }
        .onChange(of: wage) { store.used(tool.id) }
    }
}

struct SettlementTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var sector = 0; @State var contract = 0
    @State var start = Calendar.current.date(byAdding: .year, value: -3, to: Date())!; @State var end = Date()
    @State var wage = ""; @State var reason = SaudiRules.Reason.contractEnd
    @State var unpaid = "0"; @State var leave = "0"; @State var given = "0"; @State var remaining = "0"
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Text("القطاع").font(.plex(.caption, .medium)); Seg(options: ["خاص", "حكومي"], selection: $sector)
                if sector == 1 { Hint(text: "موظفو الجهات الحكومية يخضعون لنظام الخدمة المدنية وليس نظام العمل؛ هذه الحاسبة للقطاع الخاص.") }
            }
            if sector == 0 {
                Panel {
                    Text("نوع العقد").font(.plex(.caption, .medium)); Seg(options: ["غير محدد المدة", "محدد المدة"], selection: $contract)
                    DatePicker("تاريخ المباشرة", selection: $start, displayedComponents: .date); DatePicker("تاريخ انتهاء العلاقة", selection: $end, displayedComponents: .date)
                    NumField(label: "آخر أجر شهري (الأساسي + البدلات الثابتة)", text: $wage, suffix: "ريال")
                    Picker("سبب انتهاء العلاقة", selection: $reason) { ForEach(SaudiRules.Reason.allCases) { Text($0.rawValue).tag($0) } }
                    NumField(label: "أيام عمل لم يُدفع أجرها", text: $unpaid, suffix: "يوم")
                    NumField(label: "رصيد الإجازة غير المستخدم", text: $leave, suffix: "يوم")
                    if reason == .employerLawful || reason == .employerUnlawful { NumField(label: "أيام الإشعار التي أُعطيت", text: $given, suffix: "يوم") }
                    if reason == .employerUnlawful && contract == 1 { NumField(label: "الأشهر المتبقية من العقد", text: $remaining, suffix: "شهر") }
                }
                if wage.num > 0 {
                    let lines = SaudiRules.settlement(wage: wage.num, start: start, end: end, reason: reason, contract: contract == 0 ? .open : .fixed, unpaidDays: unpaid.num, leaveDays: leave.num, noticeGiven: Int(given.num), remainingMonths: remaining.num)
                    let sp = SaudiRules.service(start, end)
                    ResultCard(main: ("إجمالي التسوية التقديرية", money(lines.reduce(0) { $0 + $1.amount })), rows: [("مدة الخدمة", "\(sp.years) سنة و\(sp.months) شهر و\(sp.days) يوم")] + lines.map { ($0.label, money($0.amount)) })
                    Panel(title: "تفاصيل الحساب") { ForEach(lines.indices, id: \.self) { LabelValue(label: lines[$0].label, value: lines[$0].note) } }
                }
            }
            RulePanel("eos", "leave", "notice", "art77", "service")
        }
        .onChange(of: wage) { store.used(tool.id) }
    }
}

struct EntitlementsTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var wage = ""; @State var basic = ""; @State var unpaid = ""; @State var ot = ""; @State var daily = "8"; @State var leave = ""
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                NumField(label: "الأجر الشهري الكامل", text: $wage, suffix: "ريال"); NumField(label: "الراتب الأساسي (للعمل الإضافي)", text: $basic, suffix: "ريال")
                NumField(label: "أيام عمل لم يُدفع أجرها", text: $unpaid, suffix: "يوم"); NumField(label: "ساعات عمل إضافي لم تُدفع", text: $ot, suffix: "ساعة")
                NumField(label: "ساعات العمل اليومية", text: $daily, suffix: "ساعة"); NumField(label: "رصيد إجازة يُصرف بدله", text: $leave, suffix: "يوم")
            }
            if wage.num > 0 {
                let w = wage.num, u = unpaid.num * w / 30, l = leave.num * w / 30
                let o = ot.num > 0 ? Calc.overtime(basic: basic.num > 0 ? basic.num : w, allowances: max(0, w - basic.num), dailyHours: max(1, daily.num), hours: ot.num).total : 0
                ResultCard(main: ("المستحقات", money(u + l + o)), rows: [("أجر الأيام غير المدفوعة", money(u)), ("العمل الإضافي", money(o)), ("بدل الإجازة", money(l))])
            }
            RulePanel("overtime", "leave")
        }
        .onChange(of: wage) { store.used(tool.id) }
    }
}

struct DeductTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var wage = ""; @State var req = ""
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { NumField(label: "الأجر المستحق هذا الشهر", text: $wage, suffix: "ريال"); NumField(label: "المبلغ المطلوب استقطاعه (سلفة، جزاء…)", text: $req, suffix: "ريال") }
            if wage.num > 0 && req.num > 0 {
                let d = SaudiRules.deduction(wage: wage.num, requested: req.num)
                ResultCard(main: ("الحد المسموح استقطاعه", money(d.allowed)), rows: [("الحد الأعلى (نصف الأجر)", money(d.cap)), ("الباقي للأشهر التالية", money(max(0, d.requested - d.allowed))), ("صافي ما يُصرف", money(wage.num - d.allowed))])
            }
            RulePanel("deduct")
        }
        .onChange(of: req) { store.used(tool.id) }
    }
}
