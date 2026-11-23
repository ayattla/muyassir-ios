import SwiftUI

/// «يومي»: what matters today at a glance. Every card shows only when it has something to say. Mirrors Android's TodayScreen.
struct TodayView: View {
    let open: (String) -> Void
    let openTab: (String) -> Void
    @ObservedObject private var daily = Daily.shared
    @ObservedObject private var lock = AppLock.shared
    @AppStorage("name") private var name = ""
    @State private var editing = false
    @State private var tick = 0
    init(open: @escaping (String) -> Void, openTab: @escaping (String) -> Void) { self.open = open; self.openTab = openTab }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let now = ctx.date
            ScrollView {
                VStack(spacing: Space.m) {
                    header(now)
                    if !daily.setupDone || editing { SetupCard(first: !daily.setupDone) { editing = false } }
                    if daily.showPrayer { PrayerCard(now: now) }
                    datesRow(now)
                    TasksCard(now: now, open: open, changed: { tick += 1 }).id(tick)
                    ForEach(daily.roles, id: \.self) { RoleCard(role: $0, now: now, open: open) }
                    if daily.showAdhkar && daily.showPrayer { AdhkarCard(now: now) }
                    Button { openTab("assistant") } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: "sparkles").foregroundStyle(Brand.accent)
                            Text("اكتب ما تريد… مثل: حوّل هذه الصور إلى PDF").font(.plex(.subheadline)).foregroundStyle(Brand.text2).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Space.l).frame(minHeight: 52)
                        .background(Brand.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Brand.borderStrong, lineWidth: 1))
                    }.buttonStyle(PressStyle()).accessibilityIdentifier("todayAssistant")
                    Button("كل الأدوات") { openTab("home") }.font(.plex(.subheadline, .semibold)).tint(Brand.accent).frame(minHeight: 44)
                }
                .padding(.horizontal, Space.l).padding(.bottom, Space.xxl).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("today")
        }
        .background(Brand.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { daily.syncWidget() }
    }

    private func header(_ now: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting(now)).font(.plex(.subheadline)).foregroundStyle(Brand.text2)
                Text("يومي").font(.plex(.title2, .bold)).foregroundStyle(Brand.text1)
            }
            Spacer()
            Button { withAnimation(.snappy) { editing.toggle() } } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 18)).foregroundStyle(Brand.text1).frame(width: 44, height: 44)
            }.accessibilityLabel("تخصيص يومي").accessibilityIdentifier("todaySettings")
        }.padding(.top, Space.l)
    }

    private func greeting(_ d: Date) -> String {
        let h = KSA.hour(d)
        let base = (4...11).contains(h) ? "صباح الخير" : (12...16).contains(h) ? "طاب يومك" : "مساء الخير"
        return name.isEmpty ? base : "\(base)، \(name)"
    }

    private struct Due: Identifiable { let id = UUID(); let days: Int; let title: String; let warn: Bool; let tool: String? }

    @ViewBuilder private func datesRow(_ now: Date) -> some View {
        let dues = upcoming(now)
        if !dues.isEmpty {
            VStack(spacing: Space.s) {
                Text("مواعيد قريبة").font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1)
                HStack(spacing: Space.s) {
                    ForEach(dues) { d in
                        Button { if let t = d.tool { open(t) } } label: {
                            VStack(spacing: 2) {
                                Text(d.days == 0 ? "اليوم" : "\(d.days)").font(.plex(d.days == 0 ? .title3 : .title, .bold))
                                    .foregroundStyle(d.warn ? Brand.dyn(0xA05A00, 0xF2B01E) : Brand.accent)
                                if d.days > 0 { Text((3...10).contains(d.days) ? "أيام" : "يومًا").font(.plex(.caption2)).foregroundStyle(Brand.text2) }
                                Text(d.title).font(.plex(.footnote, .semibold)).foregroundStyle(Brand.text1).multilineTextAlignment(.center).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, Space.m).padding(.horizontal, Space.s)
                            .background(d.warn ? Brand.dyn(0xFFF6E6, 0x2E2414) : Brand.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(d.warn ? Brand.dyn(0xEBC48A, 0x5A4420) : Brand.border, lineWidth: 1))
                        }.buttonStyle(PressStyle()).disabled(d.tool == nil)
                    }
                }.accessibilityElement(children: .contain).accessibilityIdentifier("dates")
            }
        }
    }

    private func upcoming(_ now: Date) -> [Due] {
        var out: [Due] = []
        for r in daily.payRules() {
            let (d, _) = PayDays.next(r, now)
            out.append(Due(days: d, title: r.title, warn: false, tool: r.id == "gov" || r.id == "custom" ? "salary" : nil))
        }
        if daily.showDocs {
            let docs = Store.shared.list("documents").filter { $0.d("expiry") > 0 }.map { ($0, daysUntil($0.d("expiry"))) }.filter { (0...60).contains($0.1) }
            if let best = docs.min(by: { $0.1 < $1.1 }) {
                let (o, d) = best
                out.append(Due(days: d, title: lock.enabled ? "وثيقة" : o.s("name"), warn: d <= 30, tool: "documents"))
            }
        }
        let t = now.timeIntervalSince1970
        if let e = Store.shared.list("exams").filter({ $0.d("at") > t }).min(by: { $0.d("at") < $1.d("at") }) {
            let d = daysUntil(e.d("at")); if d <= 14 { out.append(Due(days: d, title: "اختبار \(e.s("subject"))", warn: false, tool: "exams")) }
        }
        return Array(out.sorted { $0.days < $1.days }.prefix(3))
    }
}

// MARK: setup

private struct SetupCard: View {
    let first: Bool
    let done: () -> Void
    @ObservedObject private var daily = Daily.shared
    @State private var day = ""
    var body: some View {
        VStack(spacing: Space.m) {
            Text(first ? "نرتّب لك يومك" : "تخصيص يومي").font(.plex(.title3, .bold)).foregroundStyle(Brand.text1)
            Text("اختر ما يصفك، ويمكنك اختيار أكثر من دور. كل ما تختاره يبقى على جهازك.").font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)], spacing: Space.s) {
                ForEach(Tools.roles, id: \.0) { id, label in
                    let on = daily.roles.contains(id)
                    Button { daily.toggleRole(id) } label: {
                        Text(label).font(.plex(.subheadline, .semibold)).foregroundStyle(on ? Brand.accent : Brand.text1)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(on ? Brand.accentSoft : Brand.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(on ? Brand.accent : Brand.border, lineWidth: on ? 2 : 1))
                    }
                    .buttonStyle(PressStyle()).accessibilityIdentifier("role-\(id)").accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            VStack(spacing: 0) {
                row("المدينة لمواقيت الصلاة") {
                    Picker("المدينة", selection: Binding(get: { daily.city }, set: { daily.chooseCity($0) })) { ForEach(Cities.all) { Text($0.name).tag($0.id) } }
                        .accessibilityIdentifier("todayCity")
                }
                Divider()
                row("موعد راتبك") {
                    Picker("موعد راتبك", selection: Binding(get: { daily.salary }, set: { daily.setSalary($0) })) {
                        Text("راتب الدولة (يوم 27)").tag("gov"); Text("يوم أحدده").tag("custom"); Text("لا أريد").tag("none")
                    }
                }
                if daily.salary == "custom" {
                    NumField(label: "يوم الراتب من الشهر (1 إلى 31)", text: Binding(get: { day }, set: { day = $0; if let d = Int($0) { daily.setSalary("custom", day: d) } }))
                        .padding(.vertical, Space.s)
                }
                Divider()
                toggle("مواقيت الصلاة", daily.showPrayer, daily.setPrayer)
                toggle("حساب المواطن (يوم 10)", daily.showCitizen, daily.setCitizen)
                toggle("التقاعد والضمان (يوم 1)", daily.showPension, daily.setPension)
                toggle("انتهاء الوثائق", daily.showDocs, daily.setDocs)
                toggle("تذكير الأذكار من آيات تتلى", daily.showAdhkar, daily.setAdhkar)
            }
            PrimaryButton(title: first ? "ابدأ يومي" : "تم") { withAnimation(.snappy) { daily.finishSetup(); done() } }.accessibilityIdentifier("todayStart")
        }
        .padding(Space.l).card()
        .onAppear { day = "\(daily.salaryDay)" }
        .accessibilityElement(children: .contain).accessibilityIdentifier("todaySetup")
    }
    private func row<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        HStack { Text(label).font(.plex(.subheadline)).foregroundStyle(Brand.text1); Spacer(); c().tint(Brand.accent) }.frame(minHeight: 48)
    }
    private func toggle(_ label: String, _ v: Bool, _ set: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { v }, set: set)) { Text(label).font(.plex(.subheadline)).foregroundStyle(Brand.text1) }.tint(Brand.accent).frame(minHeight: 48)
    }
}

// MARK: prayer

private struct PrayerCard: View {
    let now: Date
    @ObservedObject private var daily = Daily.shared
    var body: some View {
        let city = Cities.byId(daily.city)
        let times = PrayerTimes.today(city, now)
        let tomorrow = PrayerTimes.today(city, KSA.cal.date(byAdding: .day, value: 1, to: now)!)
        let (idx, left) = PrayerTimes.next(times, nowMin: KSA.minuteOfDay(now), tomorrowFajr: tomorrow[0])
        let (y, m, d) = KSA.ymd(now)
        let h = Hijri.toHijri(y, m, d)
        let on = Brand.onAccent
        VStack(spacing: Space.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if let h { Text("\(Hijri.days[KSA.weekday(now) - 1]) \(h.d) \(Hijri.months[h.m - 1]) \(h.y)") }
                    Text("\(d) \(Hijri.gMonths[m - 1]) \(String(y))")
                }.font(.plex(.footnote)).foregroundStyle(on.opacity(0.9))
                Spacer()
                Text(city.name).font(.plex(.caption, .semibold)).foregroundStyle(on).padding(.horizontal, 10).padding(.vertical, 4).background(on.opacity(0.16), in: Capsule())
            }
            VStack(spacing: 0) {
                Text("صلاة \(PrayerTimes.names[idx]) بعد").font(.plex(.subheadline)).foregroundStyle(on.opacity(0.92))
                Text(PrayerTimes.left(left)).font(.plex(.largeTitle, .bold)).foregroundStyle(on).monospacedDigit().accessibilityIdentifier("prayerLeft")
            }
            HStack(spacing: 4) {
                ForEach([0, 2, 3, 4, 5], id: \.self) { i in
                    let sel = i == idx
                    VStack(spacing: 0) {
                        Text(PrayerTimes.names[i]).font(.plex(.caption2))
                        Text(PrayerTimes.clock(times[i])).font(.plex(.subheadline, .semibold)).monospacedDigit()
                    }
                    .foregroundStyle(on.opacity(sel ? 1 : 0.75)).frame(maxWidth: .infinity).padding(.vertical, 4)
                    .background(sel ? on.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(Space.l).background(Brand.accent, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .accessibilityElement(children: .contain).accessibilityIdentifier("prayerCard")
    }
}

// MARK: tasks

private struct TasksCard: View {
    let now: Date
    let open: (String) -> Void
    let changed: () -> Void
    var body: some View {
        let cal = KSA.cal
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 0, of: now)!.timeIntervalSince1970
        let tomorrowEnd = endOfDay + 86_400
        let tasks = Array(Store.shared.list("tasks").filter { let due = $0.d("due"); return (due > 0 && due <= endOfDay) || (due == 0 && !$0.b("done")) }.prefix(5))
        let homework = Array(Store.shared.list("homework").filter { let due = $0.d("due"); return due > 0 && due <= tomorrowEnd && !$0.b("done") }.prefix(3))
        let doneCount = tasks.filter { $0.b("done") }.count
        VStack(spacing: Space.s) {
            HStack {
                Text("مهامك اليوم").font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1)
                Spacer()
                if !tasks.isEmpty { Text("\(doneCount) من \(tasks.count)").font(.plex(.caption, .medium)).foregroundStyle(Brand.text2) }
            }
            if tasks.isEmpty && homework.isEmpty {
                Text("لا مهام لليوم. أضف ما تريد إنجازه، ونعرضه هنا ونذكّرك به.").font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
            }
            ForEach(tasks.indices, id: \.self) { i in line(tasks[i].s("title"), tasks[i].b("done")) { toggle("tasks", tasks[i]) } }
            ForEach(homework.indices, id: \.self) { i in line("\(homework[i].s("subject")): \(homework[i].s("title"))", false) { toggle("homework", homework[i]) } }
            Button(tasks.isEmpty ? "أضف مهمة" : "كل المهام") { open("tasks") }.font(.plex(.subheadline, .semibold)).tint(Brand.accent).frame(minHeight: 44)
        }
        .padding(Space.l).card()
        .accessibilityElement(children: .contain).accessibilityIdentifier("todayTasks")
    }
    private func toggle(_ store: String, _ o: Rec) {
        Store.shared.saveList(store, Store.shared.list(store).map { var r = $0; if r.id == o.id { r["done"] = !o.b("done") }; return r })
        changed()
    }
    private func line(_ text: String, _ done: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(done ? Brand.mint : Brand.text3)
                Text(text).font(.plex(.body)).foregroundStyle(done ? Brand.text3 : Brand.text1).strikethrough(done).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(done ? .isSelected : [])
    }
}

// MARK: role and adhkar

private struct RoleCard: View {
    let role: String
    let now: Date
    let open: (String) -> Void
    var body: some View {
        let (title, line, actions) = content()
        VStack(spacing: Space.s) {
            Text(title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1)
            Text(line).font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
            HStack(spacing: Space.s) { ForEach(actions, id: \.0) { id, label in SecondaryButton(title: label) { open(id) } } }
        }
        .padding(Space.l).frame(maxWidth: .infinity).card()
        .accessibilityElement(children: .contain).accessibilityIdentifier("roleCard-\(role)")
    }
    private func content() -> (String, String, [(String, String)]) {
        switch role {
        case "student":
            let t = Store.shared.obj("timetable"); let after = KSA.hour(now) >= 13
            // The timetable runs Sunday (0) to Thursday (4); after school, tomorrow's lessons are what matters.
            let wd = KSA.weekday(now); let target = after ? wd % 7 : wd - 1
            let lessons = (0...4).contains(target) ? (0..<7).map { t.s("\(target)-\($0)") }.filter { !$0.isEmpty } : []
            return (after ? "حصص الغد" : "حصص اليوم", lessons.isEmpty ? "أضف جدولك الدراسي لتظهر حصصك هنا" : lessons.joined(separator: "، "),
                    [("timetable", "الجدول"), ("flashcards", "المراجعة")])
        case "teacher":
            let q = Store.shared.list("published").first
            return ("اختباراتك", q.map { "آخر اختبار منشور: \($0.s("title"))" } ?? "أنشئ اختبارًا وانشره برابط، وتصلك النتائج هنا",
                    [("quiz_maker", "اختبار جديد"), ("attendance", "الحضور")])
        case "employee":
            return ("عملك", "احسب راتبك الصافي أو مكافأتك أو إجازاتك بالمواد النظامية", [("salary", "الراتب"), ("leave", "الإجازات")])
        default:
            return ("منشأتك", "فاتورة أو عرض سعر في دقيقة، بصيغة PDF", [("invoice", "فاتورة"), ("quote", "عرض سعر")])
        }
    }
}

private struct AdhkarCard: View {
    let now: Date
    @ObservedObject private var daily = Daily.shared
    @Environment(\.openURL) private var openURL
    var body: some View {
        let t = PrayerTimes.today(Cities.byId(daily.city), now)
        let m = KSA.minuteOfDay(now)
        let (label, path) = m >= t[0] && m < t[3] ? ("أذكار الصباح", "azkar-sabah") : m >= t[3] && m < t[5] + 120 ? ("أذكار المساء", "azkar-masaa") : ("أذكار النوم", "azkar-nawm")
        Button { if let u = URL(string: "https://ayattla.com/\(path)") { openURL(u) } } label: {
            VStack(spacing: 4) {
                Text(label).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.dyn(0x0E7A57, 0x5FD3AE))
                Text("حان وقت \(label)").font(.plex(.subheadline)).foregroundStyle(Brand.text1)
                Text("افتحها في آيات تتلى").font(.plex(.footnote, .semibold)).foregroundStyle(Brand.dyn(0x0E7A57, 0x5FD3AE))
            }
            .frame(maxWidth: .infinity).padding(Space.l)
            .background(Brand.toneSoft(0x14936B), in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Brand.mint.opacity(0.25), lineWidth: 1))
        }.buttonStyle(PressStyle()).accessibilityIdentifier("adhkarCard")
    }
}
