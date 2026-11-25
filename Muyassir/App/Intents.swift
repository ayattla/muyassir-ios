import AppIntents
import SwiftUI

/// Siri and Shortcuts: open a common tool or the recipes directly ("امسح مستند في ميسر").
@MainActor
final class DeepLink: ObservableObject {
    static let shared = DeepLink()
    @Published var target: String?
}

struct ScanIntent: AppIntent {
    static let title: LocalizedStringResource = "مسح مستند"
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { DeepLink.shared.target = "tool/scan"; return .result() }
}
struct CompressPdfIntent: AppIntent {
    static let title: LocalizedStringResource = "ضغط PDF"
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { DeepLink.shared.target = "tool/pdf_compress"; return .result() }
}
struct ImagesToPdfIntent: AppIntent {
    static let title: LocalizedStringResource = "تحويل الصور إلى PDF"
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { DeepLink.shared.target = "tool/img_pdf"; return .result() }
}
struct RecipesIntent: AppIntent {
    static let title: LocalizedStringResource = "الوصفات"
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { DeepLink.shared.target = "recipes"; return .result() }
}

struct MuyassirShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ScanIntent(), phrases: ["امسح مستند في \(.applicationName)", "Scan a document with \(.applicationName)"], shortTitle: "مسح مستند", systemImageName: "doc.viewfinder")
        AppShortcut(intent: CompressPdfIntent(), phrases: ["اضغط PDF في \(.applicationName)", "Compress a PDF with \(.applicationName)"], shortTitle: "ضغط PDF", systemImageName: "arrow.down.right.and.arrow.up.left")
        AppShortcut(intent: ImagesToPdfIntent(), phrases: ["حول الصور إلى PDF في \(.applicationName)", "Images to PDF with \(.applicationName)"], shortTitle: "صور إلى PDF", systemImageName: "photo.on.rectangle")
        AppShortcut(intent: RecipesIntent(), phrases: ["افتح الوصفات في \(.applicationName)", "Open recipes in \(.applicationName)"], shortTitle: "الوصفات", systemImageName: "wand.and.stars")
    }
}
