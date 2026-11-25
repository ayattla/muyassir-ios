import SwiftUI

/// «يومي»: what matters today at a glance. Every card shows only when it has something to say. Mirrors Android's TodayScreen.
struct TodayView: View {
    let open: (String) -> Void
    let openTab: (String) -> Void
    let openCat: (Category) -> Void
    @ObservedObject private var daily = Daily.shared
    @ObservedObject private var lock = AppLock.shared
    @AppStorage("name") private var name = ""
    @State private var editing = false
    @State private var tick = 0
    init(open: @escaping (String) -> Void, openTab: @escaping (String) -> Void, openCat: @escaping (Category) -> Void = { _ in }) { self.open = open; self.openTab = openTab; self.openCat = openCat }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let now = ctx.date
            ScrollView {
                VStack(spacing: Space.m) {
                    TodayTopBar(now: now, openMe: { openTab("settings") }) { withAnimation(.snappy) { editing.toggle() } }
                    CommandBar(now: now, openAssistant: { openTab("assistant") }, open: open)
                    if daily.showPrayer { PrayerCard(now: now) }
                    QuickGrid(open: open, openTools: { openTab("home") })
                    if !daily.setupDone || editing { SetupCard(first: !daily.setupDone) { editing = false } }
                    datesRow(now)
                    TasksCard(now: now, open: open, changed: { tick += 1 }).id(tick)
                    if daily.setupDone && daily.roles.isEmpty { RolePrompt() }
                    ForEach(daily.roles, id: \.self) { TodayRoleCard(role: $0, now: now, open: open) }
                    ContinueCard(open: open)
                    if daily.showAdhkar && daily.showPrayer { AdhkarCard(now: now) }
                    SpacesGrid(openCat: openCat)
                    ToolOfDay(now: now, open: open)
                }
                .padding(.horizontal, Space.l).padding(.bottom, Space.xxl).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("today")
        }
        .background(Brand.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { daily.syncWidget() }
    }

    fileprivate static func greeting(_ d: Date, _ name: String) -> String {
        let h = KSA.hour(d)
        let base = (4...11).contains(h) ? "صباح الخير" : (12...16).contains(h) ? "طاب يومك" : "مساء الخير"
        return name.isEmpty ? base : "\(base)، \(name)"
    }

    private struct Due: Identifiable { let id = UUID(); let days: Int; let title: String; let warn: Bool; let tool: String?; var islamic = false }

    @ViewBuilder private func datesRow(_ now: Date) -> some View {
        let dues = upcoming(now)
        if !dues.isEmpty {
            VStack(spacing: Space.s) {
                SectionTitle(title: "مواعيدك القادمة", sub: "رواتب ومناسبات ووثائق")
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: Space.s) {
                    ForEach(dues) { d in
                        Button { if let t = d.tool { open(t) } } label: {
                            VStack(spacing: 2) {
                                Text(d.days == 0 ? "اليوم" : "\(d.days)").font(.plex(d.days == 0 ? .title3 : .title, .bold))
                                    .foregroundStyle(d.warn ? Brand.dyn(0xA05A00, 0xF2B01E) : d.islamic ? Brand.dyn(0x0E7A57, 0x5FD3AE) : Brand.accent)
                                if d.days > 0 { Text((3...10).contains(d.days) ? "أيام" : "يومًا").font(.plex(.caption2)).foregroundStyle(Brand.text2) }
                                Text(d.title).font(.plex(.footnote, .semibold)).foregroundStyle(Brand.text1).multilineTextAlignment(.center).lineLimit(2)
                            }
                            .frame(width: 112).padding(.vertical, Space.m).padding(.horizontal, Space.s)
                            .background(d.warn ? Brand.dyn(0xFFF6E6, 0x2E2414) : Brand.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(d.warn ? Brand.dyn(0xEBC48A, 0x5A4420) : Brand.border, lineWidth: 1))
                        }.buttonStyle(PressStyle()).disabled(d.tool == nil)
                    }
                } }.accessibilityElement(children: .contain).accessibilityIdentifier("dates")
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
        out += Occasions.upcoming(now).map { Due(days: $0.days, title: $0.title, warn: false, tool: "hijri", islamic: true) }
        return Array(out.sorted { $0.days < $1.days }.prefix(8))
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
                Text("ما عندك مهام اليوم. اكتب أول مهمة واضغط إضافة.").font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
            }
            QuickTaskField(due: endOfDay, added: changed)
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

private struct TodayRoleCard: View {
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

// MARK: home layout pieces (mirrors Android's Today.kt)

private struct SectionTitle: View {
    let title: String
    var sub: String? = nil
    var action: (String, () -> Void)? = nil
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.plex(.headline, .bold)).foregroundStyle(Brand.text1)
                if let sub { Text(sub).font(.plex(.caption)).foregroundStyle(Brand.text2) }
            }
            Spacer()
            if let action { Button(action.0, action: action.1).font(.plex(.subheadline, .semibold)).tint(Brand.accent).frame(minHeight: 44) }
        }
    }
}

private struct TodayTopBar: View {
    let now: Date
    let openMe: () -> Void
    let customise: () -> Void
    @AppStorage("name") private var name = ""
    var body: some View {
        let (y, m, d) = KSA.ymd(now)
        let h = Hijri.toHijri(y, m, d)
        HStack(spacing: Space.m) {
            Button(action: openMe) {
                Group {
                    if let c = name.trimmingCharacters(in: .whitespaces).first { Text(String(c)).font(.plex(.title3, .bold)) }
                    else { Image(systemName: "person.fill").font(.system(size: 18)) }
                }
                .foregroundStyle(Brand.accent).frame(width: 48, height: 48).background(Brand.accentSoft, in: Circle())
            }.accessibilityLabel("حسابي").accessibilityIdentifier("todayMe")
            VStack(alignment: .leading, spacing: 2) {
                Text(TodayView.greeting(now, name)).font(.plex(.headline, .bold)).foregroundStyle(Brand.text1).lineLimit(1)
                Text(h.map { "\(Hijri.days[KSA.weekday(now) - 1]) \($0.d) \(Hijri.months[$0.m - 1])، \(d) \(Hijri.gMonths[m - 1])" } ?? "")
                    .font(.plex(.caption)).foregroundStyle(Brand.text2).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: customise) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 17)).foregroundStyle(Brand.text1).frame(width: 48, height: 48)
                    .overlay(Circle().stroke(Brand.border, lineWidth: 1))
            }.accessibilityLabel("تخصيص يومي").accessibilityIdentifier("todaySettings")
        }.padding(.top, Space.l)
    }
}

/// One place to ask for anything, with three ideas that change with the time of day.
private struct CommandBar: View {
    let now: Date
    let openAssistant: () -> Void
    let open: (String) -> Void
    var body: some View {
        let hr = KSA.hour(now)
        let ideas = ((5...11).contains(hr) ? ["scan", "img_pdf", "translate"] : (12...17).contains(hr) ? ["pdf_merge", "pdf_compress", "invoice"] : ["tasks", "budget", "notes"]).compactMap { Tools.byId[$0] }
        VStack(spacing: Space.s) {
            Button(action: openAssistant) {
                HStack(spacing: Space.m) {
                    Image(systemName: "sparkles").font(.system(size: 16, weight: .semibold)).foregroundStyle(Brand.onAccent)
                        .frame(width: 34, height: 34).background(Brand.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("وش تبي تسوي اليوم؟").font(.plex(.body)).foregroundStyle(Brand.text2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Space.l).frame(minHeight: 58)
                .background(Brand.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Brand.accent.opacity(0.35), lineWidth: 1.5))
            }.buttonStyle(PressStyle()).accessibilityIdentifier("todayAssistant")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(ideas) { t in
                        let hex = Tools.category(t.cats[0]).hex
                        Button { open(t.id) } label: {
                            Label(t.title, systemImage: t.icon).font(.plex(.subheadline, .medium)).foregroundStyle(Brand.text1)
                                .padding(.horizontal, 14).frame(minHeight: 40).background(Brand.toneSoft(hex), in: Capsule())
                        }.buttonStyle(PressStyle())
                    }
                }
            }
        }
    }
}

/// Eight shortcuts: favourites first, then what fits the person's role.
private struct QuickGrid: View {
    let open: (String) -> Void
    let openTools: () -> Void
    @EnvironmentObject private var store: Store
    @ObservedObject private var daily = Daily.shared
    var body: some View {
        let base = daily.roles.flatMap { Tools.byRole[$0] ?? [] }
        var seen = Set<String>()
        let tools = (store.favorites + base + ["scan", "img_pdf", "pdf_merge", "pdf_compress", "translate", "salary", "invoice", "qr_make"])
            .filter { seen.insert($0).inserted }.compactMap { Tools.byId[$0] }.prefix(8)
        VStack(spacing: Space.s) {
            SectionTitle(title: "اختصاراتك", sub: store.favorites.isEmpty ? "ثبّت أدواتك بالنجمة لتظهر هنا" : nil, action: ("كل الأدوات", openTools))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: Space.m) {
                ForEach(Array(tools)) { t in
                    let hex = Tools.category(t.cats[0]).hex
                    Button { open(t.id) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: t.icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(Brand.tone(hex))
                                .frame(width: 52, height: 52).background(Brand.toneSoft(hex), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            Text(t.title).font(.plex(.caption, .medium)).foregroundStyle(Brand.text1).multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(PressStyle()).accessibilityIdentifier("quick-\(t.id)")
                }
            }
            .padding(.vertical, Space.m).padding(.horizontal, Space.s).card()
            .accessibilityElement(children: .contain).accessibilityIdentifier("quickGrid")
        }
    }
}

private struct QuickTaskField: View {
    let due: Double
    let added: () -> Void
    @State private var draft = ""
    var body: some View {
        HStack(spacing: Space.s) {
            TextField("أضف مهمة لليوم", text: $draft).font(.plex(.body)).submitLabel(.done).onSubmit(add)
                .padding(.horizontal, Space.m).frame(minHeight: 48)
                .background(Brand.bg, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Brand.border, lineWidth: 1))
                .accessibilityIdentifier("quickTask")
            Button(action: add) {
                Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(Brand.onAccent)
                    .frame(width: 48, height: 48).background(Brand.accent, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            }.accessibilityLabel("إضافة المهمة").accessibilityIdentifier("quickTaskAdd")
        }
    }
    private func add() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }
        let rec: Rec = ["id": Date().timeIntervalSince1970 * 1000, "title": title, "due": due, "done": false]
        Store.shared.saveList("tasks", [rec] + Store.shared.list("tasks")); draft = ""; added()
    }
}

private struct RolePrompt: View {
    @ObservedObject private var daily = Daily.shared
    var body: some View {
        VStack(spacing: Space.s) {
            Text("وش يصفك؟").font(.plex(.subheadline, .bold)).foregroundStyle(Brand.text1)
            Text("نعرض لك أدوات دورك ومواعيده هنا").font(.plex(.caption)).foregroundStyle(Brand.text2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(Tools.roles, id: \.0) { id, label in
                        Button { daily.toggleRole(id) } label: {
                            Text(label).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.accent).padding(.horizontal, 16).frame(minHeight: 40)
                                .overlay(Capsule().stroke(Brand.accent.opacity(0.4), lineWidth: 1))
                        }.accessibilityIdentifier("pick-\(id)")
                    }
                }
            }
        }.padding(Space.l).frame(maxWidth: .infinity).card()
    }
}

/// Pick up where you left off: the last three things done in the app.
private struct ContinueCard: View {
    let open: (String) -> Void
    @EnvironmentObject private var store: Store
    var body: some View {
        let items = store.recents.prefix(3).compactMap { r in Tools.byId[r.tool].map { ($0, r) } }
        if !items.isEmpty {
            VStack(spacing: Space.s) {
                SectionTitle(title: "أكمل من حيث توقفت")
                ForEach(items, id: \.1.id) { t, r in
                    Button { open(t.id) } label: { ActivityRow(icon: t.icon, hex: Tools.category(t.cats[0]).hex, title: t.title, detail: r.detail, date: r.time, action: "فتح") }.buttonStyle(PressStyle())
                }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("continue")
        }
    }
}

/// Every space of the app, one tap away.
private struct SpacesGrid: View {
    let openCat: (Category) -> Void
    var body: some View {
        VStack(spacing: Space.s) {
            SectionTitle(title: "مساحاتك", sub: "\(Tools.all.count) أداة في \(Tools.categories.count) مساحات")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)], spacing: Space.s) {
                ForEach(Tools.categories) { c in
                    Button { openCat(c) } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: c.icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Brand.tone(c.hex))
                                .frame(width: 36, height: 36).background(Brand.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1).lineLimit(1)
                                Text("\(Tools.inCat(c.id).count) أداة").font(.plex(.caption2)).foregroundStyle(Brand.text2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Space.m).frame(minHeight: 64)
                        .background(Brand.toneSoft(c.hex), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    }.buttonStyle(PressStyle()).accessibilityIdentifier("space-\(c.id)")
                }
            }
        }
    }
}

/// One tool you haven't tried, a different one each day.
private struct ToolOfDay: View {
    let now: Date
    let open: (String) -> Void
    @EnvironmentObject private var store: Store
    var body: some View {
        let unused = Tools.all.filter { !store.favorites.contains($0.id) && (store.usage[$0.id] ?? 0) == 0 }
        let pool = unused.isEmpty ? Tools.all : unused
        let t = pool[(KSA.cal.ordinality(of: .day, in: .year, for: now) ?? 1) % pool.count]
        let hex = Tools.category(t.cats[0]).hex
        Button { open(t.id) } label: {
            HStack(spacing: Space.m) {
                Image(systemName: t.icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(Brand.tone(hex))
                    .frame(width: 48, height: 48).background(Brand.toneSoft(hex), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("جرّب اليوم").font(.plex(.caption)).foregroundStyle(Brand.text2)
                    Text(t.title).font(.plex(.subheadline, .bold)).foregroundStyle(Brand.text1)
                    Text(t.sub).font(.plex(.caption)).foregroundStyle(Brand.text2).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(Space.l)
            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Brand.border, lineWidth: 1))
        }.buttonStyle(PressStyle()).accessibilityIdentifier("toolOfDay")
    }
}
