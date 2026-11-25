import SwiftUI

/// The smart home: brand header, greeting, search, featured tools, sections, then the user's own history.
struct HomeView: View {
    @EnvironmentObject var store: Store
    @AppStorage("theme") private var theme = "light"
    @AppStorage("name") private var name = ""
    @AppStorage("hidden") private var hidden = ""
    @AppStorage("role") private var role = ""
    @Environment(\.horizontalSizeClass) private var hsize
    var go: (String) -> Void = { _ in }
    @Binding var path: NavigationPath
    @State private var outputs: [URL] = []

    private var cols: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: Space.m), count: hsize == .regular ? 4 : 2) }
    private func shows(_ id: String) -> Bool { !hidden.split(separator: ",").contains(Substring(id)) }
    private let general = ["pdf_word", "pdf_merge", "img_compress", "ocr", "scan", "img_convert"]
    /// Quick tools: the user's role first, then the general favourites.
    private var featured: [String] { var seen = Set<String>(); return ((Tools.byRole[role] ?? []).prefix(4) + general).filter { seen.insert($0).inserted }.prefix(6).map { $0 } }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.m) {
                header
                greeting
                searchEntry
                if role.isEmpty { RoleCard() }
                if shows("quick") {
                    SectionHead(title: "أدوات سريعة", sub: "أكثر ما يحتاجه الناس يوميا")
                    LazyVGrid(columns: hsize == .regular ? Array(repeating: GridItem(.flexible(), spacing: Space.m), count: 6) : cols, spacing: Space.m) {
                        ForEach(featured, id: \.self) { id in if let t = Tools.byId[id] { NavigationLink(value: t) { FeaturedCard(tool: t) }.buttonStyle(PressStyle()).accessibilityIdentifier("quick-\(id)") } }
                    }
                }
                if shows("recipes") {
                    SectionHead(title: "الوصفات", sub: "عدة أدوات بلمسة واحدة", action: ("الكل", { path.append(RecipesRoute()) }))
                    LazyVGrid(columns: cols, spacing: Space.m) {
                        ForEach(Recipes.builtIn.prefix(hsize == .regular ? 4 : 2)) { r in NavigationLink(value: RecipeRoute(id: r.id)) { RecipeCard(recipe: r) }.buttonStyle(PressStyle()).accessibilityIdentifier("recipe-\(r.id)") }
                    }
                }
                if shows("cats") {
                    SectionHead(title: "الأقسام", sub: "\(Tools.all.count) أداة في \(Tools.categories.count) أقسام")
                    LazyVGrid(columns: cols, spacing: Space.m) {
                        ForEach(Tools.categories) { c in NavigationLink(value: c) { CategoryCard(cat: c) }.buttonStyle(PressStyle()).accessibilityIdentifier("cat-\(c.id)") }
                    }
                }
                let most = store.usage.sorted { $0.value > $1.value }.prefix(4).compactMap { Tools.byId[$0.key] }
                if shows("most") && !most.isEmpty { SectionHead(title: "الأكثر استخداما"); toolGrid(most, compact: true) }
                if shows("rec") { SectionHead(title: "مقترحة لك", sub: "بناء على آخر ما استخدمته"); toolGrid(Array(Tools.suggestions(last: store.recents.first?.tool).prefix(4)), compact: false) }
                if shows("favs") {
                    SectionHead(title: "المفضلة")
                    let favs = store.favorites.compactMap { Tools.byId[$0] }
                    if favs.isEmpty { InlineEmpty(icon: "star", text: "اضغط النجمة في أي أداة لتظهر هنا") } else { toolGrid(Array(favs.prefix(6)), compact: true) }
                }
                if shows("recent") && !store.recents.isEmpty {
                    SectionHead(title: "آخر العمليات", action: ("السجل", { go("activity") }))
                    VStack(spacing: Space.s) {
                        ForEach(store.recents.prefix(4)) { r in
                            if let t = Tools.byId[r.tool] {
                                NavigationLink(value: t) { ActivityRow(icon: t.icon, hex: Tools.hex(t), title: t.title, detail: r.detail.isEmpty ? t.sub : r.detail, date: r.time, action: "إعادة") }.buttonStyle(PressStyle())
                            }
                        }
                    }
                }
                if shows("files") && !outputs.isEmpty {
                    SectionHead(title: "ملفاتك الناتجة", sub: "تحذف تلقائيا بعد 24 ساعة", action: ("الكل", { go("activity") }))
                    VStack(spacing: Space.s) { ForEach(outputs.prefix(4), id: \.self) { u in ActivityRow(icon: fileIcon(u), hex: 0x3346D3, title: u.lastPathComponent, detail: FilesX.human(FilesX.size(u)), date: FilesX.date(u), action: "") } }
                }
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(Brand.text3)
                    Text("ملفاتك تعالج على جهازك. لا حسابات ولا إعلانات، والملفات المؤقتة تحذف تلقائيا بعد 24 ساعة.").font(.plex(.footnote)).foregroundStyle(Brand.text3).multilineTextAlignment(.center)
                }.padding(.vertical, Space.xl)
            }
            .padding(.horizontal, Space.l).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(Brand.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { outputs = FilesX.outputs() }
    }

    private func toolGrid(_ list: [Tool], compact: Bool) -> some View {
        LazyVGrid(columns: compact ? [GridItem(.adaptive(minimum: 300), spacing: Space.m)] : cols, spacing: Space.m) {
            ForEach(list) { t in NavigationLink(value: t) { if compact { ToolRow(tool: t, compact: true) } else { ToolCard(tool: t) } }.buttonStyle(PressStyle()) }
        }
    }

    private var header: some View {
        HStack {
            Button { theme = (theme == "dark") ? "light" : "dark" } label: {
                Image(systemName: theme == "dark" ? "sun.max" : "moon").font(.system(size: 18)).foregroundStyle(Brand.text2).frame(width: 44, height: 44)
            }.accessibilityLabel(theme == "dark" ? "الوضع الفاتح" : "الوضع الداكن")
            Spacer()
            HStack(spacing: Space.s) { LogoMark(size: 34); Text("ميسر").font(.plex(.title2, .bold)).foregroundStyle(Brand.text1) }
            Spacer()
            Button { go("settings") } label: { Image(systemName: "gearshape").font(.system(size: 18)).foregroundStyle(Brand.text2).frame(width: 44, height: 44) }.accessibilityLabel("الإعدادات")
        }.padding(.top, Space.s)
    }

    private var greeting: some View {
        let h = Calendar.current.component(.hour, from: Date())
        let hello = (4...11).contains(h) ? "صباح الخير" : (12...16).contains(h) ? "مساء النور" : "مساء الخير"
        return VStack(spacing: 4) {
            Text(name.isEmpty ? hello : "\(hello)، \(name)").font(.plex(.title, .bold)).foregroundStyle(Brand.text1)
            Text("ماذا تريد أن تنجز اليوم؟ كل المعالجة على جهازك.").font(.plex(.subheadline)).foregroundStyle(Brand.text2)
        }.multilineTextAlignment(.center).padding(.top, Space.s)
    }

    private var searchEntry: some View {
        HStack(spacing: Space.m) {
            Button { go("search") } label: {
                HStack(spacing: Space.m) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Brand.text3)
                    Text("ابحث بالاسم أو الوظيفة: تصغير ملف، دمج…").font(.plex(.subheadline)).foregroundStyle(Brand.text3).lineLimit(1)
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("home-search")
            Button { go("assistant") } label: {
                Label("المساعد", systemImage: "sparkles").font(.plex(.caption, .semibold)).foregroundStyle(Brand.accent)
                    .padding(.horizontal, 10).padding(.vertical, 8).background(Brand.accentSoft, in: RoundedRectangle(cornerRadius: Radius.s))
            }.buttonStyle(PressStyle())
        }
        .padding(.leading, Space.l).padding(.trailing, 6).frame(minHeight: 56).card()
    }
}

struct LogoMark: View {
    let size: CGFloat
    var body: some View {
        Image("LaunchLogo").resizable().scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct SectionHead: View {
    let title: String; var sub: String? = nil; var action: (String, () -> Void)? = nil
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: Space.s) {
                Capsule().fill(Brand.border).frame(width: 18, height: 2)
                Text(title).font(.plex(.headline, .semibold)).foregroundStyle(Brand.text1)
                Capsule().fill(Brand.border).frame(width: 18, height: 2)
            }
            if let sub { Text(sub).font(.plex(.caption)).foregroundStyle(Brand.text3) }
            if let action { Button(action.0, action: action.1).font(.plex(.caption, .semibold)) }
        }.frame(maxWidth: .infinity).padding(.top, Space.l).multilineTextAlignment(.center)
    }
}

struct FeaturedCard: View {
    let tool: Tool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: tool.icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(Brand.tone(Tools.hex(tool)))
                .frame(width: 50, height: 50).background(Brand.toneSoft(Tools.hex(tool)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(tool.title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1).lineLimit(1)
            Text(tool.sub).font(.plex(.caption2)).foregroundStyle(Brand.text3).lineLimit(1)
        }
        .multilineTextAlignment(.center).padding(Space.m).frame(maxWidth: .infinity, minHeight: 132).card()
    }
}

struct CategoryCard: View {
    let cat: Category
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: cat.icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(Brand.onAccentFor)
                .frame(width: 52, height: 52).background(Brand.tone(cat.hex), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(cat.title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1).lineLimit(1)
            Text(cat.blurb).font(.plex(.caption2)).foregroundStyle(Brand.text2).lineLimit(2, reservesSpace: true)
            Spacer(minLength: 0)
            HStack(spacing: 2) { Text("\(Tools.inCat(cat.id).count) أداة"); Image(systemName: "chevron.backward").font(.caption2) }
                .font(.plex(.caption, .semibold)).foregroundStyle(Brand.tone(cat.hex))
        }
        .multilineTextAlignment(.center).padding(Space.m).frame(maxWidth: .infinity, minHeight: 168).card().contentShape(Rectangle())
    }
}

struct ActivityRow: View {
    let icon: String; let hex: UInt32; let title: String; let detail: String; let date: Date; let action: String
    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: icon).foregroundStyle(Brand.tone(hex)).frame(width: 40, height: 40).background(Brand.toneSoft(hex), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1).lineLimit(1)
                (Text(detail) + Text(" • ") + Text(date, style: .relative)).font(.plex(.caption)).foregroundStyle(Brand.text3).lineLimit(1)
            }
            Spacer(minLength: 0)
            if !action.isEmpty { Text(action).font(.plex(.caption, .semibold)).foregroundStyle(Brand.accent) }
        }.padding(Space.m).card(Radius.m).contentShape(Rectangle())
    }
}

struct InlineEmpty: View {
    let icon: String; let text: String
    var body: some View {
        Label(text, systemImage: icon).font(.plex(.footnote)).foregroundStyle(Brand.text2).frame(maxWidth: .infinity).padding(Space.l)
            .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(Brand.border, lineWidth: 1))
    }
}

func fileIcon(_ u: URL) -> String {
    switch u.pathExtension.lowercased() {
    case "pdf": return "doc.richtext"; case "jpg", "jpeg", "png", "heic": return "photo"; case "zip": return "doc.zipper"
    case "docx": return "doc.text"; case "xlsx": return "tablecells"; case "pptx": return "rectangle.stack"; case "m4a", "wav": return "waveform"
    default: return "doc"
    }
}

struct CategoryView: View {
    let cat: Category
    @Environment(\.horizontalSizeClass) private var hsize
    var body: some View {
        let tools = Tools.inCat(cat.id)
        ScrollView {
            VStack(spacing: Space.m) {
                VStack(spacing: 6) {
                    Image(systemName: cat.icon).font(.system(size: 28, weight: .semibold)).foregroundStyle(Brand.onAccentFor)
                        .frame(width: 64, height: 64).background(Brand.tone(cat.hex), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Text(cat.blurb).font(.plex(.subheadline)).foregroundStyle(Brand.text2)
                    Text("\(tools.count) أداة").font(.plex(.caption, .semibold)).foregroundStyle(Brand.tone(cat.hex))
                        .padding(.horizontal, 12).padding(.vertical, 4).background(Brand.toneSoft(cat.hex), in: Capsule())
                }.multilineTextAlignment(.center).padding(.vertical, Space.m)
                if tools.isEmpty { EmptyStateView(icon: "square.grid.2x2", title: "لا توجد أدوات هنا", text: "ارجع إلى الرئيسية واختر قسما آخر.") }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.m), count: hsize == .regular ? 4 : 2), spacing: Space.m) {
                    ForEach(tools) { t in NavigationLink(value: t) { ToolCard(tool: t) }.buttonStyle(PressStyle()).accessibilityIdentifier("tool-\(t.id)") }
                }
            }.padding(.horizontal, Space.l).padding(.bottom, Space.xxl).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(Brand.bg)
        .navigationTitle(cat.title).navigationBarTitleDisplayMode(.inline)
    }
}
