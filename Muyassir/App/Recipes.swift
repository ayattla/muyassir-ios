import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers

/// «الوصفات»: several tools chained into one tap. Built-in recipes are free; your own are a Plus feature.
final class Recipes: ObservableObject {
    static let shared = Recipes()

    struct Step: Codable, Hashable { let op: String; var arg: Int = 0 }
    struct Recipe: Codable, Identifiable, Hashable { let id: String; let title: String; var sub: String; let input: String; let steps: [Step]; var custom = false }

    static let ops: [(String, String)] = [("enhance", "تحسين الصور"), ("gray", "أبيض وأسود"), ("resize", "تصغير الأبعاد"), ("compress_img", "ضغط الصور"),
        ("to_pdf", "الصور إلى PDF"), ("merge", "دمج ملفات PDF"), ("compress_pdf", "ضغط PDF"), ("to_images", "PDF إلى صور"), ("ocr", "استخراج النص"), ("zip", "ضغط ZIP")]
    static let defaultArg = ["resize": 1600, "compress_img": 75, "compress_pdf": 1]
    static let inputs: [(String, String)] = [("image", "صور"), ("pdf", "ملفات PDF"), ("both", "صور أو PDF")]
    static func opName(_ op: String) -> String { ops.first { $0.0 == op }?.1 ?? op }
    static func inputName(_ i: String) -> String { inputs.first { $0.0 == i }?.1 ?? i }

    static let builtIn: [Recipe] = [
        Recipe(id: "doc", title: "مستند من صور", sub: "تحسين ← PDF واحد ← ضغط", input: "image", steps: [Step(op: "enhance"), Step(op: "to_pdf"), Step(op: "compress_pdf", arg: 1)]),
        Recipe(id: "light", title: "صور خفيفة للإرسال", sub: "تصغير إلى 1600 بكسل ← ضغط 75%", input: "image", steps: [Step(op: "resize", arg: 1600), Step(op: "compress_img", arg: 75)]),
        Recipe(id: "text", title: "استخراج النص", sub: "من صور أو PDF إلى نص وWord", input: "both", steps: [Step(op: "ocr")]),
        Recipe(id: "email", title: "PDF للبريد", sub: "ضغط متوسط يناسب المرفقات", input: "pdf", steps: [Step(op: "compress_pdf", arg: 1)]),
        Recipe(id: "merge", title: "دمج وضغط", sub: "عدة ملفات PDF ← ملف واحد مضغوط", input: "pdf", steps: [Step(op: "merge"), Step(op: "compress_pdf", arg: 1)]),
        Recipe(id: "archive", title: "أرشفة المستندات", sub: "تحسين ← أبيض وأسود ← PDF ← ZIP", input: "image", steps: [Step(op: "enhance"), Step(op: "gray"), Step(op: "to_pdf"), Step(op: "zip")]),
    ]
    @Published var custom: [Recipe] = []
    var all: [Recipe] { Self.builtIn + custom }

    private init() {
        if let d = UserDefaults.standard.data(forKey: "recipes"), let l = try? JSONDecoder().decode([Recipe].self, from: d) { custom = l }
    }
    private func persist() { UserDefaults.standard.set(try? JSONEncoder().encode(custom), forKey: "recipes") }
    func byId(_ id: String) -> Recipe? { all.first { $0.id == id } }
    func save(_ r: Recipe) { var r = r; r.sub = Self.describe(r.steps); r.custom = true; custom.removeAll { $0.id == r.id }; custom.append(r); persist() }
    func delete(_ id: String) { custom.removeAll { $0.id == id }; persist() }

    static func describe(_ steps: [Step]) -> String {
        steps.map { s in opName(s.op) + (s.op == "resize" ? " \(s.arg)" : s.op == "compress_img" ? " \(s.arg)%" : s.op == "compress_pdf" ? [" قوي", " متوسط", " خفيف"][min(max(s.arg, 0), 2)] : "") }.joined(separator: " ← ")
    }
    static func types(_ r: Recipe) -> [UTType] { r.input == "image" ? [.image] : r.input == "pdf" ? [.pdf] : [.image, .pdf] }
    func forKinds(_ kinds: Set<String>) -> [Recipe] {
        all.filter { r in !kinds.isEmpty && kinds.allSatisfy { k in r.input == "image" ? k == "image" : r.input == "pdf" ? k == "pdf" : (k == "image" || k == "pdf") } }
    }
    static func asTool(_ r: Recipe) -> Tool { Tool(id: "recipe:\(r.id)", cats: ["files"], title: r.title, sub: r.sub, icon: "wand.and.stars", keys: "") }

    // MARK: running (off the main thread)

    static func run(_ r: Recipe, _ inputs: [URL], out: URL, p: Progress) throws -> [URL] {
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("in/recipe-\(UUID().uuidString)", isDirectory: true)
        var files = inputs
        for (i, s) in r.steps.enumerated() {
            p.update(i, r.steps.count, "الخطوة \(i + 1) من \(r.steps.count): \(opName(s.op))")
            let dir = work.appendingPathComponent("s\(i)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            files = try step(s, files, dir)
            if files.isEmpty { throw UserError("لم تُنتج الخطوة «\(opName(s.op))» أي ملف. تأكد من نوع الملفات المختارة.") }
        }
        return try files.map { f in
            let t = out.appendingPathComponent(f.lastPathComponent)
            try? FileManager.default.removeItem(at: t); try FileManager.default.copyItem(at: f, to: t); return t
        }
    }

    private static func isImage(_ u: URL) -> Bool { ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "bmp"].contains(u.pathExtension.lowercased()) }
    private static func isPdf(_ u: URL) -> Bool { u.pathExtension.lowercased() == "pdf" }
    private static func base(_ u: URL) -> String { u.deletingPathExtension().lastPathComponent }

    private static func step(_ s: Step, _ files: [URL], _ dir: URL) throws -> [URL] {
        switch s.op {
        case "enhance", "gray", "resize", "compress_img":
            return try files.map { f in
                guard isImage(f), var img = ImageEngine.load(f, maxSide: 4096) else { return f }
                switch s.op {
                case "enhance": img = ImageEngine.autoEnhance(img)
                case "gray": img = ImageEngine.adjust(img, brightness: 0, contrast: 1, saturation: 0, sharpen: false, gray: true)
                case "resize": let m = CGFloat(s.arg > 0 ? s.arg : 1600); if max(img.size.width, img.size.height) * img.scale > m { img = ImageEngine.resize(img, w: m, h: m, keep: true) }
                default: break
                }
                let q = s.op == "compress_img" ? CGFloat((10...100).contains(s.arg) ? s.arg : 75) / 100 : 0.92
                return try ImageEngine.save(img, .jpg, quality: q, to: dir.appendingPathComponent(base(f) + ".jpg"))
            }
        case "to_pdf":
            let imgs = files.filter(isImage), rest = files.filter { !isImage($0) }
            if imgs.isEmpty { return rest }
            return rest + [try PdfEngine.fromImages(imgs.compactMap { ImageEngine.load($0, maxSide: 3000) }, a4: true, to: dir.appendingPathComponent("مستند.pdf"))]
        case "merge":
            let pdfs = files.filter(isPdf)
            if pdfs.count < 2 { return files }
            return files.filter { !isPdf($0) } + [try PdfEngine.write(try PdfEngine.merge(pdfs), dir.appendingPathComponent("ملف-مدمج.pdf"))]
        case "compress_pdf":
            return try files.map { f in
                guard isPdf(f) else { return f }
                let (dpi, q): (CGFloat, CGFloat) = s.arg == 0 ? (72, 0.45) : s.arg == 2 ? (150, 0.75) : (110, 0.6)
                return try PdfEngine.compress(f, dpi: dpi, quality: q, to: dir.appendingPathComponent(base(f) + "-مضغوط.pdf")) { _, _ in }
            }
        case "to_images":
            return try files.flatMap { f -> [URL] in
                guard isPdf(f), let d = PDFDocument(url: f) else { return [f] }
                return try (0..<d.pageCount).compactMap { i in d.page(at: i).map { PdfEngine.render($0, dpi: 150) } }.enumerated()
                    .map { i, img in try ImageEngine.save(img, .jpg, quality: 0.9, to: dir.appendingPathComponent("\(base(f))-\(i + 1).jpg")) }
            }
        case "ocr":
            var parts: [String] = []
            for f in files {
                if isPdf(f), let d = PDFDocument(url: f) {
                    for i in 0..<d.pageCount { if let pg = d.page(at: i) { parts.append(try Ocr.recognize(PdfEngine.render(pg, dpi: 220), .ar)) } }
                } else if isImage(f), let img = ImageEngine.load(f, maxSide: 3000) { parts.append(try Ocr.recognize(img, .ar)) }
            }
            let t = parts.joined(separator: "\n\n")
            let txt = dir.appendingPathComponent("نص-مستخرج.txt"); try t.write(to: txt, atomically: true, encoding: .utf8)
            let docx = dir.appendingPathComponent("نص-مستخرج.docx"); try Office.writeDocx(docx, t.components(separatedBy: "\n\n").map { .text($0) })
            return [txt, docx]
        case "zip":
            let z = dir.appendingPathComponent("أرشيف.zip")
            try Zip.write(try files.map { ($0.lastPathComponent, try Data(contentsOf: $0)) }, to: z)
            return [z]
        default: return files
        }
    }
}

/// «فتح في مُيسّر»: files opened in the app from Files, Mail, WhatsApp… are copied privately, then the user chooses what to do.
@MainActor
final class Incoming: ObservableObject {
    static let shared = Incoming()
    @Published var files: [URL] = []
    @Published var version = 0
    private var handoff: [URL]?

    func receive(_ url: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("shared/\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let t = root.appendingPathComponent(url.lastPathComponent)
        guard (try? FileManager.default.copyItem(at: url, to: t)) != nil else { return }
        files = [t]; version += 1
    }
    func handTo(_ l: [URL]) { handoff = l }
    func take() -> [URL]? { defer { handoff = nil }; return handoff }

    static func kind(_ u: URL) -> String {
        switch u.pathExtension.lowercased() {
        case "pdf": "pdf"
        case "jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "bmp": "image"
        case "docx", "doc": "word"
        case "xlsx", "xls": "excel"
        case "pptx", "ppt": "ppt"
        case "zip": "zip"
        default: "other"
        }
    }
    static let kindLabel = ["pdf": "PDF", "image": "صورة", "word": "Word", "excel": "Excel", "ppt": "PowerPoint", "zip": "ZIP", "other": "ملف"]
    static func toolsFor(_ kinds: Set<String>) -> [String] {
        let by: [String: [String]] = ["pdf": ["pdf_compress", "pdf_merge", "pdf_word", "ocr", "pdf_img", "pdf_split", "pdf_protect", "pdf_excel", "pdf_rotate", "pdf_extract"],
            "image": ["img_pdf", "img_compress", "ocr", "img_bg", "img_resize", "img_convert", "img_enhance", "id_photo", "img_crop"],
            "word": ["word_pdf"], "excel": ["excel_pdf"], "ppt": ["ppt_pdf"], "zip": ["unzip"]]
        var seen = Set<String>()
        return (kinds.flatMap { by[$0] ?? [] } + ["zip"]).filter { seen.insert($0).inserted }
    }
}
