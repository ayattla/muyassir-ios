import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var q = ""
    private let grid = [GridItem(.adaptive(minimum: 300), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: grid, alignment: .leading, spacing: 10) {
                if !q.isEmpty {
                    let res = Tools.search(q, usage: store.usage)
                    Section { ForEach(res) { t in NavigationLink(value: t) { ToolRow(tool: t) }.buttonStyle(.plain) } } header: { header(res.isEmpty ? "لا توجد أداة بهذا الاسم" : "\(res.count) نتيجة") }
                } else {
                    Section { EmptyView() } header: { quick }
                    Section { ForEach(Tools.categories) { c in NavigationLink(value: c) { CategoryCard(cat: c) }.buttonStyle(.plain) } } header: { header("التصنيفات") }
                    let favs = store.favorites.compactMap { Tools.byId[$0] }
                    if !favs.isEmpty { Section { ForEach(favs) { t in NavigationLink(value: t) { ToolRow(tool: t, compact: true) }.buttonStyle(.plain) } } header: { header("المفضلة") } }
                    let most = store.usage.sorted { $0.value > $1.value }.prefix(6).compactMap { Tools.byId[$0.key] }
                    if !most.isEmpty { Section { ForEach(most) { t in NavigationLink(value: t) { ToolRow(tool: t, compact: true) }.buttonStyle(.plain) } } header: { header("الأكثر استخدامًا") } }
                    Section { ForEach(Tools.suggestions(last: store.recents.first?.tool)) { t in NavigationLink(value: t) { ToolRow(tool: t) }.buttonStyle(.plain) } } header: { header("مقترحة لك") }
                    if !store.recents.isEmpty {
                        Section {
                            ForEach(store.recents.prefix(8)) { r in
                                if let t = Tools.byId[r.tool] {
                                    NavigationLink(value: t) {
                                        HStack {
                                            Image(systemName: t.icon).foregroundStyle(Tools.color(t)).frame(width: 28)
                                            VStack(alignment: .leading) { Text(t.title).font(.plex(.subheadline, .semibold)); if !r.detail.isEmpty { Text(r.detail).font(.plex(.caption)).foregroundStyle(.secondary).lineLimit(1) } }
                                            Spacer(); Text(r.time, style: .relative).font(.plex(.caption2)).foregroundStyle(.secondary)
                                        }.padding(.vertical, 6).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                            }
                        } header: { HStack { header("آخر العمليات"); Spacer(); Button("مسح") { store.clearRecents() }.font(.plex(.subheadline)) } }
                    }
                    Section { EmptyView() } footer: {
                        Text("ملفاتك تُعالَج على جهازك. لا حسابات ولا إعلانات. الملفات المؤقتة تُحذف تلقائيًا بعد 24 ساعة.").font(.plex(.footnote)).foregroundStyle(.secondary).padding(.vertical, 20)
                    }
                }
            }
            .padding(16).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("مُيسّر")
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث: دمج PDF، ضريبة، إزالة خلفية…")
    }

    private func header(_ t: String) -> some View { Text(t).font(.plex(.headline, .semibold)).padding(.top, 10).frame(maxWidth: .infinity, alignment: .leading) }

    private var quick: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(["scan", "pdf_merge", "ocr", "img_bg", "qr_read", "vat"], id: \.self) { id in
                    let t = Tools.byId[id]!
                    NavigationLink(value: t) {
                        VStack(spacing: 6) {
                            Image(systemName: t.icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 56, height: 56).background(Tools.color(t), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            Text(t.title).font(.plex(.caption, .medium)).foregroundStyle(.primary).multilineTextAlignment(.center).lineLimit(2).frame(width: 86)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryCard: View {
    let cat: Category
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cat.icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 50, height: 50).background(cat.color, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(cat.title).font(.plex(.headline, .semibold)).foregroundStyle(.primary)
                Text(cat.blurb).font(.plex(.caption)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text("\(Tools.inCat(cat.id).count)").font(.plex(.headline, .bold)).foregroundStyle(cat.color)
        }
        .padding(14).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CategoryView: View {
    let cat: Category
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                ForEach(Tools.inCat(cat.id)) { t in NavigationLink(value: t) { ToolRow(tool: t) }.buttonStyle(.plain) }
            }.padding(16).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(cat.title)
    }
}
