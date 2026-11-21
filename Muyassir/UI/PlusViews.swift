import SwiftUI
import LocalAuthentication
import PhotosUI

let privacyURL = URL(string: "https://github.com/ayattla/muyassir-ios/blob/main/docs/PRIVACY.md")!
let termsURL = URL(string: "https://github.com/ayattla/muyassir-ios/blob/main/docs/TERMS.md")!
/// Support address. Empty = use the project's public feedback page instead.
let supportEmail = ""

/// Small «بلس» label next to an option that needs the subscription.
struct PlusBadge: View {
    @ObservedObject var plus = Plus.shared
    var body: some View {
        if !plus.unlocked {
            Label("بلس", systemImage: "crown.fill").font(.plex(.caption2, .semibold)).foregroundStyle(Color(hex: 0x6B4600))
                .padding(.horizontal, 7).padding(.vertical, 2).background(Brand.saffron.opacity(0.25), in: Capsule())
        }
    }
}

// MARK: - Paywall

struct PaywallView: View {
    let reason: Plus.Reason
    @ObservedObject var plus = Plus.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var pick = "yearly"

    private let benefits = [("infinity", "بلا حدود يومية", "كل أدوات الملفات والصور متى شئت"),
                            ("square.stack.3d.up.fill", "دفعة واحدة حتى \(Plus.plusFiles) ملف", "وملفات حتى \(Plus.plusMB) م.ب"),
                            ("doc.richtext.fill", "قوالب احترافية", "أكثر من 20 قالبًا بشعار منشأتك"),
                            ("text.viewfinder", "OCR لملفات كاملة", "وملف PDF قابل للبحث")]
    private let extras = ["إزالة الخلفية بدقة عالية وألوان مخصصة", "كل مقاسات صور الوثائق وورقة طباعة", "توقيع محفوظ وأختام وعلامة مائية",
                          "تصدير السجلات إلى Excel وPDF", "قفل الملاحظات والوثائق ببصمة الوجه", "ألوان وأيقونات مميزة", "أولوية في الدعم"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.m) {
                    Image(systemName: "crown.fill").font(.system(size: 30)).foregroundStyle(Brand.saffron)
                        .frame(width: 64, height: 64).background(Brand.ink, in: RoundedRectangle(cornerRadius: 20))
                    Text("مُيسّر بلس").font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.accent)
                    Text(plus.active ? "أنت مشترك في بلس" : "أنجز أكثر بلا حدود").font(.plex(.title2, .bold)).foregroundStyle(Brand.text1).multilineTextAlignment(.center)
                    if reason != .menu && !plus.active {
                        VStack(spacing: 4) {
                            Text(reason.title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1)
                            Text(reason.body).font(.plex(.footnote)).foregroundStyle(Brand.text2)
                        }.multilineTextAlignment(.center).padding(Space.m).frame(maxWidth: .infinity).background(Brand.accentSoft, in: RoundedRectangle(cornerRadius: Radius.m))
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Space.s) {
                        ForEach(benefits, id: \.1) { icon, title, text in
                            VStack(spacing: 4) {
                                Image(systemName: icon).font(.title3).foregroundStyle(Brand.accent)
                                Text(title).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.text1)
                                Text(text).font(.plex(.caption)).foregroundStyle(Brand.text2)
                            }.multilineTextAlignment(.center).padding(Space.m).frame(maxWidth: .infinity, minHeight: 110).card()
                        }
                    }
                    VStack(spacing: 4) {
                        ForEach(extras, id: \.self) { e in Label(e, systemImage: "checkmark").font(.plex(.footnote)).foregroundStyle(Brand.text2) }
                    }
                    offer
                    Label("ملفاتك تبقى على جهازك. ألغِ في أي وقت من المتجر.", systemImage: "lock.fill").font(.plex(.caption)).foregroundStyle(Brand.text3)
                    HStack {
                        Button("شروط الاستخدام") { openURL(termsURL) }
                        Button("سياسة الخصوصية") { openURL(privacyURL) }
                    }.font(.plex(.footnote, .semibold))
                }
                .padding(Space.xl).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(Brand.bg)
            .accessibilityIdentifier("paywall")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("إغلاق").accessibilityIdentifier("paywallClose")
                }
                if plus.live && !plus.active {
                    ToolbarItem(placement: .primaryAction) { Button("استعادة المشتريات") { Task { await plus.restore() } }.disabled(plus.busy) }
                }
            }
            .alert(plus.message ?? "", isPresented: Binding(get: { plus.message != nil }, set: { if !$0 { plus.message = nil } })) { Button("حسنًا") {} }
        }
        .onChange(of: plus.active) { _, on in if on && reason != .menu { dismiss() } }
    }

    @ViewBuilder private var offer: some View {
        if plus.active {
            Text(plus.subscribed ? "\(plus.planName)\(plus.renews ? " • يتجدد تلقائيًا" : " • لن يتجدد")" : "مرور اليوم مفعّل حتى \(plus.dayPassUntil.formatted(date: .omitted, time: .shortened))")
                .font(.plex(.body)).foregroundStyle(Brand.text1)
            if plus.subscribed { SecondaryButton(title: "إدارة الاشتراك أو إلغاؤه", icon: "person.crop.circle") { openURL(Plus.manageURL) } }
        } else if !plus.live {
            VStack(spacing: Space.s) {
                Text("قريبًا").font(.plex(.headline, .semibold)).foregroundStyle(Brand.text1)
                Text("كل الأدوات مفتوحة لك مجانًا الآن خلال فترة الإطلاق. سيُطرح بلس قريبًا بسعر رمزي.").font(.plex(.footnote)).foregroundStyle(Brand.text2).multilineTextAlignment(.center)
                Toggle("نبّهني عند إطلاق بلس", isOn: Binding(get: { plus.notifyWhenLive }, set: { _ in plus.toggleNotify() })).font(.plex(.subheadline))
            }.padding(Space.l).card()
        } else if plus.plans.isEmpty {
            Text("تعذّر تحميل الأسعار من App Store. تأكد من الاتصال وحاول لاحقًا.").font(.plex(.footnote)).foregroundStyle(Brand.text2)
        } else {
            let monthly = plus.plans.first { $0.id == "monthly" }
            ForEach(plus.plans.filter { $0.id != "day" || pick == "day" }) { p in
                let save: Int = {
                    guard p.id == "yearly", let m = monthly, m.amount > 0 else { return 0 }
                    return 100 - Int((((p.amount * 100) / (m.amount * 12)) as NSDecimalNumber).doubleValue)
                }()
                PlanCard(plan: p, selected: pick == p.id, save: save) { pick = p.id }
            }
            let chosen = plus.plans.first { $0.id == pick } ?? plus.plans[0]
            PrimaryButton(title: chosen.trialDays > 0 ? "ابدأ تجربة مجانية \(chosen.trialDays) أيام" : chosen.id == "day" ? "افتح بلس 24 ساعة" : "اشترك الآن", icon: "crown.fill", enabled: !plus.busy) {
                Task { await plus.buy(chosen) }
            }.accessibilityIdentifier("subscribe")
            Text(chosen.id == "day" ? "دفعة واحدة \(chosen.price)، بلا اشتراك ولا تجديد."
                 : chosen.trialDays > 0 ? "مجانًا \(chosen.trialDays) أيام، ثم \(chosen.price) كل \(chosen.period) ويتجدد تلقائيًا. نذكّرك قبل نهاية التجربة بيوم، ويمكنك الإلغاء في أي وقت من إعدادات App Store."
                 : "\(chosen.price) كل \(chosen.period)، ويتجدد تلقائيًا حتى تلغيه من إعدادات App Store.")
                .font(.plex(.caption)).foregroundStyle(Brand.text3).multilineTextAlignment(.center)
            if let d = plus.plans.first(where: { $0.id == "day" }), pick != "day" {
                Button("تحتاجه مرة واحدة؟ مرور يوم بـ \(d.price)") { pick = "day" }.font(.plex(.subheadline, .semibold))
            }
        }
    }
}

private struct PlanCard: View {
    let plan: Plus.Plan; let selected: Bool; let save: Int; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.title3).foregroundStyle(selected ? Brand.accent : Brand.borderStrong)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.title).font(.plex(.headline, .semibold)).foregroundStyle(Brand.text1)
                        if save > 0 { Text("وفّر \(save)%").font(.plex(.caption2, .semibold)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 2).background(Brand.mint, in: Capsule()) }
                    }
                    Text(plan.trialDays > 0 ? "\(plan.trialDays) أيام مجانًا • \(plan.note)" : plan.note).font(.plex(.caption)).foregroundStyle(Brand.text2)
                }
                Spacer()
                VStack(alignment: .trailing) { Text(plan.price).font(.plex(.subheadline, .semibold)); Text("/ \(plan.period)").font(.plex(.caption)).foregroundStyle(Brand.text3) }.foregroundStyle(Brand.text1)
            }
            .padding(Space.l)
            .background(selected ? Brand.accentSoft : Brand.surface, in: RoundedRectangle(cornerRadius: Radius.l))
            .overlay(RoundedRectangle(cornerRadius: Radius.l).stroke(selected ? Brand.accent : Brand.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("plan-\(plan.id)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Plus status card at the top of Settings.
struct PlusCard: View {
    @ObservedObject var plus = Plus.shared
    var body: some View {
        Button { plus.paywall = .menu } label: {
            HStack(spacing: Space.m) {
                Image(systemName: "crown.fill").foregroundStyle(Brand.saffron).frame(width: 44, height: 44).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(plus.active ? "أنت مشترك في مُيسّر بلس" : "مُيسّر بلس").font(.plex(.subheadline, .semibold)).foregroundStyle(.white)
                    Text(plus.active ? "كل الميزات مفتوحة. اضغط لإدارة اشتراكك."
                         : !plus.live ? "قريبًا: بلا حدود يومية وقوالب احترافية وOCR لملفات كاملة"
                         : "استخدمت اليوم \(plus.usedToday) من \(Plus.freeOpsPerDay) عمليات مجانية. افتحها بلا حدود.")
                        .font(.plex(.caption)).foregroundStyle(.white.opacity(0.78)).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.left").foregroundStyle(.white.opacity(0.7))
            }
            .padding(Space.l).background(Brand.ink, in: RoundedRectangle(cornerRadius: Radius.l))
        }
        .buttonStyle(PressStyle()).accessibilityIdentifier("plusCard")
    }
}

// MARK: - Templates

/// Document templates: 4 layouts × 6 colours = 24. Free: the classic one with the «أُنشئ بمُيسّر» line.
enum Templates {
    static let layouts = ["كلاسيكي", "ترويسة ملوّنة", "شريط جانبي", "رسمي متوسط"]
    static let palettes: [(String, UInt32)] = [("نيلي", 0x2F4BFF), ("زمردي", 0x0B7F7A), ("عنابي", 0x8E1F3C), ("فحمي", 0x2A2F3A), ("ذهبي", 0xA86A06), ("بنفسجي", 0x6A3FC4)]
    static var count: Int { layouts.count * palettes.count }
    static var selected: Int {
        get { UserDefaults.standard.integer(forKey: "template") }
        set { UserDefaults.standard.set(newValue, forKey: "template") }
    }
    @MainActor static var current: Int { Plus.shared.unlocked ? selected : 0 }
    static func name(_ i: Int) -> String { "\(layouts[i / palettes.count]) • \(palettes[i % palettes.count].0)" }
    static var logoURL: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("data/logo.png") }
    static var logo: UIImage? { UIImage(contentsOfFile: logoURL.path) }

    /// Apply the chosen template, logo and footer to a document-tool PDF.
    @MainActor @discardableResult static func apply(_ b: DocBuilder, logo useLogo: Bool = true) -> DocBuilder {
        let i = current
        b.layoutStyle = i / palettes.count
        b.accent = UIColor(Color(hex: palettes[i % palettes.count].1))
        if Plus.shared.unlocked && useLogo { b.logo = logo }
        b.footer = Plus.shared.unlocked ? nil : Plus.footer
        return b
    }
}

struct TemplatePanel: View {
    var useLogo = true
    var styles = true
    @ObservedObject var plus = Plus.shared
    @AppStorage("template") private var selected = 0
    @State private var item: PhotosPickerItem?
    @State private var hasLogo = FileManager.default.fileExists(atPath: Templates.logoURL.path)

    private var shown: Int { plus.unlocked ? selected : 0 }

    var body: some View {
        Panel {
            HStack(spacing: 6) { Text(styles ? "القالب" : "شعار المنشأة").font(.plex(.subheadline, .semibold)); PlusBadge() }.frame(maxWidth: .infinity)
            if styles {
                HStack(spacing: Space.s) {
                    ForEach(Templates.layouts.indices, id: \.self) { li in
                        Button { choose(li, plus.unlocked ? selected % Templates.palettes.count : 0) } label: {
                            VStack(spacing: 4) {
                                MiniPage(layout: li, accent: Color(hex: Templates.palettes[shown % Templates.palettes.count].1))
                                Text(Templates.layouts[li]).font(.plex(.caption2)).foregroundStyle(Brand.text2).lineLimit(1)
                            }
                            .padding(6).frame(maxWidth: .infinity)
                            .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(shown / Templates.palettes.count == li ? Brand.accent : Brand.border, lineWidth: shown / Templates.palettes.count == li ? 2 : 1))
                        }.buttonStyle(.plain).accessibilityLabel("قالب \(Templates.layouts[li])").accessibilityIdentifier("layout-\(li)")
                    }
                }
                HStack {
                    ForEach(Templates.palettes.indices, id: \.self) { pi in
                        Button { choose(shown / Templates.palettes.count, pi) } label: {
                            Circle().fill(Color(hex: Templates.palettes[pi].1)).frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Brand.text1, lineWidth: shown % Templates.palettes.count == pi ? 3 : 0))
                        }.buttonStyle(.plain).accessibilityLabel("لون \(Templates.palettes[pi].0)")
                    }
                }.frame(maxWidth: .infinity)
            }
            Text(!styles ? (plus.unlocked ? "يظهر شعارك أعلى المستند" : "مع بلس: شعارك دون سطر «\(Plus.footer)».")
                 : plus.unlocked ? "\(Templates.count) قالبًا: \(Templates.name(shown))"
                 : "المجاني: القالب الكلاسيكي مع سطر «\(Plus.footer)». بلس: \(Templates.count) قالبًا وشعارك دون السطر.")
                .font(.plex(.caption)).foregroundStyle(Brand.text3).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            if useLogo {
                HStack {
                    if plus.unlocked {
                        PhotosPicker(selection: $item, matching: .images) {
                            Label(hasLogo ? "تغيير شعار المنشأة" : "إضافة شعار المنشأة", systemImage: "photo.badge.plus").font(.plex(.subheadline, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        }
                    } else {
                        SecondaryButton(title: "إضافة شعار المنشأة", icon: "photo.badge.plus") { plus.allow(.template) }
                    }
                    if hasLogo { Button("إزالة", role: .destructive) { try? FileManager.default.removeItem(at: Templates.logoURL); hasLogo = false } }
                }
            }
        }
        .accessibilityIdentifier("templates")
        .onChange(of: item) { _, it in
            Task {
                guard let d = try? await it?.loadTransferable(type: Data.self), let img = UIImage(data: d), let png = img.pngData() else { return }
                try? FileManager.default.createDirectory(at: Templates.logoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? png.write(to: Templates.logoURL); hasLogo = true
            }
        }
    }

    private func choose(_ layout: Int, _ palette: Int) {
        let i = layout * Templates.palettes.count + palette
        if i == 0 || plus.allow(.template) { selected = i }
    }
}

private struct MiniPage: View {
    let layout: Int; let accent: Color
    var body: some View {
        Canvas { c, s in
            let w = s.width, h = s.height
            if layout == 1 { c.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.22)), with: .color(accent)) }
            if layout == 2 { c.fill(Path(CGRect(x: w * 0.92, y: 0, width: w * 0.08, height: h)), with: .color(accent)) }
            if layout == 3 {
                c.fill(Path(CGRect(x: w * 0.25, y: h * 0.1, width: w * 0.5, height: h * 0.06)), with: .color(Color(hex: 0x141A2E)))
                c.fill(Path(CGRect(x: w * 0.2, y: h * 0.2, width: w * 0.6, height: 1.5)), with: .color(accent))
                c.fill(Path(CGRect(x: w * 0.2, y: h * 0.23, width: w * 0.6, height: 1.5)), with: .color(accent))
            } else if layout != 1 {
                c.fill(Path(CGRect(x: w * 0.4, y: h * 0.1, width: w * 0.45, height: h * 0.06)), with: .color(Color(hex: 0x141A2E)))
                c.fill(Path(CGRect(x: w * 0.7, y: h * 0.2, width: w * 0.15, height: h * 0.025)), with: .color(accent))
            }
            for k in 0..<5 { c.fill(Path(CGRect(x: w * 0.15, y: h * (0.34 + Double(k) * 0.11), width: w * 0.7, height: h * 0.025)), with: .color(Color(hex: 0xCDD2DE))) }
        }
        .frame(width: 44, height: 58).background(.white, in: RoundedRectangle(cornerRadius: 4)).overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.border))
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - App lock (Face ID / Touch ID / passcode)

@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()
    @Published var enabled = UserDefaults.standard.bool(forKey: "lock")
    @Published var open = false

    func set(_ v: Bool) { enabled = v; open = v; UserDefaults.standard.set(v, forKey: "lock") }
    var available: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    func prompt(_ reason: String) async -> Bool {
        (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Shows its content only after unlocking, when the lock is on.
struct LockGate<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @ObservedObject var lock = AppLock.shared
    var body: some View {
        if !lock.enabled || lock.open { content }
        else {
            VStack(spacing: Space.m) {
                Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(Brand.accent)
                Text("\(title) مقفلة").font(.plex(.headline, .semibold))
                Text("افتحها ببصمة الوجه أو الإصبع أو رمز الجهاز.").font(.plex(.footnote)).foregroundStyle(Brand.text2)
                PrimaryButton(title: "فتح", icon: "faceid") { Task { if await lock.prompt("فتح \(title)") { lock.open = true } } }
            }
            .padding(Space.xxl).accessibilityIdentifier("locked")
            .task { if await lock.prompt("فتح \(title)") { lock.open = true } }
        }
    }
}

// MARK: - Support

@MainActor func contactSupport(_ openURL: OpenURLAction) {
    let plus = Plus.shared.active
    let subject = (plus ? "[بلس] " : "") + "ملاحظة على تطبيق مُيسّر"
    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    let body = "\n\n—\nالإصدار \(v) • iOS \(UIDevice.current.systemVersion)\(plus ? " • مشترك بلس" : "")"
    func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "" }
    if !supportEmail.isEmpty, let u = URL(string: "mailto:\(supportEmail)?subject=\(enc(subject))&body=\(enc(body))") { openURL(u) }
    else if let u = URL(string: "https://github.com/ayattla/muyassir-ios/issues/new?title=\(enc(subject))&body=\(enc(body))\(plus ? "&labels=plus" : "")") { openURL(u) }
}

/// Accent colours for Plus (≥ 4.5:1 with white text in light mode).
let accents: [(String, UInt32, UInt32)] = [("نيلي", 0x3346D3, 0x9AA6FF), ("زمردي", 0x0B7F7A, 0x7FD1C9), ("عنابي", 0xA3264A, 0xF29CB4),
                                           ("برتقالي", 0xB0500A, 0xF4B27A), ("بنفسجي", 0x6A3FC4, 0xC3AEF5), ("فحمي", 0x2A2F3A, 0xC9CED9)]
let appIcons: [(String?, String)] = [(nil, "الأصلية"), ("AppIcon-Paper", "فاتحة"), ("AppIcon-Saffron", "زعفرانية")]
