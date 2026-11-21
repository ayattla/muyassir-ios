import SwiftUI
import UserNotifications

enum FType { case text, multi, num, date, datetime, choice([String]), bool }
struct FieldSpec { let key: String; let label: String; var type: FType = .text; var required = false }

let dayFmt: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "ar"); f.dateFormat = "EEEE d/M/yyyy"; return f }()
let dtFmt: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "ar"); f.dateFormat = "EEEE d/M/yyyy  h:mm a"; return f }()
func daysUntil(_ t: Double) -> Int { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: t))).day ?? 0 }
func whenText(_ t: Double) -> String { let d = daysUntil(t); return d == 0 ? "اليوم" : d == 1 ? "غدًا" : d == -1 ? "أمس" : d > 0 ? "بعد \(d) يوم" : "منذ \(-d) يوم" }

extension Dictionary where Key == String, Value == Any {
    func s(_ k: String) -> String { self[k] as? String ?? "" }
    func d(_ k: String) -> Double { self[k] as? Double ?? (self[k] as? Int).map(Double.init) ?? 0 }
    func b(_ k: String) -> Bool { self[k] as? Bool ?? false }
    var id: Double { d("id") }
}

enum Notify {
    static func schedule(id: String, at: Date, title: String, body: String) {
        guard at > Date() else { return }
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            c.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }
    static func cancel(_ id: String) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id]) }
    /// Completion notice for long operations; shown only if the user already allowed notifications.
    static func done(_ tool: String, _ n: Int) {
        let c = UNUserNotificationCenter.current()
        c.getNotificationSettings { st in
            guard st.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent(); content.title = "اكتملت العملية: \(tool)"; content.body = "\(n) \(n == 1 ? "ملف جاهز" : "ملفات جاهزة") في مُيسّر"
            c.add(UNNotificationRequest(identifier: "done-\(UUID().uuidString)", content: content, trigger: nil))
        }
    }
}

/// Generic on-device list: add / edit / delete / tick, optional reminders and Excel export.
struct RecordList<Header: View>: View {
    let tool: Tool
    let storeName: String
    let fields: [FieldSpec]
    let title: (Rec) -> String
    var subtitle: (Rec) -> String = { _ in "" }
    var doneKey: String? = nil
    var sort: ([Rec]) -> [Rec] = { $0 }
    var reminder: ((Rec) -> (Date, String)?)? = nil
    @ViewBuilder var header: ([Rec]) -> Header
    var emptyText = "أضف أول عنصر بالزر أدناه"

    @EnvironmentObject var store: Store
    @State var items: [Rec] = []
    @State var editing: Rec?
    @State var exportURL: URL?

    var body: some View {
        ToolScreen(tool: tool) {
            header(items)
            HStack {
                PrimaryButton(title: "إضافة", icon: "plus") { editing = ["id": Date().timeIntervalSince1970 * 1000] }
            }
            if !items.isEmpty {
                HStack {
                    SecondaryButton(title: "تصدير Excel", icon: "tablecells") { if Plus.shared.allow(.export) { exportURL = export() } }
                    SecondaryButton(title: "تصدير PDF", icon: "doc.richtext") { if Plus.shared.allow(.export) { exportURL = exportPdf() } }
                    PlusBadge()
                }
            }
            if items.isEmpty { EmptyStateView(icon: tool.icon, title: "لا توجد عناصر بعد", text: emptyText) }
            ForEach(sort(items), id: \.id) { o in
                Panel {
                    HStack {
                        if let k = doneKey {
                            Button { save(items.map { $0.id == o.id ? $0.merging([k: !o.b(k)] as Rec) { $1 } : $0 }) } label: { Image(systemName: o.b(k) ? "checkmark.circle.fill" : "circle").font(.title3) }
                                .buttonStyle(.plain).foregroundStyle(o.b(k) ? Brand.mint : .secondary).accessibilityLabel(o.b(k) ? "منجزة" : "غير منجزة")
                        }
                        Button { editing = o } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title(o)).font(.plex(.subheadline, .semibold)).strikethrough(doneKey.map { o.b($0) } ?? false).foregroundStyle(.primary)
                                let s = subtitle(o); if !s.isEmpty { Text(s).font(.plex(.caption)).foregroundStyle(.secondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                        Button(role: .destructive) { Notify.cancel("\(Int(o.id))"); save(items.filter { $0.id != o.id }) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).accessibilityLabel("حذف")
                    }
                }
            }
        }
        .onAppear { items = store.list(storeName) }
        .sheet(item: Binding(get: { editing.map { EditBox(rec: $0) } }, set: { editing = $0?.rec })) { box in
            RecordForm(fields: fields, rec: box.rec, isNew: !items.contains { $0.id == box.rec.id }) { r in
                save(items.filter { $0.id != r.id } + [r])
                if let rr = reminder?(r) { Notify.schedule(id: "\(Int(r.id))", at: rr.0, title: title(r), body: rr.1) }
                store.used(tool.id, title(r)); editing = nil
            } cancel: { editing = nil }
        }
        .sheet(item: Binding(get: { exportURL.map { EditURL(url: $0) } }, set: { exportURL = $0?.url })) { ShareSheet(items: [$0.url]) }
    }

    private func save(_ l: [Rec]) { items = l; store.saveList(storeName, l) }

    private func exportPdf() -> URL? {
        let r = rows()
        return exportTablePdf(tool.title, header: r[0], rows: Array(r.dropFirst()))
    }

    private func export() -> URL? {
        let u = FilesX.outDir().appendingPathComponent("\(tool.title).xlsx")
        try? Office.writeXlsx(u, [(tool.title, rows())]); return u
    }

    private func rows() -> [[String]] {
        [fields.map(\.label)] + items.map { o in fields.map { f -> String in
            switch f.type {
            case .date: return o.d(f.key) > 0 ? dayFmt.string(from: Date(timeIntervalSince1970: o.d(f.key))) : ""
            case .datetime: return o.d(f.key) > 0 ? dtFmt.string(from: Date(timeIntervalSince1970: o.d(f.key))) : ""
            case .bool: return o.b(f.key) ? "نعم" : "لا"
            default: return o.s(f.key)
            }
        } }
    }
}

struct EditBox: Identifiable { let rec: Rec; var id: Double { rec.id } }
struct EditURL: Identifiable { let url: URL; var id: String { url.path } }

extension RecordList where Header == EmptyView {
    init(tool: Tool, storeName: String, fields: [FieldSpec], title: @escaping (Rec) -> String, subtitle: @escaping (Rec) -> String = { _ in "" }, doneKey: String? = nil,
         sort: @escaping ([Rec]) -> [Rec] = { $0 }, reminder: ((Rec) -> (Date, String)?)? = nil) {
        self.init(tool: tool, storeName: storeName, fields: fields, title: title, subtitle: subtitle, doneKey: doneKey, sort: sort, reminder: reminder, header: { _ in EmptyView() })
    }
}

struct RecordForm: View {
    let fields: [FieldSpec]
    @State var rec: Rec
    let isNew: Bool
    let save: (Rec) -> Void
    let cancel: () -> Void
    @State var error: String?

    var body: some View {
        NavigationStack {
            Form {
                ForEach(fields.indices, id: \.self) { i in
                    let f = fields[i]
                    switch f.type {
                    case .text: TextField(f.label, text: str(f.key))
                    case .multi: TextField(f.label, text: str(f.key), axis: .vertical).lineLimit(3...8)
                    case .num: TextField(f.label, text: str(f.key)).keyboardType(.decimalPad)
                    case .date: DatePicker(f.label, selection: date(f.key), displayedComponents: .date)
                    case .datetime: DatePicker(f.label, selection: date(f.key))
                    case let .choice(opts): Picker(f.label, selection: Binding(get: { rec.s(f.key).isEmpty ? opts[0] : rec.s(f.key) }, set: { rec[f.key] = $0 })) { ForEach(opts, id: \.self) { Text($0) } }
                    case .bool: Toggle(f.label, isOn: Binding(get: { rec.b(f.key) }, set: { rec[f.key] = $0 }))
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .font(.plex(.body))
            .navigationTitle(isNew ? "إضافة" : "تعديل").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء", action: cancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        if fields.contains(where: { $0.required && rec.s($0.key).isEmpty && rec.d($0.key) == 0 }) { error = "أكمل الحقول المطلوبة"; return }
                        for f in fields { if case let .choice(o) = f.type, rec.s(f.key).isEmpty { rec[f.key] = o[0] }
                            if case .date = f.type, rec.d(f.key) == 0 { rec[f.key] = Date().timeIntervalSince1970 } }
                        save(rec)
                    }.fontWeight(.semibold)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func str(_ k: String) -> Binding<String> { Binding(get: { rec.s(k) }, set: { rec[k] = $0 }) }
    private func date(_ k: String) -> Binding<Date> {
        Binding(get: { rec.d(k) > 0 ? Date(timeIntervalSince1970: rec.d(k)) : Date().addingTimeInterval(3600) }, set: { rec[k] = $0.timeIntervalSince1970 })
    }
}

// MARK: concrete lists

struct NotesTool: View {
    let tool: Tool
    var body: some View { LockGate(title: "المفكرة") { RecordList(tool: tool, storeName: "notes", fields: [FieldSpec(key: "title", label: "العنوان", required: true), FieldSpec(key: "body", label: "الملاحظة", type: .multi)],
        title: { $0.s("title") }, subtitle: { String($0.s("body").prefix(120)) }, sort: { $0.sorted { $0.id > $1.id } }) } }
}

private let priorities = ["عادية", "مهمة", "عاجلة"]
struct TasksTool: View {
    let tool: Tool
    var body: some View { RecordList(tool: tool, storeName: "tasks", fields: [FieldSpec(key: "title", label: "المهمة", required: true), FieldSpec(key: "priority", label: "الأولوية", type: .choice(priorities)), FieldSpec(key: "due", label: "الموعد", type: .date), FieldSpec(key: "done", label: "منجزة", type: .bool)],
        title: { $0.s("title") }, subtitle: { [$0.s("priority"), $0.d("due") > 0 ? whenText($0.d("due")) : ""].filter { !$0.isEmpty }.joined(separator: " • ") }, doneKey: "done",
        sort: { $0.sorted { ($0.b("done") ? 1 : 0, -(priorities.firstIndex(of: $0.s("priority")) ?? 0), $0.d("due")) < ($1.b("done") ? 1 : 0, -(priorities.firstIndex(of: $1.s("priority")) ?? 0), $1.d("due")) } }) }
}

struct RemindersTool: View {
    let tool: Tool
    var body: some View { RecordList(tool: tool, storeName: "reminders", fields: [FieldSpec(key: "title", label: "التذكير", required: true), FieldSpec(key: "at", label: "الوقت", type: .datetime, required: true), FieldSpec(key: "note", label: "تفاصيل")],
        title: { $0.s("title") }, subtitle: { $0.d("at") > 0 ? dtFmt.string(from: Date(timeIntervalSince1970: $0.d("at"))) : "" }, sort: { $0.sorted { $0.d("at") < $1.d("at") } },
        reminder: { (Date(timeIntervalSince1970: $0.d("at")), $0.s("note")) }) }
}

struct ExamsTool: View {
    let tool: Tool
    var body: some View {
        RecordList(tool: tool, storeName: "exams", fields: [FieldSpec(key: "subject", label: "المادة", required: true), FieldSpec(key: "at", label: "موعد الاختبار", type: .datetime, required: true), FieldSpec(key: "room", label: "القاعة/الملاحظات"), FieldSpec(key: "remind", label: "تذكير قبلها بيوم", type: .bool)],
            title: { $0.s("subject") }, subtitle: { $0.d("at") > 0 ? "\(dtFmt.string(from: Date(timeIntervalSince1970: $0.d("at")))) • \(whenText($0.d("at")))" : "" },
            sort: { $0.sorted { $0.d("at") < $1.d("at") } }, reminder: { $0.b("remind") ? (Date(timeIntervalSince1970: $0.d("at") - 86400), "اختبارك غدًا") : nil },
            header: { list in
                if let n = list.filter({ $0.d("at") > Date().timeIntervalSince1970 }).min(by: { $0.d("at") < $1.d("at") }) { ResultCard(main: ("أقرب اختبار", n.s("subject")), rows: [("الموعد", whenText(n.d("at")))]) }
            })
    }
}

struct HomeworkTool: View {
    let tool: Tool
    var body: some View { RecordList(tool: tool, storeName: "homework", fields: [FieldSpec(key: "subject", label: "المادة", required: true), FieldSpec(key: "title", label: "الواجب", required: true), FieldSpec(key: "due", label: "موعد التسليم", type: .date), FieldSpec(key: "done", label: "سُلّم", type: .bool)],
        title: { "\($0.s("subject")): \($0.s("title"))" }, subtitle: { $0.d("due") > 0 ? "التسليم \(whenText($0.d("due")))" : "" }, doneKey: "done",
        sort: { $0.sorted { ($0.b("done") ? 1 : 0, $0.d("due")) < ($1.b("done") ? 1 : 0, $1.d("due")) } }) }
}

struct DocumentsTool: View {
    let tool: Tool
    var body: some View {
        LockGate(title: "الوثائق") { RecordList(tool: tool, storeName: "documents", fields: [FieldSpec(key: "name", label: "اسم الوثيقة أو الموعد", required: true),
            FieldSpec(key: "kind", label: "النوع", type: .choice(["هوية وطنية", "جواز سفر", "إقامة", "رخصة قيادة", "استمارة مركبة", "تأمين", "عقد إيجار", "موعد", "أخرى"])),
            FieldSpec(key: "expiry", label: "تاريخ الانتهاء أو الموعد", type: .date, required: true), FieldSpec(key: "days", label: "التذكير قبل (أيام)", type: .num), FieldSpec(key: "note", label: "ملاحظة")],
            title: { $0.s("name") }, subtitle: { "\($0.s("kind")) • \(whenText($0.d("expiry")))" }, sort: { $0.sorted { $0.d("expiry") < $1.d("expiry") } },
            reminder: { r in (Date(timeIntervalSince1970: r.d("expiry") - (r.s("days").num > 0 ? r.s("days").num : 30) * 86400).addingTimeInterval(9 * 3600), "تنتهي \(r.s("kind")) قريبًا — جدّدها عبر المنصة الرسمية") },
            header: { list in
                if !list.isEmpty { ResultCard(main: nil, rows: [("تنتهي خلال 30 يومًا", "\(list.filter { (0...30).contains(daysUntil($0.d("expiry"))) }.count)"), ("منتهية", "\(list.filter { daysUntil($0.d("expiry")) < 0 }.count)")]) }
                Hint(text: "لا تكتب أرقام الوثائق الكاملة. البيانات تبقى على جهازك فقط. التجديد يتم عبر أبشر أو المنصة المختصة.")
            }) }
    }
}

let expenseCats = ["طعام", "مواصلات", "سكن", "فواتير", "تسوق", "صحة", "تعليم", "ترفيه", "أخرى"]
func thisMonth(_ l: [Rec]) -> [Rec] {
    let c = Calendar.current
    return l.filter { let d = Date(timeIntervalSince1970: $0.d("date") > 0 ? $0.d("date") : $0.id / 1000); return c.isDate(d, equalTo: Date(), toGranularity: .month) }
}

struct ExpensesTool: View {
    let tool: Tool
    var body: some View {
        RecordList(tool: tool, storeName: "expenses", fields: [FieldSpec(key: "title", label: "البند", required: true), FieldSpec(key: "amount", label: "المبلغ", type: .num, required: true), FieldSpec(key: "cat", label: "الفئة", type: .choice(expenseCats)), FieldSpec(key: "date", label: "التاريخ", type: .date)],
            title: { "\($0.s("title")) — \(money($0.s("amount").num))" }, subtitle: { "\($0.s("cat")) • \($0.d("date") > 0 ? dayFmt.string(from: Date(timeIntervalSince1970: $0.d("date"))) : "")" },
            sort: { $0.sorted { $0.d("date") > $1.d("date") } },
            header: { list in
                let m = thisMonth(list)
                if !list.isEmpty { ResultCard(main: ("مصروف هذا الشهر", money(m.reduce(0) { $0 + $1.s("amount").num })), rows: Dictionary(grouping: m) { $0.s("cat") }.map { ($0.key, money($0.value.reduce(0) { $0 + $1.s("amount").num })) }.sorted { $0.1 > $1.1 }) }
            })
    }
}

struct BudgetTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var income = ""
    @State var limits: [String: String] = [:]
    var body: some View {
        let spent = Dictionary(grouping: thisMonth(store.list("expenses"))) { $0.s("cat") }.mapValues { $0.reduce(0) { $0 + $1.s("amount").num } }
        let total = spent.values.reduce(0, +)
        ToolScreen(tool: tool) {
            Panel { NumField(label: "الدخل الشهري", text: $income, suffix: "ريال") }
            ResultCard(main: ("المتبقي هذا الشهر", money(income.num - total)), rows: [("المصروف", money(total)), ("الحدود المخططة", money(limits.values.reduce(0) { $0 + $1.num }))], note: "المصروفات تُسجَّل من أداة «إدارة المصروفات».")
            Panel(title: "الحد الشهري لكل فئة") {
                ForEach(expenseCats, id: \.self) { c in
                    let s = spent[c] ?? 0, lim = limits[c]?.num ?? 0
                    HStack {
                        VStack(alignment: .leading) {
                            Text(c).font(.plex(.subheadline, .semibold))
                            if lim > 0 { ProgressView(value: min(s / lim, 1)).tint(s > lim ? .red : Brand.lapis) }
                            Text("صُرف \(money(s))").font(.plex(.caption)).foregroundStyle(.secondary)
                        }
                        NumField(label: "الحد", text: Binding(get: { limits[c] ?? "" }, set: { limits[c] = $0 })).frame(width: 130)
                    }
                }
            }
        }
        .onAppear { let o = store.obj("budget"); income = o.s("income"); limits = Dictionary(uniqueKeysWithValues: expenseCats.map { ($0, o.s("l_\($0)")) }) }
        .onChange(of: income) { persist() }
        .onChange(of: limits) { persist() }
    }
    private func persist() { var o: Rec = ["income": income]; limits.forEach { o["l_\($0.key)"] = $0.value }; store.saveObj("budget", o) }
}

struct AttendanceTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var students: [String] = []
    @State var sessions: [Rec] = []
    @State var newName = ""
    @State var absent = Set<String>()
    @State var date = Date()
    @State var exportURL: URL?
    var body: some View {
        ToolScreen(tool: tool) {
            Panel(title: "الطلاب (\(students.count))") {
                HStack { Field(label: "اسم الطالب (أو عدة أسماء بفاصلة)", text: $newName); Button { addNames() } label: { Image(systemName: "person.badge.plus").font(.title3) }.accessibilityLabel("إضافة") }
            }
            if !students.isEmpty {
                Panel(title: "تسجيل حصة") {
                    DatePicker("التاريخ", selection: $date, displayedComponents: .date)
                    Text("علّم الغائبين:").font(.plex(.subheadline, .semibold))
                    ForEach(students, id: \.self) { s in
                        HStack {
                            Button { if absent.contains(s) { absent.remove(s) } else { absent.insert(s) } } label: { Label(s, systemImage: absent.contains(s) ? "xmark.circle.fill" : "checkmark.circle") }
                                .foregroundStyle(absent.contains(s) ? .red : Brand.mint).buttonStyle(.plain)
                            Spacer()
                            Button(role: .destructive) { students.removeAll { $0 == s }; saveStudents() } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("حذف الطالب")
                        }
                    }
                    PrimaryButton(title: "حفظ الحصة (\(students.count - absent.count) حاضر)", icon: "checkmark") {
                        sessions.append(["id": Date().timeIntervalSince1970 * 1000, "date": date.timeIntervalSince1970, "absent": Array(absent)]); store.saveList("attendance", sessions); absent = []; store.used(tool.id)
                    }
                }
            }
            if !sessions.isEmpty {
                Panel(title: "ملخص الغياب (\(sessions.count) حصة)") {
                    ForEach(students, id: \.self) { s in
                        let c = sessions.filter { ($0["absent"] as? [String] ?? []).contains(s) }.count
                        LabelValue(label: s, value: "\(c) غياب • \(fmt(100 * Double(sessions.count - c) / Double(sessions.count), 0))% حضور")
                    }
                    SecondaryButton(title: "تصدير Excel وPDF", icon: "tablecells") {
                        guard Plus.shared.allow(.export) else { return }
                        let ds = sessions.sorted { $0.d("date") < $1.d("date") }
                        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
                        let header = ["الطالب"] + ds.map { f.string(from: Date(timeIntervalSince1970: $0.d("date"))) } + ["الغياب"]
                        let rows = students.map { s -> [String] in let marks = ds.map { ($0["absent"] as? [String] ?? []).contains(s) ? "غائب" : "حاضر" }; return [s] + marks + ["\(marks.filter { $0 == "غائب" }.count)"] }
                        let u = FilesX.outDir().appendingPathComponent("سجل-الحضور.xlsx"); try? Office.writeXlsx(u, [("الحضور", [header] + rows)])
                        let summary = students.map { s -> [String] in let c = sessions.filter { ($0["absent"] as? [String] ?? []).contains(s) }.count; return [s, "\(c)", "\(fmt(100 * Double(sessions.count - c) / Double(sessions.count), 0))%"] }
                        _ = exportTablePdf("سجل الحضور", header: ["الطالب", "الغياب", "نسبة الحضور"], rows: summary, dir: u.deletingLastPathComponent())
                        exportURL = u // the PDF summary is saved next to it (also listed in «نشاطي» › الملفات)
                    }
                }
            }
        }
        .onAppear { students = store.list("students").map { $0.s("name") }; sessions = store.list("attendance") }
        .sheet(item: Binding(get: { exportURL.map { EditURL(url: $0) } }, set: { exportURL = $0?.url })) { ShareSheet(items: [$0.url]) }
    }
    private func addNames() {
        let names = newName.split(whereSeparator: { $0 == "," || $0 == "،" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !students.contains($0) }
        students += names; newName = ""; saveStudents()
    }
    private func saveStudents() { store.saveList("students", students.map { ["name": $0] }) }
}

/// A simple table PDF for exported records.
func exportTablePdf(_ title: String, header: [String], rows: [[String]], dir: URL? = nil) -> URL? {
    let b = DocBuilder(landscape: header.count > 5)
    b.add(.title(title, sub: dayFmt.string(from: Date()))); b.add(.table(header: header, rows: rows))
    return try? b.save(to: (dir ?? FilesX.outDir()).appendingPathComponent("\(title).pdf"))
}
