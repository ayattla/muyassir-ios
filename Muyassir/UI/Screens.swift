import SwiftUI

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
                Section("جرّب") { chips(["تصغير ملف", "صور إلى PDF", "دمج", "إزالة الخلفية", "استخراج نص", "راتب", "ضريبة", "QR", "compress", "merge"]) }
                Section { NavigationLink { AssistantView() } label: { Label("لا تعرف أي أداة؟ صف ما تريد للمساعد", systemImage: "sparkles").foregroundStyle(Brand.accent) } }
            } else if res.isEmpty {
                ContentUnavailableView("لا توجد أداة بهذا الوصف", systemImage: "magnifyingglass", description: Text("جرّب كلمة أخرى، أو صف ما تريد للمساعد."))
            } else {
                ForEach(Tools.categories) { c in
                    let list = res.filter { $0.cats[0] == c.id }
                    if !list.isEmpty {
                        Section(c.title) {
                            ForEach(list) { t in NavigationLink(value: t) { ToolRow(tool: t, compact: true, plain: true) }.simultaneousGesture(TapGesture().onEnded { remember() }) }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Brand.bg)
        .navigationTitle("البحث")
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "تصغير ملف، صور إلى PDF، راتب…")
        .onSubmit(of: .search) { remember() }
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
    var body: some View {
        ScrollView {
            VStack(spacing: Space.m) {
                Text("صف ما تريد إنجازه، وسأرشدك إلى الأدوات المناسبة بالترتيب").font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
                Field(label: "طلبك", text: $q, lines: 3)
                PrimaryButton(title: "اقترح الأدوات", icon: "lightbulb", enabled: !q.trimmingCharacters(in: .whitespaces).isEmpty) { withAnimation { plan = Assistant.plan(q) } }
                if let plan {
                    if let note = plan.note { Text(note).font(.plex(.subheadline)).foregroundStyle(Brand.text2).multilineTextAlignment(.center) }
                    ForEach(Array(plan.steps.enumerated()), id: \.element.id) { i, s in
                        NavigationLink(value: s.tool) {
                            HStack(spacing: Space.m) {
                                Text("\(i + 1)").font(.plex(.subheadline, .bold)).foregroundStyle(Brand.onAccent).frame(width: 32, height: 32).background(Brand.accent, in: Circle())
                                VStack(alignment: .leading, spacing: 2) { Text(s.tool.title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1); Text(s.why).font(.plex(.caption)).foregroundStyle(Brand.text2) }
                                Spacer(minLength: 0)
                                Text("افتح").font(.plex(.caption, .semibold)).foregroundStyle(Brand.accent)
                            }.padding(Space.l).card()
                        }.buttonStyle(PressStyle()).transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                } else {
                    SectionHead(title: "أمثلة")
                    FlowChips(items: ["حوّل صوري إلى PDF وصغّر حجمه", "أريد نص هذه الصورة", "صورة شخصية بمقاس الجواز", "ادمج ملفات PDF واحمها بكلمة مرور", "كم صافي راتبي؟", "صوّر أوراقًا ووقّعها"]) { q = $0; plan = Assistant.plan($0) }
                    Hint(text: "المساعد يعمل على جهازك دون إنترنت، ويقترح فقط: أنت من يفتح الأداة ويختار ملفاتك وينفّذ.")
                }
            }.padding(Space.l).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(Brand.bg).navigationTitle("المساعد")
    }
}

/// Activity tab: operations (re-run), result files (open, share, delete) and favourites.
struct ActivityView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0
    @State private var files: [URL] = []
    @State private var preview: URL?
    @State private var share: URL?
    var body: some View {
        List {
            Section { Seg(options: ["العمليات", "الملفات", "المفضلة"], selection: $tab) }.listRowBackground(Color.clear)
            switch tab {
            case 0:
                if store.recents.isEmpty { ContentUnavailableView("لا توجد عمليات بعد", systemImage: "clock", description: Text("كل ما تنجزه في الأدوات يظهر هنا لتعيده بلمسة.")) }
                ForEach(store.recents) { r in if let t = Tools.byId[r.tool] { NavigationLink(value: t) { ActivityRow(icon: t.icon, hex: Tools.hex(t), title: t.title, detail: r.detail.isEmpty ? t.sub : r.detail, date: r.time, action: "إعادة") } } }
                if !store.recents.isEmpty { Button("مسح السجل", role: .destructive) { store.clearRecents() }.frame(maxWidth: .infinity) }
            case 1:
                if files.isEmpty { ContentUnavailableView("لا توجد ملفات ناتجة", systemImage: "folder", description: Text("نتائج التحويل والضغط تبقى هنا 24 ساعة ثم تُحذف تلقائيًا.")) }
                ForEach(files, id: \.self) { u in
                    Button { preview = u } label: { ActivityRow(icon: fileIcon(u), hex: 0x3346D3, title: u.lastPathComponent, detail: FilesX.human(FilesX.size(u)), date: FilesX.date(u), action: "معاينة") }
                        .buttonStyle(.plain)
                        .swipeActions { Button(role: .destructive) { try? FileManager.default.removeItem(at: u); files = FilesX.outputs() } label: { Label("حذف", systemImage: "trash") }; Button { share = u } label: { Label("مشاركة", systemImage: "square.and.arrow.up") }.tint(Brand.accent) }
                }
            default:
                let favs = store.favorites.compactMap { Tools.byId[$0] }
                if favs.isEmpty { ContentUnavailableView("لا توجد مفضلة", systemImage: "star", description: Text("اضغط النجمة أعلى أي أداة لتضيفها هنا وفي الرئيسية.")) }
                ForEach(favs) { t in NavigationLink(value: t) { ToolRow(tool: t, compact: true, plain: true) } }
            }
        }
        .listRowSeparator(.hidden).scrollContentBackground(.hidden).background(Brand.bg)
        .navigationTitle("نشاطي")
        .onAppear { files = FilesX.outputs() }
        .quickLookPreview($preview, in: files)
        .sheet(item: Binding(get: { share.map { EditURL(url: $0) } }, set: { share = $0?.url })) { ShareSheet(items: [$0.url]) }
    }
}

/// Settings tab: appearance (light by default), greeting name, home sections, privacy and storage.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("theme") private var theme = "light"
    @AppStorage("name") private var name = ""
    @AppStorage("hidden") private var hidden = ""
    @AppStorage("searches") private var history = ""
    @State private var done: String?
    private let sections = [("quick", "الأدوات السريعة"), ("cats", "الأقسام"), ("favs", "المفضلة"), ("most", "الأكثر استخدامًا"), ("rec", "مقترحة لك"), ("recent", "آخر العمليات"), ("files", "الملفات الناتجة")]
    var body: some View {
        Form {
            Section("المظهر") {
                Picker("الوضع", selection: $theme) { Text("فاتح").tag("light"); Text("داكن").tag("dark"); Text("حسب الجهاز").tag("system") }.pickerStyle(.segmented)
            }
            Section("الترحيب") { TextField("اسمك (اختياري) يظهر في التحية", text: $name) }
            Section("أقسام الصفحة الرئيسية") {
                ForEach(sections, id: \.0) { id, label in
                    Toggle(label, isOn: Binding(get: { !hidden.split(separator: ",").contains(Substring(id)) }, set: { on in
                        var set = Set(hidden.split(separator: ",").map(String.init)); if on { set.remove(id) } else { set.insert(id) }; hidden = set.sorted().joined(separator: ",")
                    }))
                }
            }
            Section {
                Button("حذف الملفات المؤقتة والنتائج الآن", role: .destructive) { FilesX.clearAll(); done = "حُذفت الملفات المؤقتة والنتائج" }
                Button("مسح سجل العمليات والبحث") { store.clearRecents(); history = ""; done = "مُسح السجل" }
                if let done { Text(done).foregroundStyle(Brand.mint) }
            } header: { Text("الخصوصية والتخزين") } footer: { Text("كل المعالجة على جهازك، ولا تُرفع ملفاتك إلى أي خادم. النتائج تُحذف تلقائيًا بعد 24 ساعة.") }
            Section {
                VStack(spacing: 6) {
                    LogoMark(size: 48)
                    Text("مُيسّر").font(.plex(.headline, .semibold))
                    Text("الإصدار \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") • \(Tools.all.count) أداة").font(.plex(.caption)).foregroundStyle(Brand.text3)
                }.frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .font(.plex(.body))
        .navigationTitle("الإعدادات")
    }
}
