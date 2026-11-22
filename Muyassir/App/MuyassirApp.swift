import SwiftUI
import UserNotifications

@main
struct MuyassirApp: App {
    @StateObject private var store = Store.shared
    @StateObject private var plus = Plus.shared
    @AppStorage("theme") private var theme = "light"
    @AppStorage("accentActive") private var accentActive = 0
    init() {
        FilesX.cleanOld()
        #if DEBUG
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "-plus"), i + 1 < a.count { Plus.shared.testState(a[i + 1]) }
        if let i = a.firstIndex(of: "-paywall"), i + 1 < a.count { Plus.shared.paywall = Plus.Reason(rawValue: a[i + 1]) }
        #endif
        Plus.shared.start()
        if let i = CommandLine.arguments.firstIndex(of: "-theme"), i + 1 < CommandLine.arguments.count { UserDefaults.standard.set(CommandLine.arguments[i + 1], forKey: "theme") }
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .id(accentActive) // rebuild with the new accent colour
                .environmentObject(store)
                .environmentObject(plus)
                .fullScreenCover(item: $plus.paywall) { PaywallView(reason: $0) }
                .task { await plus.refresh(); await Cloud.refreshLicence() }
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .tint(Brand.accent)
                // Light is the default; dark only when chosen, or "follow the device".
                .preferredColorScheme(theme == "dark" ? .dark : theme == "system" ? nil : .light)
        }
    }
}

/// Muyassir design system ("Paper & Ink"). Every colour adapts to light/dark; all text pairs meet WCAG AA.
enum Brand {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
    /// Default indigo; Plus users can pick another accent (applied through `accentActive`).
    static var accent: Color { let a = accents[min(max(UserDefaults.standard.integer(forKey: "accentActive"), 0), accents.count - 1)]; return dyn(a.1, a.2) }
    static let onAccent = dyn(0xFFFFFF, 0x0E1220)
    static var accentSoft: Color { UserDefaults.standard.integer(forKey: "accentActive") == 0 ? dyn(0xECEEFD, 0x242B4A) : accent.opacity(0.12) }
    static let bg = dyn(0xF6F7FA, 0x0F1320)
    static let surface = dyn(0xFFFFFF, 0x181D2B)
    static let sunken = dyn(0xF0F2F6, 0x121623)
    static let border = dyn(0xE3E6EE, 0x2B3245)
    static let borderStrong = dyn(0xCDD2DE, 0x3A4258)
    static let text1 = dyn(0x141A2E, 0xF2F4FA)
    static let text2 = dyn(0x4F586E, 0xB7BDCE)
    static let text3 = dyn(0x6A7389, 0x959DB3)
    static let ink = Color(hex: 0x1C2453)
    static let mint = dyn(0x14936B, 0x5FD3AE)
    static let saffron = Color(hex: 0xF2B01E)
    static var lapis: Color { accent } // older call sites
    /// Icon colour on a solid category tile.
    static let onAccentFor = dyn(0xFFFFFF, 0x10131D)
    /// Category colours share one lightness; lifted in dark mode for contrast.
    static func tone(_ hex: UInt32) -> Color {
        Color(UIColor { t in
            let c = UIColor(Color(hex: hex)); guard t.userInterfaceStyle == .dark else { return c }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0; c.getRed(&r, green: &g, blue: &b, alpha: &a)
            return UIColor(red: r + (1 - r) * 0.38, green: g + (1 - g) * 0.38, blue: b + (1 - b) * 0.38, alpha: 1)
        })
    }
    static func toneSoft(_ hex: UInt32) -> Color {
        Color(UIColor { t in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0; UIColor(Color(hex: hex)).getRed(&r, green: &g, blue: &b, alpha: &a)
            if t.userInterfaceStyle == .dark { let k: CGFloat = 0.28; return UIColor(red: 0.094 + (r - 0.094) * k, green: 0.114 + (g - 0.114) * k, blue: 0.169 + (b - 0.169) * k, alpha: 1) }
            let k: CGFloat = 0.10; return UIColor(red: 1 + (r - 1) * k, green: 1 + (g - 1) * k, blue: 1 + (b - 1) * k, alpha: 1)
        })
    }
}

enum Space { static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 20, xxl: CGFloat = 24 }
enum Radius { static let s: CGFloat = 10, m: CGFloat = 14, l: CGFloat = 18, xl: CGFloat = 24 }

/// Card surface: white with hairline border and a soft shadow in light mode; lifted surface in dark mode.
struct CardSurface: ViewModifier {
    var radius: CGFloat = Radius.l
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Brand.border, lineWidth: 1))
            .shadow(color: scheme == .dark ? .clear : Color(hex: 0x141A2E).opacity(0.06), radius: 6, y: 2)
    }
}
extension View { func card(_ radius: CGFloat = Radius.l) -> some View { modifier(CardSurface(radius: radius)) } }

/// Quick scale on press for cards (skipped when Reduce Motion is on).
struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduce
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduce ? 0.97 : 1).animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Arabic UI font that follows Dynamic Type.
extension Font {
    static func plex(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight { case .bold, .heavy, .black: name = "IBMPlexSansArabic-Bold"; case .semibold: name = "IBMPlexSansArabic-SemiBold"; case .medium: name = "IBMPlexSansArabic-Medium"; default: name = "IBMPlexSansArabic-Regular" }
        let size: CGFloat
        switch style { case .largeTitle: size = 32; case .title: size = 26; case .title2: size = 22; case .title3: size = 20; case .headline: size = 16; case .subheadline: size = 14; case .footnote: size = 13; case .caption: size = 12; case .caption2: size = 11; default: size = 16 }
        return .custom(name, size: size, relativeTo: style)
    }
}

struct RootView: View {
    @ObservedObject private var incoming = Incoming.shared
    @ObservedObject private var deepLink = DeepLink.shared
    @State private var tab = "home"
    @State private var homePath = NavigationPath()
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) {
                HomeView(go: { tab = $0 }, path: $homePath)
                    .navigationDestination(for: Tool.self) { ToolHost(tool: $0) }
                    .navigationDestination(for: Category.self) { CategoryView(cat: $0) }
                    .navigationDestination(for: RecipeRoute.self) { RecipeRunView(id: $0.id) }
                    .navigationDestination(for: RecipesRoute.self) { _ in RecipesView() }
                    .navigationDestination(for: IncomingRoute.self) { _ in IncomingView() }
            }
            .tabItem { Label("الرئيسية", systemImage: "house") }.tag("home")
            NavigationStack { SearchView().navigationDestination(for: Tool.self) { ToolHost(tool: $0) } }
                .tabItem { Label("البحث", systemImage: "magnifyingglass") }.tag("search")
            NavigationStack { AssistantView().navigationDestination(for: Tool.self) { ToolHost(tool: $0) }.navigationDestination(for: RecipeRoute.self) { RecipeRunView(id: $0.id) } }
                .tabItem { Label("المساعد", systemImage: "sparkles") }.tag("assistant")
            NavigationStack { ActivityView().navigationDestination(for: Tool.self) { ToolHost(tool: $0) } }
                .tabItem { Label("نشاطي", systemImage: "clock.arrow.circlepath") }.tag("activity")
            NavigationStack { SettingsView() }
                .tabItem { Label("الإعدادات", systemImage: "gearshape") }.tag("settings")
        }
        .onAppear {
            // UI tests and screenshots: `-tool <id>`, `-cat <id>` or `-tab <name>` open a screen directly.
            let a = CommandLine.arguments
            func arg(_ k: String) -> String? { a.firstIndex(of: k).flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil } }
            if let t = arg("-tool").flatMap({ Tools.byId[$0] }) { homePath.append(t) }
            if let c = arg("-cat").flatMap({ id in Tools.categories.first { $0.id == id } }) { homePath.append(c) }
            if let t = arg("-tab") { tab = t }
            if arg("-screen") == "recipes" { homePath.append(RecipesRoute()) }
        }
        // «فتح في مُيسّر» from Files/Mail/WhatsApp, and muyassir://tool/<id> links from the widget and shortcuts.
        .onOpenURL { open($0) }
        .onChange(of: incoming.version) { _, _ in tab = "home"; homePath.append(IncomingRoute()) }
        .onChange(of: deepLink.target) { _, t in
            guard let t, let u = URL(string: "muyassir://\(t)") else { return }
            deepLink.target = nil; open(u)
        }
    }

    private func open(_ url: URL) {
        if url.isFileURL { Incoming.shared.receive(url); return }
        guard url.scheme == "muyassir" else { return }
        tab = "home"; homePath = NavigationPath()
        switch url.host() {
        case "tool": if let t = Tools.byId[url.lastPathComponent] { homePath.append(t) }
        case "recipes": homePath.append(RecipesRoute())
        case "recipe": homePath.append(RecipeRoute(id: url.lastPathComponent))
        default: break
        }
    }
}
