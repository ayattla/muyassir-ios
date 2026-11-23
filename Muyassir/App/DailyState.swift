import Foundation
import SwiftUI
import WidgetKit

/// What «يومي» shows. Everything stays on the device (Store obj "daily"), same keys as Android.
final class Daily: ObservableObject {
    static let shared = Daily()
    @Published private(set) var setupDone = false
    @Published private(set) var roles: [String] = []        // student, teacher, employee, business
    @Published private(set) var city = "riyadh"
    @Published private(set) var showPrayer = true
    @Published private(set) var salary = "gov"              // gov | custom | none
    @Published private(set) var salaryDay = 27
    @Published private(set) var showCitizen = false
    @Published private(set) var showPension = false
    @Published private(set) var showDocs = true
    @Published private(set) var showAdhkar = true

    private init() { load() }

    func load() {
        let o = Store.shared.obj("daily")
        setupDone = o["done"] as? Bool ?? false
        roles = o["roles"] as? [String] ?? []
        if roles.isEmpty, let r = UserDefaults.standard.string(forKey: "role"), !r.isEmpty, r != "none" { roles = [r] }
        city = o["city"] as? String ?? "riyadh"; showPrayer = o["prayer"] as? Bool ?? true
        salary = o["salary"] as? String ?? "gov"; salaryDay = o["salaryDay"] as? Int ?? 27
        showCitizen = o["citizen"] as? Bool ?? false; showPension = o["pension"] as? Bool ?? false
        showDocs = o["docs"] as? Bool ?? true; showAdhkar = o["adhkar"] as? Bool ?? true
    }

    private func save() {
        Store.shared.saveObj("daily", ["done": setupDone, "roles": roles, "city": city, "prayer": showPrayer, "salary": salary, "salaryDay": salaryDay,
                                       "citizen": showCitizen, "pension": showPension, "docs": showDocs, "adhkar": showAdhkar])
        syncWidget()
    }

    /// Hands the widget what it shows: city, the next pay day and the nearest document date (no names).
    func syncWidget(_ now: Date = Date()) {
        var w = WidgetSnapshot(); w.city = city; w.prayer = showPrayer
        if let r = payRules().first { let (_, d) = PayDays.next(r, now); w.payTitle = r.title; w.payDate = d }
        if showDocs {
            let t = KSA.cal.startOfDay(for: now).timeIntervalSince1970
            w.docDate = Store.shared.list("documents").map { $0.d("expiry") }.filter { $0 >= t && $0 <= t + 60 * 86_400 }.min().map { Date(timeIntervalSince1970: $0) }
        }
        w.write(); WidgetCenter.shared.reloadAllTimelines()
    }

    func toggleRole(_ r: String) {
        if let i = roles.firstIndex(of: r) { roles.remove(at: i) } else { roles.append(r) }
        UserDefaults.standard.set(roles.first ?? "none", forKey: "role"); save()
    }
    func chooseCity(_ id: String) { city = Cities.byId(id).id; save() }
    func setPrayer(_ v: Bool) { showPrayer = v; save() }
    func setSalary(_ kind: String, day: Int? = nil) { salary = kind; salaryDay = min(max(day ?? salaryDay, 1), 31); save() }
    func setCitizen(_ v: Bool) { showCitizen = v; save() }
    func setPension(_ v: Bool) { showPension = v; save() }
    func setDocs(_ v: Bool) { showDocs = v; save() }
    func setAdhkar(_ v: Bool) { showAdhkar = v; save() }
    func finishSetup() { setupDone = true; save() }

    /// Payment rules the person follows, in display order.
    func payRules() -> [PayDays.Rule] {
        var r: [PayDays.Rule] = []
        switch salary { case "gov": r.append(PayDays.gov); case "custom": r.append(PayDays.custom(salaryDay)); default: break }
        if showCitizen { r.append(PayDays.citizen) }
        if showPension { r.append(PayDays.pension) }
        return r
    }

    func resetForTest() { Store.shared.saveObj("daily", [:]); load() }
}
