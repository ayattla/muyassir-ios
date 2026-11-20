import SwiftUI
import UserNotifications

@main
struct MuyassirApp: App {
    @StateObject private var store = Store.shared
    init() { FilesX.cleanOld() }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .tint(Brand.lapis)
        }
    }
}

enum Brand {
    static let lapis = Color(hex: 0x2F4BFF)
    static let ink = Color(hex: 0x101935)
    static let mint = Color(hex: 0x12C29A)
    static let saffron = Color(hex: 0xFFC23D)
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
    @State private var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Tool.self) { ToolHost(tool: $0) }
                .navigationDestination(for: Category.self) { CategoryView(cat: $0) }
        }
        .onAppear {
            // The UI test and screenshots pass `-tool <id>` to open one tool directly.
            if let i = CommandLine.arguments.firstIndex(of: "-tool"), i + 1 < CommandLine.arguments.count, let t = Tools.byId[CommandLine.arguments[i + 1]] { path.append(t) }
        }
    }
}
