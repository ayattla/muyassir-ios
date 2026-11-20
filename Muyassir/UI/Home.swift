import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var q = ""
    private let rows = [GridItem(.adaptive(minimum: 320), spacing: 10)]
    private let tiles = [GridItem(.adaptive(minimum: 160), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !q.isEmpty {
                    let res = Tools.search(q, usage: store.usage)
                    header(res.isEmpty ? "لا توجد أداة بهذا الاسم" : "\(res.count) نتيجة")
                    if res.isEmpty { EmptyStateView(icon: "magnifyingglass", title: "لم نجد «\(q)»", text: "جرّب كلمة أقصر مثل: PDF، صورة، راتب، QR") }
                    LazyVGrid(columns: rows, spacing: 10) { ForEach(res) { t in link(t) } }
                } else {
                    hero
                    header("اختصارات سريعة")
                    quick
                    header("التصنيفات")
                    LazyVGrid(columns: tiles, spacing: 10) {
                        ForEach(Tools.categories) { c in NavigationLink(value: c) { CategoryCard(cat: c) }.buttonStyle(.plain).accessibilityIdentifier("cat-\(c.id)") }
                    }
                    let favs = store.favorites.compactMap { Tools.byId[$0] }
                    if !favs.isEmpty { header("المفضلة"); LazyVGrid(columns: rows, spacing: 10) { ForEach(favs) { t in link(t, compact: true) } } }
                    let most = store.usage.sorted { $0.value > $1.value }.prefix(4).compactMap { Tools.byId[$0.key] }
                    if !most.isEmpty { header("الأكثر استخدامًا"); LazyVGrid(columns: rows, spacing: 10) { ForEach(most) { t in link(t, compact: true) } } }
                    header("مقترحة لك")
                    LazyVGrid(columns: rows, spacing: 10) { ForEach(Tools.suggestions(last: store.recents.first?.tool)) { t in link(t) } }
                    if !store.recents.isEmpty {
                        HStack { header("آخر العمليات"); Spacer(); Button("مسح السجل") { store.clearRecents() }.font(.plex(.subheadline)).padding(.top, 12) }
                        LazyVGrid(columns: rows, spacing: 8) {
                            ForEach(store.recents.prefix(6)) { r in
                                if let t = Tools.byId[r.tool] {
                                    NavigationLink(value: t) {
                                        HStack(spacing: 12) {
                                            Image(systemName: t.icon).foregroundStyle(Tools.color(t)).frame(width: 36, height: 36).background(Tools.color(t).opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                                            VStack(alignment: .leading) { Text(t.title).font(.plex(.subheadline, .semibold)); if !r.detail.isEmpty { Text(r.detail).font(.plex(.caption)).foregroundStyle(.secondary).lineLimit(1) } }
                                            Spacer(); Text(r.time, style: .relative).font(.plex(.caption2)).foregroundStyle(.secondary)
                                        }.padding(12).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Label("ملفاتك تُعالَج على جهازك. لا حسابات ولا إعلانات، والملفات المؤقتة تُحذف تلقائيًا بعد 24 ساعة.", systemImage: "lock")
                        .font(.plex(.footnote)).foregroundStyle(.secondary).padding(.vertical, 18)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("مُيسّر")
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث عن أداة")
    }

    private func header(_ t: String) -> some View { Text(t).font(.plex(.headline, .semibold)).padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading) }
    private func link(_ t: Tool, compact: Bool = false) -> some View { NavigationLink(value: t) { ToolRow(tool: t, compact: compact) }.buttonStyle(.plain).accessibilityIdentifier("tool-\(t.id)") }

    /// The one bold element: a lapis band with the promise of the app.
    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Tools.all.count) أداة في جيبك").font(.plex(.title3, .bold)).foregroundStyle(.white)
                Text("تحويل وPDF وصور وحاسبات سعودية، تعمل على جهازك بلا رفع ولا اشتراك.").font(.plex(.subheadline)).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            ZStack(alignment: .topLeading) {
                Image(systemName: "checkmark").font(.system(size: 22, weight: .bold)).foregroundStyle(.white).frame(width: 52, height: 52).background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 15))
                Circle().fill(Brand.saffron).frame(width: 9, height: 9).padding(8)
            }
        }
        .padding(18)
        .background(LinearGradient(colors: [Color(hex: 0x3B57FF), Color(hex: 0x1E2FC4)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.top, 4)
    }

    private var quick: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(["pdf_merge", "pdf_compress", "ocr", "img_compress", "img_bg", "scan", "vat", "qr_read"], id: \.self) { id in
                let t = Tools.byId[id]!
                NavigationLink(value: t) {
                    VStack(spacing: 6) {
                        Image(systemName: t.icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(Tools.color(t))
                            .frame(width: 56, height: 56).background(Tools.color(t).opacity(0.13), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        Text(t.title).font(.plex(.caption, .medium)).foregroundStyle(.primary).multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                    }.frame(maxWidth: .infinity).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }
}

struct CategoryCard: View {
    let cat: Category
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: cat.icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(cat.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Spacer()
                Text("\(Tools.inCat(cat.id).count) أداة").font(.plex(.caption, .semibold)).foregroundStyle(cat.color)
                    .padding(.horizontal, 9).padding(.vertical, 4).background(cat.color.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 10)
            Text(cat.title).font(.plex(.headline, .semibold)).foregroundStyle(.primary).lineLimit(1)
            Text(cat.blurb).font(.plex(.caption)).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct CategoryView: View {
    let cat: Category
    var body: some View {
        let tools = Tools.inCat(cat.id)
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: cat.icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(cat.color, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(tools.count) أداة").font(.plex(.headline, .semibold)).foregroundStyle(cat.color)
                        Text(cat.blurb).font(.plex(.subheadline)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16).background(cat.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                if tools.isEmpty { EmptyStateView(icon: "square.grid.2x2", title: "لا توجد أدوات هنا", text: "ارجع إلى الرئيسية واختر تصنيفًا آخر.") }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 10)], spacing: 10) {
                    ForEach(tools) { t in NavigationLink(value: t) { ToolRow(tool: t) }.buttonStyle(.plain).accessibilityIdentifier("tool-\(t.id)") }
                }
            }.padding(16).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(cat.title)
    }
}
