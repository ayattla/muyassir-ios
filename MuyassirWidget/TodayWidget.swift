import SwiftUI
import WidgetKit

/// «يومي» on the home screen: the next prayer with a live countdown, the next pay day and the nearest document.
/// One entry per prayer, so the widget moves on to the next prayer by itself without waking the app.
struct TodayEntry: TimelineEntry {
    let date: Date
    let city: String
    let prayer: String?
    let prayerAt: Date?
    let pay: String?
    let doc: String?
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { TodayEntry(date: Date(), city: "الرياض", prayer: "العصر", prayerAt: Date().addingTimeInterval(5400), pay: "راتب الدولة بعد 3 أيام", doc: nil) }
    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) { completion(entries(from: Date()).first ?? placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let list = entries(from: Date())
        completion(Timeline(entries: list, policy: .after(list.last?.date.addingTimeInterval(60) ?? Date().addingTimeInterval(3600))))
    }

    /// Entries for now and for each prayer over the next day.
    private func entries(from now: Date) -> [TodayEntry] {
        let s = WidgetSnapshot.read(), city = Cities.byId(s.city)
        var marks = [now]
        if s.prayer { marks += prayerDates(city, from: now).map { $0.1 }.filter { $0 > now }.prefix(6) }
        return marks.map { at in
            let next = s.prayer ? prayerDates(city, from: at).first { $0.1 > at } : nil
            return TodayEntry(date: at, city: city.name, prayer: next.map { PrayerTimes.names[$0.0] }, prayerAt: next?.1,
                              pay: s.payTitle.flatMap { t in s.payDate.flatMap { label(t, days(at, $0)) } }, doc: s.docDate.flatMap { label("وثيقة تنتهي", days(at, $0)) })
        }
    }

    /// The five prayers of today and tomorrow, as (name index, time).
    private func prayerDates(_ city: Cities.City, from: Date) -> [(Int, Date)] {
        let cal = KSA.cal
        return (0...1).flatMap { off -> [(Int, Date)] in
            let day = cal.date(byAdding: .day, value: off, to: from)!
            let t = PrayerTimes.today(city, day), start = cal.startOfDay(for: day)
            return [0, 2, 3, 4, 5].map { ($0, start.addingTimeInterval(Double(t[$0]) * 60)) }
        }
    }
    private func days(_ from: Date, _ to: Date) -> Int { KSA.cal.dateComponents([.day], from: KSA.cal.startOfDay(for: from), to: KSA.cal.startOfDay(for: to)).day ?? 0 }
    private func label(_ title: String, _ d: Int) -> String? { d < 0 ? nil : d == 0 ? "\(title) اليوم" : "\(title) بعد \(d) \((3...10).contains(d) ? "أيام" : "يوما")" }
}

struct TodayWidgetView: View {
    let e: TodayEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        VStack(spacing: 6) {
            if let p = e.prayer, let at = e.prayerAt {
                Text("صلاة \(p) في \(e.city)").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                Text(at, style: .timer).font(.system(size: family == .systemSmall ? 26 : 30, weight: .bold)).monospacedDigit().foregroundStyle(.white).multilineTextAlignment(.center)
                Text(at, style: .time).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            } else {
                Text("يومي").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            }
            if family != .systemSmall || e.prayer == nil {
                ForEach([e.pay, e.doc].compactMap { $0 }, id: \.self) {
                    Text($0).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(Color(red: 0.2, green: 0.275, blue: 0.827), for: .widget)
        .widgetURL(URL(string: "muyassir://today"))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today", provider: TodayProvider()) { TodayWidgetView(e: $0) }
            .configurationDisplayName("يومي")
            .description("الصلاة القادمة وموعد الراتب وأقرب وثيقة.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
