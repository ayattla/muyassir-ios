import SwiftUI
import WidgetKit

/// Home-screen widget: one-tap tools and recipes (opens the app at that screen; nothing runs in the background).
struct QuickEntry: TimelineEntry { let date: Date }

struct QuickProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickEntry { QuickEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (QuickEntry) -> Void) { completion(QuickEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickEntry>) -> Void) { completion(Timeline(entries: [QuickEntry(date: Date())], policy: .never)) }
}

struct QuickWidgetView: View {
    private let items: [(String, String, String)] = [("مسح", "doc.viewfinder", "muyassir://tool/scan"), ("ضغط PDF", "arrow.down.right.and.arrow.up.left", "muyassir://tool/pdf_compress"),
                                                     ("صور إلى PDF", "photo.on.rectangle", "muyassir://tool/img_pdf"), ("الوصفات", "wand.and.stars", "muyassir://recipes")]
    var body: some View {
        VStack(spacing: 8) {
            Text("مُيسّر").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(red: 0.08, green: 0.1, blue: 0.18))
            HStack(spacing: 6) {
                ForEach(items, id: \.0) { label, icon, url in
                    Link(destination: URL(string: url)!) {
                        VStack(spacing: 4) {
                            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                            Text(label).font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(Color(red: 0.2, green: 0.27, blue: 0.83))
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Color(red: 0.925, green: 0.933, blue: 0.99), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(.white, for: .widget)
    }
}

struct QuickWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "quick", provider: QuickProvider()) { _ in QuickWidgetView() }
            .configurationDisplayName("مُيسّر السريع")
            .description("مسح وضغط وتحويل بلمسة، والوصفات.")
            .supportedFamilies([.systemMedium])
    }
}

@main
struct MuyassirWidgets: WidgetBundle { var body: some Widget { QuickWidget() } }
