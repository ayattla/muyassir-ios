import Foundation

/// What the «يومي» widget needs, written by the app into the shared App Group. Only settings and dates, never document names.
struct WidgetSnapshot: Codable {
    var city = "riyadh"
    var prayer = true
    var payTitle: String?
    var payDate: Date?
    var docDate: Date?

    static let group = "group.com.muyassir.app"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

    static func read() -> WidgetSnapshot {
        guard let d = defaults?.data(forKey: "daily"), let s = try? JSONDecoder().decode(WidgetSnapshot.self, from: d) else { return WidgetSnapshot() }
        return s
    }
    func write() { if let d = try? JSONEncoder().encode(self) { Self.defaults?.set(d, forKey: "daily") } }
}
