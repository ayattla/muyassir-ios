import SwiftUI
import UniformTypeIdentifiers

/// Search tab: instant results by name, purpose or synonym (Arabic and English), grouped by section, with history.
struct SearchView: View {
    @EnvironmentObject var store: Store
    @AppStorage("searches") private var history = ""
    @State private var q = ""
    private var past: [String] { history.split(separator: "\n").map(String.init) }
    private func remember() { let v = q.trimmingCharacters(in: .whitespaces); guard v.count > 1 else { return }; history = ([v] + past.filter { $0 != v }).prefix(8).joined(separator: "\n") }
    var body: some View {
        let res = Tools.search(q, usage: store.usage)
        List {
            if q.isEmpty {
                if !past.isEmpty {
                    Section { chips(past) } header: { HStack { Text("عمليات بحث سابقة"); Spacer(); Button("مسح") { history = "" } } }
                }
                Section("جرب") { chips(["تصغير ملف", "صور إلى PDF", "دمج", "إزالة الخلفية", "استخراج نص", "راتب", "ضريبة", "QR", "compress", "merge"]) }
                Section { NavigationLink { AssistantView() } label: { Label("لا تعرف أي أداة؟ صف ما تريد للمساعد", systemImage: "sparkles").foregroundStyle(Brand.accent) } }
            } else if res.isEmpty {
                ContentUnavailableView("لا توجد أداة بهذا الوصف", systemImage: "magnifyingglass", description: Text("جرب كلمة أخرى، أو صف ما تريد للمساعد."))
            } else {
                ForEach(Tools.categories) { c in
                    let list = res.filter { $0.cats[0] == c.id }
                    if !list.isEmpty {
                        Section(c.title) {
                            ForEach(list) { t in NavigationLink(value: t) { ToolRow(tool: t, compact: true, plain: true) }.accessibilityIdentifier("result-\(t.id)") }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Brand.bg)
        .navigationTitle("البحث")
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "تصغير ملف، صور إلى PDF، راتب…")
        .onSubmit(of: .search) { remember() }
        .onDisappear { remember() }
    }
    private func chips(_ items: [String]) -> some View {
        FlowChips(items: items) { q = $0 }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }
}

/// Wrapping row of chips.
struct FlowChips: View {
    let items: [String]; let tap: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 8) { ForEach(items, id: \.self) { s in Chip(text: s, selected: false) { tap(s) } } }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 350; var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews { let s = v.sizeThatFits(.unspecified); if x + s.width > w, x > 0 { x = 0; y += row + spacing; row = 0 }; x += s.width + spacing; row = max(row, s.height) }
        return CGSize(width: w, height: y + row)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, row: CGFloat = 0
        for v in subviews { let s = v.sizeThatFits(.unspecified); if x + s.width > b.maxX, x > b.minX { x = b.minX; y += row + spacing; row = 0 }; v.place(at: CGPoint(x: x, y: y), proposal: .unspecified); x += s.width + spacing; row = max(row, s.height) }
    }
}

/// Assistant tab: describe the goal, get the tools in order. Offline; it only guides.
struct AssistantView: View {
    @State private var q = ""
    @State private var plan: Assistant.Plan?
    @State private var picking: String?
    var body: some View {
        ScrollView {
            VStack(spacing: Space.m) {
                Text("صف ما تريد إنجازه، وسأرشدك إلى الأدوات المناسبة بالترتيب").font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
                Field(label: "طلبك", text: $q, lines: 3)
                PrimaryButton(title: "اقترح الأدوات", icon: "lightbulb", enabled: !q.trimmingCharacters(in: .whitespaces).isEmpty) { withAnimation { plan = Assistant.plan(q) } }
                if let plan {
                    if let note = plan.note { Text(note).font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center) }
                    if let rid = Assistant.recipeFor(plan.steps.map(\.tool.id)), let r = Recipes.shared.byId(rid) {
                        Text("أو نفذها كلها بلمسة واحدة:").font(.plex(.caption, .semibold)).foregroundStyle(Brand.text2)
                        NavigationLink(value: RecipeRoute(id: r.id)) { RecipeCard(recipe: r) }.buttonStyle(PressStyle()).accessibilityIdentifier("assistantRecipe")
                    }
                    ForEach(Array(plan.steps.enumerated()), id: \.element.id) { i, s in
                        if i == 0 && Plus.isMetered(s.tool.id) {
                            SecondaryButton(title: "اختر الملفات وافتح «\(s.tool.title)»", icon: "folder.badge.plus") { picking = s.tool.id }.accessibilityIdentifier("assistPick")
                        }
                        NavigationLink(value: s.tool) {
                            HStack(spacing: Space.m) {
                                Text("\(i + 1)").font(.plex(.subheadline, .bold)).foregroundStyle(Brand.onAccent).frame(width: 32, height: 32).background(Brand.accent, in: Circle())
                                VStack(alignment: .leading, spacing: 2) { Text(s.tool.title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1); Text(s.why).font(.plex(.caption)).foregroundStyle(Brand.text2) }
                                Spacer(minLength: 0)
                                Text("افتح").font(.plex(.caption, .semibold)).foregroundStyle(Brand.accent)
                            }.padding(Space.l).card()
                        }.buttonStyle(PressStyle()).transition(.opacity.combined(with: .move(edge: .bottom)))
                        .simultaneousGesture(TapGesture().onEnded { Assistant.prefill(q) }).accessibilityIdentifier("assistOpen-\(s.tool.id)")
                    }
                } else {
                    SectionHead(title: "أمثلة")
                    FlowChips(items: ["حول صوري إلى PDF وصغر حجمه", "أريد تحويل عشر صور إلى Word", "أنشئ ورقة عمل للصف السادس", "أريد حساب مستحقات نهاية الخدمة", "اجمع هذه المستندات في PDF", "استخرج الجداول من هذا التقرير"]) { q = $0; plan = Assistant.plan($0) }
                    Hint(text: "المساعد يعمل على جهازك دون إنترنت: يفهم طلبك، ويفتح الأداة الحقيقية بملفاتك وبما ذكرته (الصف، المادة)، ثم تضغط تنفيذ وترى النتيجة. لا يرسل شيئا خارج جهازك.")
                }
            }.padding(Space.l).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(Brand.bg).navigationTitle("المساعد")
        .fileImporter(isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }), allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            guard let id = picking, case .success(let urls) = r, !urls.isEmpty else { picking = nil; return }
            let local = urls.compactMap { try? FilesX.toTemp($0) }
            Incoming.shared.handTo(local); Assistant.prefill(q); picking = nil; DeepLink.shared.target = "tool/\(id)"
        }
    }
}

/// Activity tab: operations (re-run), result files (open, share, delete) and favourites.
struct ActivityView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0
    @State private var files: [URL] = []
    @State private var preview: URL?
    @State private var share: URL?
    @State private var fileQuery = ""
    @State private var projectsVersion = 0
    @ObservedObject private var plus = Plus.shared
    var body: some View {
        List {
            Section {
                Seg(options: ["العمليات", "الملفات", "مشاريعي", "المفضلة"], selection: $tab)
                Button { plus.paywall = .menu } label: {
                    Label(plus.active ? "ميسر بلس مفعل" : plus.live ? "اليوم: \(plus.usedToday) من \(Plus.freeOpsPerDay) عمليات مجانية • ميسر بلس" : "ميسر بلس قريبا", systemImage: "crown.fill")
                        .font(.plex(.caption, .semibold)).frame(maxWidth: .infinity)
                }.buttonStyle(.borderless)
            }.listRowBackground(Color.clear)
            switch tab {
            case 0:
                if store.recents.isEmpty { ContentUnavailableView("لا توجد عمليات بعد", systemImage: "clock", description: Text("كل ما تنجزه في الأدوات يظهر هنا لتعيده بلمسة.")) }
                ForEach(store.recents) { r in if let t = Tools.byId[r.tool] { NavigationLink(value: t) { ActivityRow(icon: t.icon, hex: Tools.hex(t), title: t.title, detail: r.detail.isEmpty ? t.sub : r.detail, date: r.time, action: "إعادة") } } }
                if !store.recents.isEmpty { Button("مسح السجل", role: .destructive) { store.clearRecents() }.frame(maxWidth: .infinity) }
            case 1:
                if files.isEmpty { ContentUnavailableView("لا توجد ملفات ناتجة", systemImage: "folder", description: Text("نتائج التحويل والضغط تبقى هنا 24 ساعة ثم تحذف تلقائيا، إلا ما تختار إبقاءه.")) }
                else { TextField("ابحث في ملفاتك", text: $fileQuery).textFieldStyle(.roundedBorder) }
                ForEach(files.filter { fileQuery.isEmpty || Tools.norm($0.lastPathComponent).contains(Tools.norm(fileQuery)) }, id: \.self) { u in
                    Button { preview = u } label: { ActivityRow(icon: fileIcon(u), hex: 0x3346D3, title: u.lastPathComponent, detail: FilesX.human(FilesX.size(u)) + (FilesX.isKept(u) ? " • محفوظ" : " • يحذف بعد 24 ساعة"), date: FilesX.date(u), action: "معاينة") }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) { try? FileManager.default.removeItem(at: u); files = FilesX.outputs() } label: { Label("حذف", systemImage: "trash") }
                            Button { share = u } label: { Label("مشاركة", systemImage: "square.and.arrow.up") }.tint(Brand.accent)
                            if !FilesX.isKept(u) { Button { FilesX.keep(u); files = FilesX.outputs() } label: { Label("إبقاء", systemImage: "pin") }.tint(Brand.mint) }
                        }
                        .contextMenu {
                            Menu("أضف إلى مشروع") {
                                ForEach(Projects.all().indices, id: \.self) { i in let p = Projects.all()[i]; Button(p.s("name")) { Projects.add(p.d("id"), u); files = FilesX.outputs(); projectsVersion += 1 } }
                                Button("مشروع جديد باسم الملف") { let p = Projects.create(FilesX.base(u)); Projects.add(p.d("id"), u); files = FilesX.outputs(); projectsVersion += 1 }
                            }
                        }
                }
            case 2:
                ProjectsSection(version: $projectsVersion)
            default:
                let favs = store.favorites.compactMap { Tools.byId[$0] }
                if favs.isEmpty { ContentUnavailableView("لا توجد مفضلة", systemImage: "star", description: Text("اضغط النجمة أعلى أي أداة لتضيفها هنا وفي الرئيسية.")) }
                ForEach(favs) { t in NavigationLink(value: t) { ToolRow(tool: t, compact: true, plain: true) } }
            }
        }
        .listRowSeparator(.hidden).scrollContentBackground(.hidden).background(Brand.bg)
        .navigationTitle("ملفاتي")
        .onAppear { files = FilesX.outputs() }
        .quickLookPreview($preview, in: files)
        .sheet(item: Binding(get: { share.map { EditURL(url: $0) } }, set: { share = $0?.url })) { ShareSheet(items: [$0.url]) }
    }
}

/// Settings tab: appearance (light by default), greeting name, home sections, privacy and storage.
struct SettingsView: View {
    let open: (String) -> Void
    @EnvironmentObject var store: Store
    @AppStorage("theme") private var theme = "light"
    @AppStorage("name") private var name = ""
    @AppStorage("hidden") private var hidden = ""
    @AppStorage("searches") private var history = ""
    @State private var done: String?
    @ObservedObject private var plus = Plus.shared
    @ObservedObject private var lock = AppLock.shared
    @AppStorage("accent") private var accent = 0
    @State private var icon = UIApplication.shared.alternateIconName
    @Environment(\.openURL) private var openURL
    @AppStorage("role") private var role = ""
    init(open: @escaping (String) -> Void = { _ in }) { self.open = open }
    private let sections = [("quick", "الأدوات السريعة"), ("recipes", "الوصفات"), ("cats", "الأقسام"), ("favs", "المفضلة"), ("most", "الأكثر استخداما"), ("rec", "مقترحة لك"), ("recent", "آخر العمليات"), ("files", "الملفات الناتجة")]
    var body: some View {
        Form {
            Section {
                Text("وثائقك وتفضيلاتك والإعدادات").font(.plex(.subheadline)).foregroundStyle(Brand.text2).frame(maxWidth: .infinity).listRowBackground(Color.clear)
                HStack(spacing: Space.s) {
                    ForEach([("documents", "وثائقي", "folder.badge.person.crop"), ("budget", "ميزانيتي", "chart.pie")], id: \.0) { id, label, icon in
                        Button { open(id) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(Brand.accent)
                                Text(label).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1)
                            }.frame(maxWidth: .infinity, minHeight: 76).card(Radius.m)
                        }.buttonStyle(PressStyle()).accessibilityIdentifier("me-\(id)")
                    }
                }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section { PlusCard().listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
            Section("المظهر") {
                Picker("الوضع", selection: $theme) { Text("فاتح").tag("light"); Text("داكن").tag("dark"); Text("حسب الجهاز").tag("system") }.pickerStyle(.segmented)
                HStack(spacing: 6) { Text("لون التطبيق"); PlusBadge() }
                HStack {
                    ForEach(accents.indices, id: \.self) { i in
                        Button {
                            if i == 0 || plus.allow(.look) { accent = i; plus.syncLook() }
                        } label: {
                            Circle().fill(Color(hex: accents[i].1)).frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Brand.text1, lineWidth: (plus.unlocked ? accent : 0) == i ? 3 : 0))
                        }.buttonStyle(.plain).accessibilityLabel("اللون \(accents[i].0)")
                    }
                }.frame(maxWidth: .infinity)
                HStack(spacing: 6) { Text("أيقونة التطبيق"); PlusBadge() }
                HStack {
                    ForEach(appIcons.indices, id: \.self) { i in
                        Chip(text: appIcons[i].1, selected: icon == appIcons[i].0) {
                            guard i == 0 || plus.allow(.look) else { return }
                            UIApplication.shared.setAlternateIconName(appIcons[i].0) { e in if e == nil { icon = appIcons[i].0 } }
                        }
                    }
                }.frame(maxWidth: .infinity)
            }
            Section("الترحيب") {
                TextField("اسمك (اختياري) يظهر في التحية", text: $name)
                Picker("ما يصفك", selection: $role) { ForEach(Tools.roles, id: \.0) { Text($0.1).tag($0.0) }; Text("بلا تخصيص").tag("none") }
            }
            Section("أقسام الصفحة الرئيسية") {
                ForEach(sections, id: \.0) { id, label in
                    Toggle(label, isOn: Binding(get: { !hidden.split(separator: ",").contains(Substring(id)) }, set: { on in
                        var set = Set(hidden.split(separator: ",").map(String.init)); if on { set.remove(id) } else { set.insert(id) }; hidden = set.sorted().joined(separator: ",")
                    }))
                }
            }
            Section {
                Button("حذف الملفات المؤقتة والنتائج الآن", role: .destructive) { FilesX.clearAll(); done = "حذفت الملفات المؤقتة والنتائج" }
                Button("مسح سجل العمليات والبحث") { store.clearRecents(); history = ""; done = "مسح السجل" }
                HStack {
                    Toggle("قفل المفكرة والوثائق ببصمة الوجه", isOn: Binding(get: { lock.enabled }, set: { on in
                        Task {
                            if !on { if await lock.prompt("إيقاف القفل") { lock.set(false) } }
                            else if plus.allow(.lock) {
                                if !lock.available { done = "فعل بصمة الوجه أو رمز الجهاز في إعدادات جهازك أولا" }
                                else if await lock.prompt("تفعيل القفل") { lock.set(true) }
                            }
                        }
                    }))
                    PlusBadge()
                }
                if let done { Text(done).foregroundStyle(Brand.mint) }
            } header: { Text("الخصوصية والتخزين") } footer: { Text("كل المعالجة على جهازك، ولا ترفع ملفاتك إلى أي خادم. النتائج تحذف تلقائيا بعد 24 ساعة.") }
            BackupSection()
            Section {
                Button { contactSupport(openURL) } label: { Label("تواصل مع الدعم", systemImage: "questionmark.bubble") }
            } header: { Text("الدعم والملاحظات") } footer: { Text(plus.active ? "مشتركو بلس تصل رسائلهم بعلامة «بلس» ويرد عليها أولا." : "أرسل اقتراحك أو بلغ عن مشكلة.") }
            Section {
                VStack(spacing: 6) {
                    LogoMark(size: 48)
                    Text("ميسر").font(.plex(.headline, .semibold))
                    Text("الإصدار \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") • \(Tools.all.count) أداة").font(.plex(.caption)).foregroundStyle(Brand.text3)
                }.frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .font(.plex(.body))
        .navigationTitle("أنا")
    }
}
