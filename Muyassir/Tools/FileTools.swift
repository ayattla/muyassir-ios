import SwiftUI
import PDFKit
import UniformTypeIdentifiers

let docxType = UTType(filenameExtension: "docx") ?? .data
let xlsxType = UTType(filenameExtension: "xlsx") ?? .data
let pptxType = UTType(filenameExtension: "pptx") ?? .data

/// Lines of each PDF page — from the text layer or through Vision OCR (scans, and better Arabic reading order).
func pdfLines(_ url: URL, ocr: Bool, _ p: Progress) throws -> [[String]] {
    let d = try PdfEngine.open(url)
    return try (0..<d.pageCount).map { i in
        guard let page = d.page(at: i) else { return [] }
        if !ocr { return PdfEngine.text(page).components(separatedBy: "\n") }
        p.update(i, d.pageCount, "التعرف على الصفحة \(i + 1) من \(d.pageCount)")
        return try Ocr.recognize(PdfEngine.render(page, dpi: 200), .ar).components(separatedBy: "\n")
    }
}

struct PageCountLabel: View {
    let url: URL
    var body: some View { Text("عدد الصفحات: \(PDFDocument(url: url)?.pageCount ?? 0)").font(.plex(.subheadline)) }
}

struct PdfToWord: View {
    let tool: Tool; @State var ocr = false
    @StateObject private var review = ReviewState()
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF", actionLabel: "تحويل إلى Word", options: { _ in
            Panel { Toggle("إعادة بناء العناوين والجداول بالتعرف الضوئي (للمسح الضوئي والجداول، أبطأ)", isOn: $ocr).font(.plex(.subheadline))
                Hint(text: "بدونه يُستخرج النص والفقرات من طبقة النص مع اتجاه عربي صحيح. معه تُقرأ كل صفحة كصورة ويُعاد بناء الجداول والعناوين، وتظهر الكلمات غير المؤكدة لمراجعتها قبل الحفظ.") }
        }, after: { ReviewPanel(state: review) }) { ins, out, p in
            if await MainActor.run(body: { ocr }) {
                let budget = await MainActor.run { min(Plus.shared.ocrPages, 80) }
                let pages = try ocrPages(ins, p, max: budget)
                let o = out.appendingPathComponent(FilesX.base(ins[0]) + ".docx"); try Office.writeDocx(o, docxFrom(pages))
                let text = pages.map { $0.plain() }.joined(separator: "\n\n"); var seen = Set<String>(); let un = pages.flatMap(\.unsure).filter { seen.insert($0).inserted }
                await MainActor.run { review.name = FilesX.base(ins[0]); review.text = text; review.unsure = un; review.ready = true }
                return [o]
            }
            var paras: [Office.Para] = []
            for (i, lines) in try pdfLines(ins[0], ocr: false, p).enumerated() {
                if i > 0 { paras.append(.pageBreak) }
                var buf = ""
                for l in lines { if l.trimmingCharacters(in: .whitespaces).isEmpty { if !buf.isEmpty { paras.append(.text(buf.trimmingCharacters(in: .whitespaces))); buf = "" } } else { buf += l.trimmingCharacters(in: .whitespaces) + " " } }
                if !buf.isEmpty { paras.append(.text(buf.trimmingCharacters(in: .whitespaces))) }
            }
            let o = out.appendingPathComponent(FilesX.base(ins[0]) + ".docx"); try Office.writeDocx(o, paras); return [o]
        }
    }
}

struct WordToPdf: View {
    let tool: Tool
    var body: some View {
        FileTool(tool: tool, types: [docxType], pickLabel: "اختر ملف Word (DOCX)", actionLabel: "تحويل إلى PDF", options: { _ in Hint(text: "يدعم DOCX. ملفات DOC القديمة احفظها بصيغة DOCX أولًا.") }) { ins, out, _ in
            let b = DocBuilder()
            for line in try Office.readDocx(ins[0]) {
                if line.contains("\t") { b.add(.table(header: [], rows: [line.components(separatedBy: "\t")])) }
                else if line.trimmingCharacters(in: .whitespaces).isEmpty { b.add(.space(8)) } else { b.add(.para(line)) }
            }
            return [try b.save(to: out.appendingPathComponent(FilesX.base(ins[0]) + ".pdf"))]
        }
    }
}

struct PdfToExcel: View {
    let tool: Tool; @State var ocr = false
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF", actionLabel: "تحويل إلى Excel", options: { _ in
            Panel { Toggle("التعرف الضوئي على الصفحات", isOn: $ocr).font(.plex(.subheadline)); Hint(text: "كل صفحة ورقة عمل، وكل سطر صف. الأعمدة تُفصل حيث توجد مسافات واسعة أو علامات جدولة.") }
        }) { ins, out, p in
            let sheets = try pdfLines(ins[0], ocr: ocr, p).enumerated().map { i, lines in
                ("صفحة \(i + 1)", lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { l in
                    l.trimmingCharacters(in: .whitespaces).components(separatedBy: "\t").flatMap { $0.components(separatedBy: "   ") }.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } })
            }
            let o = out.appendingPathComponent(FilesX.base(ins[0]) + ".xlsx"); try Office.writeXlsx(o, sheets); return [o]
        }
    }
}

struct ExcelToPdf: View {
    let tool: Tool; @State var landscape = true; @State var headerRow = true
    var body: some View {
        FileTool(tool: tool, types: [xlsxType], pickLabel: "اختر ملف Excel (XLSX)", actionLabel: "تحويل إلى PDF", options: { _ in
            Panel { Toggle("صفحة أفقية", isOn: $landscape); Toggle("الصف الأول عناوين", isOn: $headerRow) }.font(.plex(.subheadline))
        }) { ins, out, _ in
            let sheets = try Office.readXlsx(ins[0]); guard !sheets.isEmpty else { throw UserError("لم يُعثر على أوراق عمل في الملف") }
            let b = DocBuilder(landscape: landscape)
            for (i, s) in sheets.enumerated() {
                if i > 0 { b.add(.pageBreak) }
                b.add(.heading(s.0))
                let clean = s.1.filter { $0.contains { !$0.isEmpty } }; let w = clean.map(\.count).max() ?? 0
                let padded = clean.map { $0 + Array(repeating: "", count: w - $0.count) }
                if !padded.isEmpty { b.add(.table(header: headerRow ? padded[0] : [], rows: headerRow ? Array(padded.dropFirst()) : padded)) }
            }
            return [try b.save(to: out.appendingPathComponent(FilesX.base(ins[0]) + ".pdf"))]
        }
    }
}

struct PdfToPpt: View {
    let tool: Tool
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF", actionLabel: "تحويل إلى PowerPoint", options: { _ in Hint(text: "كل صفحة تصبح شريحة بشكلها الأصلي تمامًا (صورة عالية الدقة).") }) { ins, out, p in
            let d = try PdfEngine.open(ins[0])
            let slides: [Office.Slide] = (0..<d.pageCount).compactMap { i in
                p.update(i, d.pageCount, "الصفحة \(i + 1) من \(d.pageCount)")
                guard let page = d.page(at: i) else { return nil }
                let img = PdfEngine.render(page, dpi: 150)
                return Office.Slide(title: "", png: img.pngData(), w: Int(img.size.width), h: Int(img.size.height))
            }
            let o = out.appendingPathComponent(FilesX.base(ins[0]) + ".pptx"); try Office.writePptx(o, slides); return [o]
        }
    }
}

struct PptToPdf: View {
    let tool: Tool
    var body: some View {
        FileTool(tool: tool, types: [pptxType], pickLabel: "اختر عرض PowerPoint (PPTX)", actionLabel: "تحويل إلى PDF", options: { _ in Hint(text: "تُنقل نصوص كل شريحة إلى صفحة أفقية. الصور والأشكال لا تُنقل في هذا الإصدار.") }) { ins, out, _ in
            let b = DocBuilder(landscape: true)
            for (i, s) in try Office.readPptx(ins[0]).enumerated() {
                if i > 0 { b.add(.pageBreak) }
                let lines = s.components(separatedBy: "\n")
                b.add(.title(lines.first ?? "شريحة \(i + 1)", sub: "شريحة \(i + 1)"))
                lines.dropFirst().forEach { b.add(.para("• \($0)", size: 14)) }
            }
            return [try b.save(to: out.appendingPathComponent(FilesX.base(ins[0]) + ".pdf"))]
        }
    }
}

struct PdfToImages: View {
    let tool: Tool; @State var png = 0; @State var dpi = 1; @State var range = ""
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF", actionLabel: "تحويل إلى صور", options: { _ in
            Panel { Seg(options: ["JPG", "PNG"], selection: $png); Text("الدقة").font(.plex(.subheadline, .semibold)); Seg(options: ["عادية 100", "عالية 150", "طباعة 300"], selection: $dpi)
                Field(label: "الصفحات (فارغ = الكل) مثل 1-3, 7", text: $range) }
        }) { ins, out, p in
            let d = try PdfEngine.open(ins[0])
            let pages = range.isEmpty ? Array(0..<d.pageCount) : PdfEngine.parseRanges(range, count: d.pageCount)
            return try pages.enumerated().compactMap { i, pg in
                p.update(i, pages.count, "صفحة \(i + 1) من \(pages.count)")
                guard let page = d.page(at: pg) else { return nil }
                let img = PdfEngine.render(page, dpi: [100, 150, 300][dpi])
                let u = out.appendingPathComponent("\(FilesX.base(ins[0]))-\(pg + 1).\(png == 1 ? "png" : "jpg")")
                try (png == 1 ? img.pngData() : img.jpegData(compressionQuality: 0.92))?.write(to: u); return u
            }
        }
    }
}

struct ImagesToPdf: View {
    let tool: Tool; @State var a4 = true
    var body: some View {
        FileTool(tool: tool, types: [.image], multiple: true, pickLabel: "اختر الصور", actionLabel: "إنشاء PDF", reorderable: true, options: { _ in
            Panel { Toggle("ضبط على صفحات A4", isOn: $a4).font(.plex(.subheadline)); Text("رتّب الصور بالأسهم قبل الإنشاء.").font(.plex(.caption)) }
        }) { ins, out, _ in
            [try PdfEngine.fromImages(ins.compactMap { ImageEngine.load($0, maxSide: 2400) }, a4: a4, to: out.appendingPathComponent("صور-\(ins.count).pdf"))]
        }
    }
}

struct PdfMerge: View {
    let tool: Tool
    var body: some View {
        FileTool(tool: tool, types: [.pdf], multiple: true, pickLabel: "اختر ملفين أو أكثر", actionLabel: "دمج الملفات", reorderable: true, validate: { $0.count < 2 ? "اختر ملفين على الأقل" : nil }) { ins, out, _ in
            [try PdfEngine.write(try PdfEngine.merge(ins), out.appendingPathComponent("مدمج-\(ins.count).pdf"))]
        }
    }
}

struct PdfSplit: View {
    let tool: Tool; @State var mode = 0; @State var spec = ""
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF", actionLabel: "تقسيم", validate: { $0.isEmpty ? "اختر ملفًا" : (mode == 1 && spec.isEmpty ? "اكتب النطاقات" : nil) }, options: { ins in
            Panel { PageCountLabel(url: ins[0]); Seg(options: ["كل صفحة ملف", "حسب النطاقات"], selection: $mode); if mode == 1 { Field(label: "النطاقات، كل نطاق ملف: 1-3, 4-6, 7-", text: $spec) } }
        }) { ins, out, _ in
            let d = try PdfEngine.open(ins[0])
            let groups: [[Int]] = mode == 0 ? (0..<d.pageCount).map { [$0] } : spec.split(whereSeparator: { $0 == "," || $0 == "،" }).map { PdfEngine.parseRanges(String($0), count: d.pageCount) }.filter { !$0.isEmpty }
            return try groups.enumerated().map { i, g in try PdfEngine.write(PdfEngine.select(d, g), out.appendingPathComponent("\(FilesX.base(ins[0]))-\(i + 1).pdf")) }
        }
    }
}

struct PdfCompress: View {
    let tool: Tool; @State var level = 1
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF", actionLabel: "ضغط الملف", options: { _ in
            Panel { Seg(options: ["خفيف", "متوازن", "قوي"], selection: $level); Hint(text: "يُعاد رسم الصفحات كصور مضغوطة فيصغر الحجم كثيرًا خاصة للملفات الممسوحة. النص يصبح غير قابل للتحديد.") }
        }) { ins, out, p in
            let (dpi, q): (CGFloat, CGFloat) = [(150, 0.8), (110, 0.65), (80, 0.45)][level]
            let o = try PdfEngine.compress(ins[0], dpi: dpi, quality: q, to: out.appendingPathComponent(FilesX.base(ins[0]) + "-مضغوط.pdf")) { i, n in p.update(i, n, "صفحة \(i + 1) من \(n)") }
            p.say("من \(FilesX.human(FilesX.size(ins[0]))) إلى \(FilesX.human(FilesX.size(o)))"); return [o]
        }
    }
}

struct PdfPages: View {
    enum Mode { case reorder, delete, extract, rotate }
    let tool: Tool; let mode: Mode
    @State var spec = ""; @State var reverse = 0; @State var deg = 0
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF", actionLabel: title,
                 validate: { $0.isEmpty ? "اختر ملفًا" : (needsSpec && spec.isEmpty ? "حدد الصفحات" : nil) }, options: { ins in
            Panel {
                PageCountLabel(url: ins[0])
                switch mode {
                case .reorder: Seg(options: ["ترتيب مخصص", "عكس الترتيب"], selection: $reverse); if reverse == 0 { Field(label: "الترتيب الجديد مثل: 3, 1, 2, 4-10", text: $spec) }
                case .delete: Field(label: "الصفحات المطلوب حذفها مثل: 2, 5-7", text: $spec)
                case .extract: Field(label: "الصفحات المطلوبة مثل: 1, 4-6", text: $spec)
                case .rotate: Seg(options: ["90° يمين", "180°", "90° يسار"], selection: $deg); Field(label: "الصفحات (فارغ = الكل)", text: $spec)
                }
            }
        }) { ins, out, _ in
            let d = try PdfEngine.open(ins[0]); let n = d.pageCount; let base = FilesX.base(ins[0])
            switch mode {
            case .reorder: return [try PdfEngine.write(PdfEngine.select(d, reverse == 1 ? Array((0..<n).reversed()) : PdfEngine.parseRanges(spec, count: n)), out.appendingPathComponent("\(base)-مرتب.pdf"))]
            case .delete:
                let del = Set(PdfEngine.parseRanges(spec, count: n)); let keep = (0..<n).filter { !del.contains($0) }
                guard !keep.isEmpty else { throw PdfEngine.Failure.empty }
                return [try PdfEngine.write(PdfEngine.select(d, keep), out.appendingPathComponent("\(base)-معدل.pdf"))]
            case .extract: return [try PdfEngine.write(PdfEngine.select(d, PdfEngine.parseRanges(spec, count: n)), out.appendingPathComponent("\(base)-مستخرج.pdf"))]
            case .rotate:
                let pages = spec.isEmpty ? Array(0..<n) : PdfEngine.parseRanges(spec, count: n)
                for i in pages { if let p = d.page(at: i) { p.rotation = (p.rotation + [90, 180, 270][deg]) % 360 } }
                return [try PdfEngine.write(d, out.appendingPathComponent("\(base)-مدور.pdf"))]
            }
        }
    }
    private var needsSpec: Bool { mode == .delete || mode == .extract || (mode == .reorder && reverse == 0) }
    private var title: String { switch mode { case .reorder: "إعادة الترتيب"; case .delete: "حذف الصفحات"; case .extract: "استخراج"; case .rotate: "تدوير" } }
}

struct PdfProtect: View {
    let tool: Tool; @State var pass = ""; @State var pass2 = ""; @State var mark = ""
    @ObservedObject private var plus = Plus.shared
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF", actionLabel: "حماية الملف",
                 validate: { $0.isEmpty ? "اختر ملفًا" : pass.count < 4 ? "كلمة المرور 4 أحرف على الأقل" : pass != pass2 ? "كلمتا المرور غير متطابقتين" : nil }, options: { _ in
            Panel {
                HStack(spacing: 6) { Text("علامة مائية (اختياري)").font(.plex(.subheadline, .semibold)); PlusBadge() }.frame(maxWidth: .infinity)
                Field(label: "نص العلامة، مثل: سري أو نسخة للمراجعة", text: Binding(get: { mark }, set: { v in if v.isEmpty || plus.allow(.sign) { mark = v } }))
            }
            Panel { Field(label: "كلمة المرور", text: $pass, secure: true); Field(label: "تأكيد كلمة المرور", text: $pass2, secure: true); Hint(text: "احتفظ بكلمة المرور؛ لا يمكن استرجاعها إن نُسيت.") }
        }) { ins, out, _ in
            var src = ins[0]
            let open = await MainActor.run { Plus.shared.unlocked }
            let m = mark.trimmingCharacters(in: .whitespaces)
            if !m.isEmpty && open { src = try PdfEngine.watermark(src, text: m, to: FileManager.default.temporaryDirectory.appendingPathComponent("wm-\(UUID().uuidString).pdf")) }
            return [try PdfEngine.protect(src, password: pass, to: out.appendingPathComponent(FilesX.base(ins[0]) + "-محمي.pdf"))]
        }
    }
}

struct PdfUnlock: View {
    let tool: Tool; @State var pass = ""
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF المحمي", actionLabel: "إزالة الحماية", options: { _ in
            Panel { Field(label: "كلمة مرور الملف", text: $pass, secure: true); Hint(text: "استخدمها فقط لملفات تملكها أو مصرح لك بها.") }
        }) { ins, out, _ in [try PdfEngine.unlock(ins[0], password: pass, to: out.appendingPathComponent(FilesX.base(ins[0]) + "-مفتوح.pdf"))] }
    }
}

struct ZipTool: View {
    let tool: Tool; @State var name = "أرشيف"
    var body: some View {
        FileTool(tool: tool, types: [.item], multiple: true, pickLabel: "اختر الملفات", actionLabel: "إنشاء ZIP", options: { _ in Panel { Field(label: "اسم الأرشيف", text: $name) } }) { ins, out, _ in
            let o = out.appendingPathComponent("\(name.isEmpty ? "أرشيف" : name).zip")
            try Zip.write(try ins.map { ($0.lastPathComponent, try Data(contentsOf: $0)) }, to: o); return [o]
        }
    }
}

struct UnzipTool: View {
    let tool: Tool
    var body: some View {
        FileTool(tool: tool, types: [.zip], pickLabel: "اختر ملف ZIP", actionLabel: "فك الضغط") { ins, out, _ in
            let dir = out.appendingPathComponent(FilesX.base(ins[0]), isDirectory: true)
            var res: [URL] = []
            for (name, data) in try Zip.read(ins[0]) {
                let u = dir.appendingPathComponent(name).standardizedFileURL
                guard u.path.hasPrefix(dir.standardizedFileURL.path + "/") else { continue } // block "../" traversal
                try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: u); res.append(u)
            }
            if res.isEmpty { throw UserError("الأرشيف فارغ أو تالف") }
            return res
        }
    }
}
