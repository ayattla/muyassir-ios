import Foundation
import StoreKit
import SwiftUI
import UserNotifications

/// «مُيسّر بلس»: one place that decides what is free and what needs the subscription, plus StoreKit 2.
///
/// Launch rule (from the monetization plan): the app ships fully free. Limits only start once the App Store
/// actually offers the Plus products (`live`); until then every gate is open and the paywall says «قريبًا».
/// Everything is checked on the device (StoreKit 2 verifies the signed transactions); there is no server.
@MainActor
final class Plus: ObservableObject {
    static let shared = Plus()

    // ---- the free tier, exactly as in the plan ----
    static let freeOpsPerDay = 5, freeFiles = 5, freeMB = 20, freeOcrPages = 3, plusFiles = 100, plusMB = 500
    static let footer = "أُنشئ بمُيسّر"

    /// App Store Connect products (see docs/PLUS.md). Subscription group «مُيسّر بلس».
    static let monthlyID = "com.muyassir.app.plus.monthly", yearlyID = "com.muyassir.app.plus.yearly", dayID = "com.muyassir.app.plus.day"

    /// Tools whose runs count toward the daily free operations (files and images).
    static let metered: Set<String> = [
        "pdf_word", "word_pdf", "pdf_excel", "excel_pdf", "pdf_ppt", "ppt_pdf", "pdf_img", "img_pdf", "pdf_merge", "pdf_split",
        "pdf_compress", "pdf_reorder", "pdf_delete", "pdf_extract", "pdf_rotate", "ocr", "pdf_protect", "pdf_unlock",
        "zip", "unzip", "img_convert", "img_compress", "img_resize", "img_crop", "img_rotate", "img_enhance", "img_bg",
        "img_batch", "id_photo", "pdf_edit",
    ]

    enum Reason: String, Identifiable, CaseIterable {
        case daily = "Daily", files = "Files", size = "Size", ocr = "Ocr", template = "Template", quality = "Quality", sizes = "Sizes"
        case sign = "Sign", export = "Export", lock = "Lock", look = "Look", support = "Support", recipe = "Recipe", ai = "Ai", backup = "Backup", menu = "Menu"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: "استخدمت عملياتك المجانية لليوم"
            case .files: "المعالجة الدفعية من ميزات بلس"
            case .size: "الملفات الكبيرة من ميزات بلس"
            case .ocr: "استخراج النص من ملف كامل من ميزات بلس"
            case .template: "القوالب الاحترافية من ميزات بلس"
            case .quality: "الدقة العالية من ميزات بلس"
            case .sizes: "كل المقاسات من ميزات بلس"
            case .sign: "التوقيع المحفوظ والأختام من ميزات بلس"
            case .export: "تصدير السجلات من ميزات بلس"
            case .lock: "قفل الملاحظات والوثائق من ميزات بلس"
            case .look: "تخصيص المظهر من ميزات بلس"
            case .support: "الدعم ذو الأولوية من ميزات بلس"
            case .recipe: "الوصفات المخصصة من ميزات بلس"
            case .ai: "المساعد الذكي من ميزات بلس"
            case .backup: "النسخ الاحتياطي من ميزات بلس"
            case .menu: "مُيسّر بلس"
            }
        }
        var body: String {
            switch self {
            case .daily: "لديك \(Plus.freeOpsPerDay) عمليات مجانية يوميًا لأدوات الملفات والصور، وتتجدد غدًا. أو افتحها الآن بلا حدود مع بلس."
            case .files: "المجاني يعالج حتى \(Plus.freeFiles) ملفات في العملية الواحدة. مع بلس حتى \(Plus.plusFiles) ملف دفعة واحدة."
            case .size: "المجاني يقبل ملفات حتى \(Plus.freeMB) م.ب. مع بلس حتى \(Plus.plusMB) م.ب حسب ذاكرة جهازك."
            case .ocr: "المجاني يستخرج النص من \(Plus.freeOcrPages) صفحات في العملية. مع بلس ملف PDF كامل وملف PDF قابل للبحث."
            case .template: "المجاني يشمل القالب الكلاسيكي. مع بلس أكثر من 20 قالبًا وشعار منشأتك ودون سطر «\(Plus.footer)»."
            case .quality: "المجاني يحفظ بدقة عادية. مع بلس دقة عالية وألوان خلفية مخصصة."
            case .sizes: "المجاني يشمل مقاسين. مع بلس كل المقاسات وورقة طباعة جاهزة."
            case .sign: "احفظ توقيعك مرة واحدة، وأضف ختمًا أو علامة مائية لمستنداتك."
            case .export: "صدّر المصاريف والحضور والمهام وغيرها إلى Excel وPDF."
            case .lock: "احمِ ملاحظاتك ووثائقك ببصمة الوجه أو الإصبع."
            case .look: "اختر لونًا مميزًا للتطبيق وأيقونة بديلة."
            case .support: "رسائلك تصل بعلامة «بلس» ويُرد عليها أولًا."
            case .recipe: "الوصفات الجاهزة مجانية للجميع. مع بلس اصنع وصفاتك الخاصة واحفظها."
            case .ai: "جرّب التلخيص والتدقيق مرة يوميًا مجانًا. مع بلس بلا حدود."
            case .backup: "احفظ نسخة مشفّرة من بياناتك في المكان الذي تختاره، واستعدها على جهاز جديد."
            case .menu: ""
            }
        }
    }

    struct Plan: Identifiable {
        let id: String, title: String, price: String, period: String, note: String, trialDays: Int, amount: Decimal
        let product: Product?
    }

    @Published var live = false { didSet { syncLook() } }
    @Published var subscribed = false { didSet { syncLook() } }
    @Published var dayPassUntil: Date = .distantPast { didSet { syncLook() } }
    @Published var planName = ""
    @Published var renews = true
    @Published var usedToday = 0
    @Published var notifyWhenLive = false
    @Published var paywall: Reason?
    @Published var plans: [Plan] = []
    @Published var busy = false
    @Published var message: String?

    var active: Bool { subscribed || dayPassUntil > Date() }
    /// A feature is open to this user: Plus, or Plus not launched yet.
    var unlocked: Bool { active || !live }
    var opsLeft: Int { unlocked ? .max : max(0, Self.freeOpsPerDay - usedToday) }
    var ocrPages: Int { unlocked ? .max : Self.freeOcrPages }

    private var day = ""
    private var updates: Task<Void, Never>?
    private var testing = false
    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f }()

    private init() {
        let o = Store.shared.obj("plus")
        day = o["day"] as? String ?? ""; usedToday = o["used"] as? Int ?? 0
        dayPassUntil = Date(timeIntervalSince1970: o["dayPassUntil"] as? Double ?? 0)
        notifyWhenLive = o["notify"] as? Bool ?? false
        rollDay()
    }

    /// The accent colour is a Plus feature: keep the effective choice in `accentActive`.
    func syncLook() {
        let d = UserDefaults.standard, want = unlocked ? d.integer(forKey: "accent") : 0
        if d.integer(forKey: "accentActive") != want { d.set(want, forKey: "accentActive") }
    }

    private func save() {
        Store.shared.saveObj("plus", ["day": day, "used": usedToday, "dayPassUntil": dayPassUntil.timeIntervalSince1970, "notify": notifyWhenLive])
    }
    private func rollDay() { let t = Self.dayFmt.string(from: Date()); if t != day { day = t; usedToday = 0; save() } }

    /// Gate a feature: true if it may be used, otherwise shows the paywall.
    @discardableResult func allow(_ r: Reason) -> Bool { if unlocked { return true }; paywall = r; return false }

    /// Check a metered run before it starts. Returns why it is blocked, or nil.
    static func isMetered(_ tool: String) -> Bool { metered.contains(tool) || tool.hasPrefix("recipe:") }

    func check(_ tool: String, sizes: [Int64]) -> Reason? {
        guard Self.isMetered(tool) else { return nil }
        if !unlocked { rollDay(); if usedToday >= Self.freeOpsPerDay { return .daily } }
        guard !unlocked || live else { return nil } // before launch: no limits at all
        let maxFiles = unlocked ? Self.plusFiles : Self.freeFiles
        let maxBytes = Int64(unlocked ? Self.plusMB : Self.freeMB) * 1024 * 1024
        if sizes.count > maxFiles { return .files }
        if sizes.contains(where: { $0 > maxBytes }) { return .size }
        return nil
    }

    func counted(_ tool: String) { if Self.isMetered(tool) && !active { rollDay(); usedToday += 1; save() } }
    func toggleNotify() { notifyWhenLive.toggle(); save() }

    /// Smart text tools (summary, review questions): one free use a day, unlimited with Plus.
    func useAi() -> Bool {
        if unlocked { return true }
        rollDay()
        let o = Store.shared.obj("plus_ai"), used = (o["day"] as? String) == day ? (o["n"] as? Int ?? 0) : 0
        if used >= 1 { paywall = .ai; return false }
        Store.shared.saveObj("plus_ai", ["day": day, "n": used + 1]); return true
    }

    // MARK: StoreKit 2

    func start() {
        syncLook()
        guard updates == nil, !testing else { return }
        updates = Task { [weak self] in
            for await r in Transaction.updates { if case .verified(let t) = r { await t.finish(); await self?.refresh() } }
        }
        Task { await loadProducts(); await refresh() }
    }

    func loadProducts() async {
        guard let ps = try? await Product.products(for: [Self.monthlyID, Self.yearlyID, Self.dayID]) else { return }
        var list: [Plan] = []
        let monthly = ps.first { $0.id == Self.monthlyID }, yearly = ps.first { $0.id == Self.yearlyID }
        if let y = yearly {
            var trial = 0
            if let o = y.subscription?.introductoryOffer, o.paymentMode == .freeTrial, await y.subscription?.isEligibleForIntroOffer == true { trial = Self.days(o.period) }
            let perMonth = ((y.price / 12) as NSDecimalNumber).doubleValue
            list.append(Plan(id: "yearly", title: "سنوي", price: y.displayPrice, period: "سنة",
                             note: "يعادل \(String(format: "%.2f", perMonth)) \(y.priceFormatStyle.currencyCode == "SAR" ? "ر.س" : y.priceFormatStyle.currencyCode) شهريًا",
                             trialDays: trial, amount: y.price, product: y))
        }
        if let m = monthly { list.append(Plan(id: "monthly", title: "شهري", price: m.displayPrice, period: "شهر", note: "يُلغى في أي وقت", trialDays: 0, amount: m.price, product: m)) }
        if let d = ps.first(where: { $0.id == Self.dayID }) { list.append(Plan(id: "day", title: "مرور يوم", price: d.displayPrice, period: "24 ساعة", note: "كل ميزات بلس ليوم واحد، بلا اشتراك", trialDays: 0, amount: d.price, product: d)) }
        plans = list
        let was = live
        live = yearly != nil && monthly != nil
        if live && !was && notifyWhenLive {
            notifyWhenLive = false; save()
            let c = UNMutableNotificationContent(); c.title = "مُيسّر بلس متاح الآن"; c.body = "افتح العمليات بلا حدود والقوالب الاحترافية وOCR للملفات الكاملة."
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "plus-live", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)))
        }
    }

    private static func days(_ p: Product.SubscriptionPeriod) -> Int {
        switch p.unit { case .day: p.value; case .week: p.value * 7; case .month: p.value * 30; case .year: p.value * 365; @unknown default: p.value }
    }

    /// Reads current entitlements (signed by the App Store, verified on the device).
    func refresh() async {
        guard !testing else { return }
        var sub = false, renewing = true, name = "", pass = dayPassUntil
        for await r in Transaction.currentEntitlements {
            guard case .verified(let t) = r, t.revocationDate == nil else { continue }
            switch t.productID {
            case Self.monthlyID, Self.yearlyID:
                if (t.expirationDate ?? .distantFuture) > Date() { sub = true; name = t.productID == Self.yearlyID ? "اشتراك بلس السنوي" : "اشتراك بلس الشهري" }
            case Self.dayID:
                // non-renewing subscription: 24 hours from purchase
                pass = max(pass, t.purchaseDate.addingTimeInterval(24 * 3600))
            default: break
            }
        }
        if sub, let info = (plans.first { $0.id == "yearly" } ?? plans.first { $0.id == "monthly" })?.product?.subscription,
           let st = (try? await info.status)?.first(where: { $0.state == .subscribed || $0.state == .inGracePeriod }),
           case .verified(let r) = st.renewalInfo { renewing = r.willAutoRenew }
        subscribed = sub; planName = name; renews = renewing
        if pass != dayPassUntil { dayPassUntil = pass; save() }
    }

    func buy(_ plan: Plan) async {
        guard let p = plan.product else { message = "وضع التجربة: لا يتم الدفع في هذه النسخة"; return }
        busy = true; defer { busy = false }
        do {
            switch try await p.purchase() {
            case .success(let r):
                guard case .verified(let t) = r else { message = "تعذّر التحقق من عملية الشراء. لم تُفعَّل بلس."; return }
                await t.finish(); await refresh(); paywall = nil
                message = plan.id == "day" ? "تم تفعيل مرور اليوم لمدة 24 ساعة" : "مرحبًا بك في مُيسّر بلس"
                if plan.trialDays > 0, t.offerType == .introductory {
                    // remind one day before the free trial turns into a paid subscription
                    let c = UNMutableNotificationContent(); c.title = "تجربة مُيسّر بلس تنتهي غدًا"
                    c.body = "إن لم ترغب في الاستمرار ألغِ الاشتراك من إعدادات App Store قبل نهاية التجربة."
                    let at = t.purchaseDate.addingTimeInterval(Double(plan.trialDays - 1) * 86400)
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
                    try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "trial-end", content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                }
            case .pending: message = "عملية الدفع بانتظار الموافقة. ستُفعَّل بلس فور اكتمالها."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "لم تكتمل عملية الشراء. لم يُخصم أي مبلغ." }
    }

    /// Restore purchases: syncs with the App Store, then re-reads entitlements.
    func restore() async {
        busy = true; defer { busy = false }
        try? await AppStore.sync()
        await refresh()
        message = active ? "تمت استعادة اشتراكك" : "لم نجد اشتراكًا على حساب Apple هذا"
    }

    // MARK: test states (DEBUG launch argument `-plus free|free-used|plus|off`)

    func testState(_ s: String) {
        testing = true
        let sample = [
            Plan(id: "yearly", title: "سنوي", price: "SAR 49.99", period: "سنة", note: "يعادل 4.17 ر.س شهريًا", trialDays: 7, amount: 49.99, product: nil),
            Plan(id: "monthly", title: "شهري", price: "SAR 7.99", period: "شهر", note: "يُلغى في أي وقت", trialDays: 0, amount: 7.99, product: nil),
            Plan(id: "day", title: "مرور يوم", price: "SAR 2.99", period: "24 ساعة", note: "كل ميزات بلس ليوم واحد، بلا اشتراك", trialDays: 0, amount: 2.99, product: nil),
        ]
        switch s {
        case "free": plans = sample; live = true; subscribed = false; dayPassUntil = .distantPast; usedToday = 0; day = Self.dayFmt.string(from: Date()); save()
        case "free-used": plans = sample; live = true; subscribed = false; dayPassUntil = .distantPast; usedToday = Self.freeOpsPerDay; day = Self.dayFmt.string(from: Date()); save()
        case "plus": plans = sample; live = true; subscribed = true; planName = "اشتراك بلس السنوي"
        default: live = false; subscribed = false; usedToday = 0; save()
        }
    }

    static let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}
