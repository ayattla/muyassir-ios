import SwiftUI
import PDFKit
import AVFoundation
import UniformTypeIdentifiers
#if canImport(Translation)
import Translation
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Text from a picked file: PDF text layer (OCR when empty), Word, PowerPoint, plain text, or a photo (OCR).
func readText(_ url: URL, ocrPages: Int = 30) throws -> String {
    let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
    switch url.pathExtension.lowercased() {
    case "pdf":
        let d = try PdfEngine.open(url), budget = min(ocrPages, 30)
        let t = (0..<d.pageCount).compactMap { d.page(at: $0).map(PdfEngine.text) }.joined(separator: "\n")
        if t.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 { return t }
        return try (0..<min(d.pageCount, budget)).compactMap { d.page(at: $0) }.map { try Ocr.recognize(PdfEngine.render($0, dpi: 200), .ar) }.joined(separator: "\n")
    case "docx": return try Office.readDocx(url).joined(separator: "\n")
    case "pptx": return try Office.readPptx(url).joined(separator: "\n")
    case "txt", "md", "csv": return try String(contentsOf: url, encoding: .utf8)
    default:
        guard let img = ImageEngine.load(url, maxSide: 3000) else { return "" }
        return try Ocr.recognize(img, .ar)
    }
}


/// Typed text plus a button to bring text from a file or photo.
struct TextSource: View {
    let label: String
    @Binding var text: String
    @State private var picking = false
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        Panel {
            Field(label: label, text: $text, lines: 8)
            HStack {
                SecondaryButton(title: loading ? "جار القراءة…" : "من ملف أو صورة", icon: "doc.text.viewfinder") { picking = true }
                if !text.isEmpty { SecondaryButton(title: "مسح", icon: "xmark") { text = "" } }
            }
            if let error { Text(error).font(.plex(.caption)).foregroundStyle(.red) }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.pdf, .image, .plainText, UTType(filenameExtension: "docx") ?? .data, UTType(filenameExtension: "pptx") ?? .data]) { r in
            guard case .success(let u) = r else { return }
            loading = true; error = nil
            let budget = Plus.shared.ocrPages
            Task.detached {
                let res = Result { try readText(u, ocrPages: budget) }
                await MainActor.run {
                    loading = false
                    switch res { case .success(let t): if t.isEmpty { error = "لم يعثر على نص في الملف" } else { text = t }
                    case .failure(let e): error = e.localizedDescription }
                }
            }
        }
    }
}

// MARK: Translation (Apple's on-device Translation framework, iOS 18+)

struct TranslateTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var text = ""; @State var dir = 0; @State var out = ""; @State var error: String?; @State var busy = false; @State var run = 0; @State var files: [URL] = []
    var body: some View {
        ToolScreen(tool: tool) {
            Seg(options: ["عربي ← إنجليزي", "إنجليزي ← عربي"], selection: $dir)
            TextSource(label: "النص", text: $text)
            if #available(iOS 18.0, *) {
                TranslateRunner(text: text, toEnglish: dir == 0, trigger: run) { r in
                    busy = false
                    switch r {
                    case .success(let t): out = t; error = nil; save(t); store.used(tool.id); ReviewAsk.success()
                    case .failure(let e): error = "تعذرت الترجمة: \(e.localizedDescription)"
                    }
                }
                PrimaryButton(title: busy ? "يترجم…" : "ترجمة", icon: "translate", enabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy) { busy = true; run += 1 }
                    .accessibilityIdentifier("action")
                Hint(text: "تعمل الترجمة على جهازك. في أول مرة قد يطلب iOS تنزيل لغة الترجمة، وبعدها تعمل دون إنترنت.")
            } else {
                Hint(text: "الترجمة على الجهاز تتطلب iOS 18 أو أحدث. حدث نظام جهازك لاستخدامها.")
            }
            if let error { Text(error).font(.plex(.caption)).foregroundStyle(.red).accessibilityIdentifier("error") }
            if !out.isEmpty { TextResult(text: out, label: "الترجمة").accessibilityIdentifier("results"); ResultFiles(files: files) }
        }
    }
    private func save(_ t: String) {
        let u = FilesX.outDir().appendingPathComponent("ترجمة.docx")
        if (try? Office.writeDocx(u, t.components(separatedBy: "\n").map { .text($0) })) != nil { files = [u] }
    }
}

@available(iOS 18.0, *)
private struct TranslateRunner: View {
    let text: String; let toEnglish: Bool; let trigger: Int; let done: (Result<String, Error>) -> Void
    @State private var config: TranslationSession.Configuration?
    var body: some View {
        Color.clear.frame(height: 0)
            .onChange(of: trigger) {
                let src = Locale.Language(identifier: toEnglish ? "ar" : "en"), dst = Locale.Language(identifier: toEnglish ? "en" : "ar")
                if config?.source == src && config?.target == dst { config?.invalidate() } else { config = .init(source: src, target: dst) }
            }
            .translationTask(config) { session in
                do {
                    let parts = text.components(separatedBy: "\n")
                    let reqs = parts.enumerated().map { TranslationSession.Request(sourceText: $0.element.isEmpty ? " " : $0.element, clientIdentifier: "\($0.offset)") }
                    let res = try await session.translations(from: reqs)
                    let map = Dictionary(uniqueKeysWithValues: res.compactMap { r in r.clientIdentifier.flatMap(Int.init).map { ($0, r.targetText) } })
                    let joined = parts.indices.map { parts[$0].isEmpty ? "" : (map[$0] ?? "") }.joined(separator: "\n")
                    await MainActor.run { done(.success(joined)) }
                } catch { await MainActor.run { done(.failure(error)) } }
            }
    }
}

// MARK: Summary

enum DeviceModel {
    /// Apple's on-device model, only when the device supports it and it speaks Arabic.
    static var arabicReady: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let m = SystemLanguageModel.default
            return m.isAvailable && m.supportsLocale(Locale(identifier: "ar"))
        }
        #endif
        return false
    }
    static func ask(_ instructions: String, _ prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return try await LanguageModelSession(instructions: instructions).respond(to: prompt).content }
        #endif
        return ""
    }
}

struct SummarizeTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @ObservedObject private var plus = Plus.shared
    @State var text = ""; @State var points: [String] = []; @State var keys: [String] = []; @State var smart = false; @State var smartText = ""; @State var busy = false; @State var error: String?
    var words: Int { TextAi.tokens(text).count }
    var body: some View {
        ToolScreen(tool: tool) {
            TextSource(label: "النص المراد تلخيصه", text: $text)
            if DeviceModel.arabicReady { Toggle("صياغة الملخص بنموذج Apple على الجهاز", isOn: $smart).font(.plex(.subheadline)) }
            PrimaryButton(title: busy ? "يلخص…" : "لخص", icon: "text.badge.star", enabled: words >= 30 && !busy) { run() }.accessibilityIdentifier("action")
            if words > 0 && words < 30 { Text("أضف نصا أطول (30 كلمة على الأقل).").font(.plex(.caption)).foregroundStyle(Brand.text2) }
            if let error { Text(error).font(.plex(.caption)).foregroundStyle(.red) }
            if !smartText.isEmpty { TextResult(text: smartText, label: "الملخص المصاغ") }
            if !points.isEmpty {
                TextResult(text: points.map { "• \($0)" }.joined(separator: "\n"), label: "الملخص (\(points.count) نقاط)").accessibilityIdentifier("results")
                if !keys.isEmpty { Panel(title: "كلمات مفتاحية") { Text(keys.joined(separator: " • ")).font(.plex(.subheadline)) } }
            }
            Hint(text: "يختار أهم الجمل من نصك على جهازك ويعرضها بترتيبها، فلا يضيف معلومة ليست في النص.\(plus.unlocked ? "" : " المجاني: تلخيص واحد يوميا.")")
        }
    }
    private func run() {
        guard plus.useAi() else { return }
        points = TextAi.summarize(text); keys = TextAi.keywords(text, n: 8); smartText = ""; error = nil
        store.used(tool.id); ReviewAsk.success()
        guard smart else { return }
        busy = true; let src = text
        Task {
            do { let r = try await DeviceModel.ask("لخص النص التالي بالعربية في نقاط قصيرة دون إضافة أي معلومة غير موجودة فيه.", src); await MainActor.run { smartText = r; busy = false } }
            catch { await MainActor.run { self.error = "تعذرت الصياغة بالنموذج، والملخص أدناه من جملك."; busy = false } }
        }
    }
}

// MARK: Review questions

struct QuizGenTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @ObservedObject private var plus = Plus.shared
    @State var text = ""; @State var count = "10"; @State var qs: [TextAi.Question] = []; @State var files: [URL] = []; @State var msg: String?
    var body: some View {
        ToolScreen(tool: tool) {
            TextSource(label: "ملاحظاتك أو درسك", text: $text)
            NumField(label: "عدد الأسئلة", text: $count)
            PrimaryButton(title: "أنشئ أسئلة المراجعة", icon: "questionmark.bubble", enabled: TextAi.sentences(text).count >= 3) { run() }.accessibilityIdentifier("action")
            if !qs.isEmpty {
                Panel(title: "\(qs.count) سؤالا") {
                    ForEach(Array(qs.enumerated()), id: \.element.id) { i, q in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(i + 1)) \(q.text)").font(.plex(.subheadline, .semibold))
                            ForEach(q.options, id: \.self) { o in Text("   \(o == q.answer ? "✔" : "○") \(o)").font(.plex(.footnote)).foregroundStyle(o == q.answer ? Brand.mint : Brand.text2) }
                        }
                    }
                    SecondaryButton(title: "أضفها إلى بطاقات المراجعة", icon: "rectangle.on.rectangle.angled") {
                        let now = Date().timeIntervalSince1970 * 1000
                        store.saveList("flashcards", store.list("flashcards") + qs.enumerated().map { ["id": now + Double($0.offset), "f": $0.element.text, "b": $0.element.answer, "box": 1.0] as Rec })
                        msg = "أضيفت \(qs.count) بطاقة إلى بطاقات المراجعة"
                    }
                    if let msg { Text(msg).font(.plex(.caption)).foregroundStyle(Brand.mint) }
                }.accessibilityIdentifier("results")
                ResultFiles(files: files)
            } else if !text.isEmpty && TextAi.sentences(text).count < 3 {
                Text("أضف ثلاث جمل كاملة على الأقل.").font(.plex(.caption)).foregroundStyle(Brand.text2)
            }
            Hint(text: "تبنى الأسئلة من جملك نفسها على جهازك (أكمل الفراغ بأربعة اختيارات). راجعها قبل توزيعها.\(plus.unlocked ? "" : " المجاني: مرة واحدة يوميا.")")
        }
    }
    private func run() {
        guard plus.useAi() else { return }
        qs = TextAi.quiz(text, count: min(max(Int(count.num), 1), 30)); msg = nil
        guard !qs.isEmpty else { msg = "لم أجد مصطلحات كافية لبناء أسئلة. جرب نصا أطول."; return }
        let out = FilesX.outDir()
        func doc(_ key: Bool) -> URL? {
            let b = Templates.apply(DocBuilder()); b.add(.title(key ? "أسئلة المراجعة — الإجابات" : "أسئلة المراجعة"))
            for (i, q) in qs.enumerated() {
                b.add(.para("\(i + 1)) \(q.text)", size: 12, bold: true))
                for (k, o) in q.options.enumerated() { b.add(.para("   \(key && o == q.answer ? "✔" : "○") \(Array("أبجد")[min(k, 3)])) \(o)")) }
                b.add(.space(6))
            }
            return try? b.save(to: out.appendingPathComponent(key ? "أسئلة-المراجعة-الإجابات.pdf" : "أسئلة-المراجعة.pdf"))
        }
        files = [doc(false), doc(true)].compactMap { $0 }; store.used(tool.id); ReviewAsk.success()
    }
}

// MARK: Read aloud

@MainActor final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var speaking = false
    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }
    func speak(_ text: String, rate: Float, arabic: Bool) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        let u = AVSpeechUtterance(string: text); u.rate = rate
        u.voice = AVSpeechSynthesisVoice(language: arabic ? "ar-SA" : "en-US")
        synth.speak(u); speaking = true
    }
    func stop() { synth.stopSpeaking(at: .immediate); speaking = false }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { Task { @MainActor in self.speaking = false } }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { Task { @MainActor in self.speaking = false } }
}

struct ReadAloudTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @StateObject private var speaker = Speaker()
    @State var text = ""; @State var speed = 1; @State var scanning = false
    var arabic: Bool { text.unicodeScalars.filter { (0x0600...0x06FF).contains($0.value) }.count * 3 >= text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count }
    var body: some View {
        ToolScreen(tool: tool) {
            TextSource(label: "النص المراد قراءته", text: $text)
            SecondaryButton(title: "صور ورقة", icon: "camera.viewfinder") { scanning = true }
            Seg(options: ["بطيء", "عادي", "سريع"], selection: $speed)
            HStack {
                PrimaryButton(title: speaker.speaking ? "يقرأ الآن…" : "اقرأ لي", icon: "speaker.wave.2", enabled: !text.isEmpty && !speaker.speaking) {
                    speaker.speak(text, rate: [0.38, 0.5, 0.58][speed], arabic: arabic); store.used(tool.id)
                }.accessibilityIdentifier("action")
                if speaker.speaking { SecondaryButton(title: "إيقاف", icon: "stop.fill") { speaker.stop() } }
            }
            Hint(text: "يستخدم صوت iOS المدمج. لصوت أوضح نزل صوتا عربيا محسنا من الإعدادات ← تسهيلات الاستخدام ← المحتوى المنطوق ← الأصوات.")
        }
        .onDisappear { speaker.stop() }
        .fullScreenCover(isPresented: $scanning) {
            DocScanner { imgs in
                Task.detached { let t = imgs.compactMap { try? Ocr.recognize($0, .ar) }.joined(separator: "\n"); await MainActor.run { if !t.isEmpty { text = t } } }
            }.ignoresSafeArea()
        }
    }
}
