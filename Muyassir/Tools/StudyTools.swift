import SwiftUI
import AVFoundation
import AudioToolbox
import UniformTypeIdentifiers

struct GpaTool: View {
    let tool: Tool
    struct Row: Identifiable { let id = UUID(); var name = ""; var grade = "A"; var hours = "3" }
    @State var scale = 0; @State var rows = [Row(), Row(grade: "B+"), Row(grade: "A+", hours: "2")]; @State var prevGpa = ""; @State var prevHours = ""
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { Seg(options: ["من 5", "من 4"], selection: $scale) }
            Panel(title: "مواد الفصل") {
                ForEach($rows) { $r in
                    HStack {
                        Field(label: "المادة", text: $r.name)
                        Picker("", selection: $r.grade) { ForEach(Calc.letters, id: \.self) { Text($0) } }.frame(width: 80)
                        NumField(label: "ساعات", text: $r.hours).frame(width: 90)
                        Button { rows.removeAll { $0.id == r.id } } label: { Image(systemName: "xmark") }.buttonStyle(.borderless).accessibilityLabel("حذف")
                    }
                }
                SecondaryButton(title: "إضافة مادة", icon: "plus") { rows.append(Row()) }
            }
            Panel(title: "المعدل السابق (للتراكمي)") { HStack { NumField(label: "المعدل التراكمي", text: $prevGpa); NumField(label: "الساعات المجتازة", text: $prevHours) } }
            let g = Calc.gpa(rows.map { Calc.Course(points: Calc.points($0.grade, scale5: scale == 0), hours: $0.hours.num) }, prevGpa: prevGpa.num, prevHours: prevHours.num)
            let sem = g.0, cum = g.1, mx = scale == 0 ? 5.0 : 4.0
            let word = sem >= mx * 0.9 ? "ممتاز مرتفع" : sem >= mx * 0.75 ? "ممتاز" : sem >= mx * 0.7 ? "جيد جدا مرتفع" : sem >= mx * 0.55 ? "جيد جدا" : sem >= mx * 0.5 ? "جيد" : "مقبول"
            ResultCard(main: ("المعدل الفصلي", "\(fmt(sem)) من \(fmt(mx, 0))"), rows: [("التقدير", word), ("المعدل التراكمي", fmt(cum)), ("ساعات الفصل", fmt(rows.reduce(0) { $0 + $1.hours.num }))])
            Hint(text: "سلم النقاط المستخدم هو الشائع في الجامعات السعودية (A+ = 5، A = 4.75 …). راجع لائحة جامعتك فقد يختلف.")
        }
    }
}

struct PercentTool: View {
    let tool: Tool; @State var mode = 0; @State var a = ""; @State var b = ""
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Seg(options: ["الدرجة", "س% من ص", "التغير"], selection: $mode)
                switch mode {
                case 0: NumField(label: "درجتك", text: $a); NumField(label: "الدرجة الكاملة", text: $b)
                case 1: NumField(label: "النسبة %", text: $a); NumField(label: "من العدد", text: $b)
                default: NumField(label: "القيمة القديمة", text: $a); NumField(label: "القيمة الجديدة", text: $b)
                }
            }
            let x = a.num, y = b.num
            if mode == 0 && y > 0 { let p = x / y * 100; ResultCard(main: ("النسبة", "\(fmt(p))%"), rows: [("التقدير", Calc.gradeWord(p)), ("من 5", fmt(p / 20)), ("من 4", fmt(p / 25))]) }
            if mode == 1 && !b.isEmpty { ResultCard(main: ("الناتج", fmt(x / 100 * y)), rows: [("المتبقي", fmt(y - x / 100 * y))]) }
            if mode == 2 && x != 0 { let c = (y - x) / x * 100; ResultCard(main: (c >= 0 ? "زيادة" : "انخفاض", "\(fmt(abs(c)))%"), rows: [("الفرق", fmt(y - x))]) }
        }
    }
}

struct TimetableTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var data: Rec = [:]
    @State var edit: (Int, Int)?
    @State var text = ""
    @State var pdf: URL?
    let days = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس"]; let periods = 7
    var body: some View {
        ToolScreen(tool: tool) {
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                    GridRow { Text(""); ForEach(1...periods, id: \.self) { Text("الحصة \($0)").font(.plex(.caption)).frame(width: 90) } }
                    ForEach(days.indices, id: \.self) { d in
                        GridRow {
                            Text(days[d]).font(.plex(.subheadline, .semibold)).frame(width: 70, alignment: .leading)
                            ForEach(0..<periods, id: \.self) { p in
                                let v = data.s("\(d)-\(p)")
                                Button { text = v; edit = (d, p) } label: {
                                    Text(v).font(.plex(.caption)).lineLimit(2).frame(width: 90, height: 52)
                                        .background(v.isEmpty ? Color(.secondarySystemGroupedBackground) : Brand.lapis.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain).accessibilityLabel("\(days[d]) الحصة \(p + 1) \(v)").accessibilityIdentifier("cell-\(d)-\(p)")
                            }
                        }
                    }
                }
            }
            SecondaryButton(title: "تصدير PDF للطباعة", icon: "doc.richtext") {
                let b = DocBuilder(landscape: true); b.add(.title("الجدول الدراسي"))
                b.add(.table(header: ["اليوم"] + (1...periods).map { "الحصة \($0)" }, rows: days.indices.map { d in [days[d]] + (0..<periods).map { data.s("\(d)-\($0)") } }))
                pdf = try? b.save(to: FilesX.outDir().appendingPathComponent("الجدول-الدراسي.pdf"))
            }
            if let pdf { ResultFiles(files: [pdf]) }
        }
        .onAppear { data = store.obj("timetable") }
        .alert(edit.map { "\(days[$0.0]) — الحصة \($0.1 + 1)" } ?? "", isPresented: Binding(get: { edit != nil }, set: { if !$0 { edit = nil } })) {
            TextField("المادة", text: $text)
            Button("حفظ") { if let e = edit { data["\(e.0)-\(e.1)"] = text; store.saveObj("timetable", data); store.used(tool.id) }; edit = nil }
            Button("إلغاء", role: .cancel) { edit = nil }
        }
    }
}

struct StudyTimer: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var focus = "25"; @State var rest = "5"; @State var running = false; @State var onBreak = false; @State var left = 25 * 60; @State var sessions = 0
    let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        let total = max(Int((onBreak ? rest : focus).num), 1) * 60
        ToolScreen(tool: tool) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 14)
                Circle().trim(from: 0, to: 1 - Double(left) / Double(total)).stroke(onBreak ? Brand.mint : Brand.lapis, style: StrokeStyle(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack { Text(String(format: "%02d:%02d", left / 60, left % 60)).font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit(); Text(onBreak ? "استراحة" : "تركيز").font(.plex(.subheadline)).foregroundStyle(.secondary) }
            }.frame(width: 230, height: 230).frame(maxWidth: .infinity).padding(.vertical, 8)
            HStack {
                PrimaryButton(title: running ? "إيقاف مؤقت" : "ابدأ", icon: running ? "pause.fill" : "play.fill") { running.toggle(); UIApplication.shared.isIdleTimerDisabled = running }
                SecondaryButton(title: "إعادة", icon: "arrow.counterclockwise") { running = false; onBreak = false; left = max(Int(focus.num), 1) * 60 }.frame(maxWidth: 140)
            }
            Panel { HStack { NumField(label: "التركيز", text: $focus, suffix: "دقيقة"); NumField(label: "الاستراحة", text: $rest, suffix: "دقيقة") }; LabelValue(label: "جلسات مكتملة", value: "\(sessions)", strong: true) }
            Hint(text: "تبقى الشاشة مضاءة أثناء الجلسة، ويصدر تنبيه عند انتهاء كل فترة.")
        }
        .onAppear { sessions = Int(store.obj("timer").d("today")) }
        .onChange(of: focus) { if !running && !onBreak { left = max(Int(focus.num), 1) * 60 } }
        .onReceive(tick) { _ in
            guard running else { return }
            if left > 0 { left -= 1; return }
            AudioServicesPlaySystemSound(1005)
            if !onBreak { sessions += 1; store.saveObj("timer", ["today": sessions]); store.used(tool.id) }
            onBreak.toggle(); left = max(Int((onBreak ? rest : focus).num), 1) * 60
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

struct FlashcardsTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var cards: [Rec] = []; @State var front = ""; @State var back = ""; @State var studying = false; @State var flipped = false
    var body: some View {
        let due = cards.sorted { (Int($0.d("box")), $0.d("seen")) < (Int($1.d("box")), $1.d("seen")) }
        ToolScreen(tool: tool) {
            if !studying {
                Panel(title: "بطاقة جديدة") {
                    Field(label: "الوجه (سؤال أو كلمة)", text: $front); Field(label: "الظهر (الإجابة)", text: $back, lines: 2)
                    PrimaryButton(title: "إضافة البطاقة", icon: "plus", enabled: !front.isEmpty && !back.isEmpty) { save(cards + [["id": Date().timeIntervalSince1970 * 1000, "f": front, "b": back, "box": 1.0]]); front = ""; back = "" }
                }
                if cards.isEmpty { EmptyStateView(icon: "rectangle.on.rectangle.angled", title: "لا توجد بطاقات", text: "أضف كلمات أو أسئلة لتراجعها بطريقة الصناديق المتباعدة.") }
                else {
                    PrimaryButton(title: "ابدأ المراجعة (\(cards.count))", icon: "play.fill") { studying = true; flipped = false }
                    Panel(title: "البطاقات") {
                        ForEach(cards, id: \.id) { c in
                            HStack { VStack(alignment: .leading) { Text(c.s("f")).font(.plex(.subheadline, .semibold)); Text("الصندوق \(Int(max(c.d("box"), 1))) من 5").font(.plex(.caption)).foregroundStyle(.secondary) }
                                Spacer(); Button(role: .destructive) { save(cards.filter { $0.id != c.id }) } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
                        }
                    }
                }
            } else if let c = due.first {
                Button { withAnimation { flipped.toggle() } } label: {
                    Text(flipped ? c.s("b") : c.s("f")).font(.plex(.title2, .bold)).foregroundStyle(.white).multilineTextAlignment(.center).padding(24)
                        .frame(maxWidth: .infinity, minHeight: 260).background(flipped ? Brand.ink : Brand.lapis, in: RoundedRectangle(cornerRadius: 22))
                }.buttonStyle(.plain).accessibilityHint("اضغط لقلب البطاقة")
                Text(flipped ? "هل عرفت الإجابة؟" : "اضغط البطاقة لرؤية الإجابة").font(.plex(.subheadline)).frame(maxWidth: .infinity)
                if flipped {
                    HStack {
                        SecondaryButton(title: "لم أعرفها", icon: "xmark") { update(c, box: 1) }
                        PrimaryButton(title: "عرفتها", icon: "checkmark") { update(c, box: min(Int(max(c.d("box"), 1)) + 1, 5)); store.used(tool.id) }
                    }
                }
                Button("إنهاء المراجعة") { studying = false }.frame(maxWidth: .infinity)
            }
        }
        .onAppear { cards = store.list("flashcards") }
    }
    private func update(_ c: Rec, box: Int) { save(cards.map { $0.id == c.id ? $0.merging(["box": Double(box), "seen": Date().timeIntervalSince1970] as Rec) { $1 } : $0 }); flipped = false }
    private func save(_ l: [Rec]) { cards = l; store.saveList("flashcards", l) }
}

struct CertificateTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    let kinds = ["شهادة شكر وتقدير", "شهادة تفوق", "شهادة إتمام", "شهادة حضور"]
    let colors: [(String, UIColor)] = [("أزرق", UIColor(red: 0.18, green: 0.29, blue: 1, alpha: 1)), ("ذهبي", UIColor(red: 0.72, green: 0.53, blue: 0.04, alpha: 1)), ("أخضر", UIColor(red: 0.08, green: 0.5, blue: 0.24, alpha: 1)), ("عنابي", UIColor(red: 0.5, green: 0.11, blue: 0.23, alpha: 1))]
    @State var kind = 0; @State var name = ""; @State var reason = ""; @State var org = ""; @State var signer = ""; @State var date = Date(); @State var color = 0; @State var result: [URL] = []
    @State var bulk = false; @State var names = ""; @State var importing = false
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Picker("النوع", selection: $kind) { ForEach(kinds.indices, id: \.self) { Text(kinds[$0]).tag($0) } }
                Field(label: "اسم المكرم", text: $name); Field(label: "السبب أو الإنجاز", text: $reason, lines: 2); Field(label: "الجهة المانحة", text: $org); Field(label: "اسم الموقع وصفته", text: $signer)
                DatePicker("التاريخ", selection: $date, displayedComponents: .date)
                HStack { ForEach(colors.indices, id: \.self) { i in Chip(text: colors[i].0, selected: i == color) { color = i } } }
            }
            Panel {
                Toggle("شهادات جماعية من قائمة أسماء", isOn: $bulk).font(.plex(.subheadline)).accessibilityIdentifier("bulkToggle")
                if bulk {
                    Field(label: "الأسماء (اسم في كل سطر)", text: $names, lines: 6)
                    SecondaryButton(title: "استيراد الأسماء من Excel أو CSV", icon: "tablecells") { importing = true }
                    let n = nameList.count
                    Text("\(n) اسما\(Plus.shared.unlocked ? "" : " • المجاني حتى 10 أسماء في المرة")").font(.plex(.caption)).foregroundStyle(Brand.text2)
                }
            }
            TemplatePanel(styles: false)
            PrimaryButton(title: bulk ? "إنشاء الشهادات" : "إنشاء الشهادة", icon: "rosette", enabled: bulk ? !nameList.isEmpty : !name.isEmpty) {
                let list = bulk ? nameList : [name.trimmingCharacters(in: .whitespaces)]
                if list.count > 10 && !Plus.shared.allow(.files) { return }
                let b = Templates.apply(DocBuilder(landscape: true)); b.border = colors[color].1; b.layoutStyle = 0; b.accent = colors[color].1; b.pageNumbers = false
                for (i, who) in list.enumerated() {
                    if i > 0 { b.add(.pageBreak) }
                    b.add([.space(30), .para(org, size: 14, center: true, color: DocBuilder.muted), .para(kinds[kind], size: 34, bold: true, center: true, color: colors[color].1), .space(10),
                           .para("يسرنا أن نقدم هذه الشهادة إلى", size: 14, center: true), .para(who, size: 28, bold: true, center: true)])
                    if !reason.isEmpty { b.add(.para(reason, size: 14, center: true)) }
                    b.add([.space(30), .para("\(dayFmt.string(from: date))\n\(signer)\n...............................", size: 12, center: true, color: DocBuilder.muted)])
                }
                let file = list.count > 1 ? "شهادات-\(kinds[kind])-\(list.count).pdf" : "شهادة-\(list[0]).pdf"
                result = [try? b.save(to: FilesX.outDir().appendingPathComponent(file))].compactMap { $0 }; store.used(tool.id, list[0])
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .data, .commaSeparatedText, .plainText]) { r in
                if case .success(let u) = r { names = readNames(u).joined(separator: "\n") }
            }
            if !result.isEmpty { ResultFiles(files: result) }
        }
    }
}

extension CertificateTool {
    var nameList: [String] { var seen = Set<String>(); return names.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && seen.insert($0).inserted } }
}

struct CalendarTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State var selected = Calendar.current.component(.day, from: Date())
    typealias Ev = (String, Double, String)
    func allEvents() -> [Ev] {
        var e: [Ev] = []
        for r in store.list("tasks") where r.d("due") > 0 { e.append((r.s("title"), r.d("due"), "مهمة")) }
        for r in store.list("exams") { e.append((r.s("subject"), r.d("at"), "اختبار")) }
        for r in store.list("homework") where r.d("due") > 0 { e.append((r.s("title"), r.d("due"), "واجب")) }
        for r in store.list("documents") { e.append((r.s("name"), r.d("expiry"), "وثيقة")) }
        for r in store.list("reminders") { e.append((r.s("title"), r.d("at"), "تذكير")) }
        return e
    }
    var body: some View {
        let cal = Calendar(identifier: .gregorian)
        let events = allEvents()
        let len = cal.range(of: .day, in: .month, for: month)!.count, first = cal.component(.weekday, from: month) - 1
        let on: (Int) -> [Ev] = { d in events.filter { let e = Date(timeIntervalSince1970: $0.1); return cal.isDate(e, equalTo: month, toGranularity: .month) && cal.component(.day, from: e) == d } }
        ToolScreen(tool: tool) {
            HStack {
                Button { month = cal.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.forward") }.accessibilityLabel("السابق")
                Text("\(Hijri.gMonths[cal.component(.month, from: month) - 1]) \(String(cal.component(.year, from: month)))").font(.plex(.title3, .semibold)).frame(maxWidth: .infinity)
                Button { month = cal.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.backward") }.accessibilityLabel("التالي")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"], id: \.self) { Text($0).font(.plex(.caption2)) }
                ForEach(0..<(first + len), id: \.self) { i in
                    let d = i - first + 1
                    if d < 1 { Color.clear.frame(height: 40) } else {
                        Button { selected = d } label: {
                            Text("\(d)").font(.plex(.subheadline)).frame(maxWidth: .infinity, minHeight: 40)
                                .background(d == selected ? Brand.lapis : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(d == selected ? .white : .primary)
                                .overlay(alignment: .bottom) { if !on(d).isEmpty { Circle().fill(Brand.saffron).frame(width: 5, height: 5).padding(.bottom, 4) } }
                        }.buttonStyle(.plain)
                    }
                }
            }
            Panel(title: "مواعيد \(selected) \(Hijri.gMonths[cal.component(.month, from: month) - 1])") {
                let list = on(selected)
                if list.isEmpty { Text("لا شيء في هذا اليوم. أضف من أدوات المهام والتذكيرات والاختبارات والوثائق.").font(.plex(.caption)).foregroundStyle(.secondary) }
                ForEach(list.indices, id: \.self) { LabelValue(label: list[$0].0, value: list[$0].2) }
            }
        }
    }
}
