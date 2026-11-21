import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Pages (images or PDF pages) → OCR words → reconstructed layout.
func ocrPages(_ ins: [URL], _ p: Progress, max: Int) throws -> [Layout.Result] {
    var pages: [Layout.Result] = []
    for (i, u) in ins.enumerated() {
        if u.pathExtension.lowercased() == "pdf" {
            let d = try PdfEngine.open(u)
            for pg in 0..<d.pageCount where pages.count < max {
                p.update(pg, d.pageCount, "التعرف على الصفحة \(pg + 1) من \(d.pageCount)")
                if let page = d.page(at: pg) { pages.append(Layout.analyze(try Layout.recognizeWords(PdfEngine.render(page, dpi: 220)))) }
            }
        } else if pages.count < max {
            p.update(i, ins.count, "التعرف على الصورة \(i + 1) من \(ins.count)")
            guard let img = ImageEngine.load(u, maxSide: 3000) else { throw UserError("تعذّر فتح الصورة \(u.lastPathComponent)") }
            pages.append(Layout.analyze(try Layout.recognizeWords(img)))
        }
    }
    return pages
}

func docxFrom(_ pages: [Layout.Result]) -> [Office.Para] { pages.enumerated().flatMap { i, r in (i > 0 ? [Office.Para.pageBreak] : []) + Layout.toDocx(r) } }

final class ReviewState: ObservableObject { @Published var text = ""; @Published var unsure: [String] = []; @Published var ready = false; var name = "مستند" }

/// Review before saving: editable text, the unsure words listed, and a real Word file rebuilt from the edit.
struct ReviewPanel: View {
    @ObservedObject var state: ReviewState
    @State private var saved: [URL] = []
    var body: some View {
        if state.ready {
            Panel(title: "راجع النص قبل الحفظ") {
                if state.unsure.isEmpty { Hint(text: "لم يجد المحرك كلمات منخفضة الثقة، لكن راجع الأسماء والأرقام دائمًا.") }
                else {
                    Text("كلمات غير مؤكدة (\(state.unsure.count)): تحقّق منها في النص").font(.plex(.subheadline, .semibold)).foregroundStyle(.red)
                    ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(state.unsure.prefix(40), id: \.self) { Text($0).font(.plex(.caption)).padding(.horizontal, 10).padding(.vertical, 6).background(Color.red.opacity(0.1), in: Capsule()) } } }
                }
                Field(label: "النص المستخرج (الجداول: أعمدة مفصولة بـ |)", text: $state.text, lines: 10).accessibilityIdentifier("reviewText")
                PrimaryButton(title: "حفظ Word بعد المراجعة", icon: "doc.text") {
                    let o = FilesX.outDir().appendingPathComponent("\(state.name)-مراجع.docx")
                    if (try? Office.writeDocx(o, Layout.toDocx(Layout.fromText(state.text)))) != nil { saved = [o] }
                }.accessibilityIdentifier("saveReviewed")
            }
            if !saved.isEmpty { ResultFiles(files: saved) }
        }
    }
}

struct ImagesToWord: View {
    let tool: Tool
    @StateObject private var review = ReviewState()
    var body: some View {
        FileTool(tool: tool, types: [.image, .pdf], multiple: true, pickLabel: "اختر صورًا أو ملف PDF مصوّر", actionLabel: "تحويل إلى Word", reorderable: true, options: { _ in
            Hint(text: "يتعرّف على النص العربي والإنجليزي على جهازك ويعيد بناء العناوين والفقرات والجداول في ملف Word قابل للتعديل. الدقة تعتمد على وضوح الصورة، وستظهر لك الكلمات غير المؤكدة لمراجعتها.")
        }, after: { ReviewPanel(state: review) }) { ins, out, p in
            let budget = await MainActor.run { min(Plus.shared.ocrPages, 60) }
            let pages = try ocrPages(ins, p, max: budget)
            if pages.allSatisfy({ $0.blocks.isEmpty }) { throw UserError("لم يُعثر على نص. جرّب صورة أوضح أو أقرب.") }
            let n = FilesX.base(ins[0]); let o = out.appendingPathComponent("\(n).docx"); try Office.writeDocx(o, docxFrom(pages))
            let text = pages.map { $0.plain() }.joined(separator: "\n\n"); var seen = Set<String>(); let un = pages.flatMap(\.unsure).filter { seen.insert($0).inserted }
            await MainActor.run { review.name = n; review.text = text; review.unsure = un; review.ready = true }
            return [o]
        }
    }
}

/// Quiz maker record (type 0 choice, 1 true/false, 2 open), as QuizMaker reads it.
func quizRecord(_ q: ExamParser.Q) -> Rec {
    var r: Rec = ["q": q.text, "type": q.kind == .choice ? 0 : q.kind == .trueFalse ? 1 : 2, "ans": 0, "mark": "1", "lines": "3"]
    r["opts"] = Array((q.choices + ["", "", "", ""]).prefix(4)); return r
}

struct ExamToDoc: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State private var qs: [ExamParser.Q] = []; @State private var msg: String?
    var body: some View {
        FileTool(tool: tool, types: [.image, .pdf], multiple: true, pickLabel: "صوّر الاختبار أو اختر صوره", actionLabel: "استخراج الأسئلة", reorderable: true, options: { _ in
            Hint(text: "يتعرّف على الأسئلة المرقمة واختياراتها (أ، ب، ج، د) وأسئلة الصح والخطأ، ثم يبني منها ملف Word قابلًا للتعديل. راجع النتيجة قبل الطباعة.")
        }, after: {
            if !qs.isEmpty {
                Panel(title: "\(qs.count) سؤالًا") {
                    ForEach(Array(qs.prefix(30).enumerated()), id: \.offset) { i, q in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(i + 1)) \(q.text)").font(.plex(.subheadline, .semibold))
                            ForEach(q.choices, id: \.self) { Text("   ○ \($0)").font(.plex(.footnote)) }
                        }
                    }
                    SecondaryButton(title: "افتحها في إنشاء الاختبارات", icon: "questionmark.square.dashed") { store.saveList("quiz_draft", qs.map(quizRecord)); DeepLink.shared.target = "tool/quiz_maker" }
                    SecondaryButton(title: "أضفها لبنك الأسئلة", icon: "archivebox") {
                        let bank = store.list("qbank"), have = Set(bank.map { $0.s("q") })
                        let add = qs.filter { !have.contains($0.text) }.map { var r = quizRecord($0); r["subject"] = "مستخرج من صورة"; return r }
                        store.saveList("qbank", bank + add); msg = "أُضيف \(add.count) سؤالًا إلى البنك"
                    }
                    if let msg { Text(msg).font(.plex(.caption)).foregroundStyle(Brand.mint) }
                }.accessibilityIdentifier("examQuestions")
            }
        }) { ins, out, p in
            let budget = await MainActor.run { min(Plus.shared.ocrPages, 30) }
            let pages = try ocrPages(ins, p, max: budget)
            let text = pages.flatMap { $0.blocks.map { b -> String in switch b { case let .heading(t), let .para(t): return t; case let .table(r): return r.map { $0.joined(separator: " ") }.joined(separator: "\n") } } }.joined(separator: "\n")
            let found = ExamParser.parse(text)
            if found.isEmpty { throw UserError("لم أجد أسئلة مرقمة. تأكد أن الصورة واضحة وأن الأسئلة تبدأ بأرقام.") }
            await MainActor.run { qs = found; msg = nil }
            var paras: [Office.Para] = []
            for (i, q) in found.enumerated() {
                paras.append(.text("\(i + 1)) \(q.text)", bold: true))
                for (k, c) in q.choices.enumerated() { paras.append(.text("    \(k < 6 ? String(Array("أبجدهو")[k]) : "-")) \(c)")) }
                if q.kind == .trueFalse { paras.append(.text("    (     ) صح        (     ) خطأ")) }
                if q.kind == .open { paras.append(.text("    ..............................................................")) }
            }
            let o = out.appendingPathComponent("اختبار-قابل-للتعديل.docx"); try Office.writeDocx(o, paras); return [o]
        }
    }
}

/// Header, footer and page numbers on every page of a PDF (drawn over the original vector pages).
struct PdfHeaderFooter: View {
    let tool: Tool
    @State var header = ""; @State var footer = ""; @State var numbers = true; @State var style = 0; @State var skipFirst = false
    var body: some View {
        FileTool(tool: tool, types: [.pdf], pickLabel: "اختر ملف PDF", actionLabel: "إضافة إلى الصفحات",
                 validate: { $0.isEmpty ? "اختر ملفًا أولًا" : (header.isEmpty && footer.isEmpty && !numbers) ? "أضف ترويسة أو تذييلًا أو فعّل الترقيم" : nil },
                 options: { _ in
            Panel {
                Field(label: "الترويسة (أعلى كل صفحة)", text: $header); Field(label: "التذييل (أسفل كل صفحة)", text: $footer)
                Toggle("ترقيم الصفحات", isOn: $numbers).font(.plex(.subheadline))
                if numbers { Seg(options: ["1", "صفحة 1 من 10", "- 1 -"], selection: $style) }
                Toggle("بدون ترويسة ورقم على الصفحة الأولى (الغلاف)", isOn: $skipFirst).font(.plex(.subheadline))
            }
        }, after: { EmptyView() }) { ins, out, p in
            let d = try PdfEngine.open(ins[0]); let n = d.pageCount
            let (h, f, num, st, skip) = await MainActor.run { (header, footer, numbers, style, skipFirst) }
            let o = out.appendingPathComponent(FilesX.base(ins[0]) + "-مرقّم.pdf")
            let first = d.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 595, height: 842)
            let r = UIGraphicsPDFRenderer(bounds: first)
            try r.writePDF(to: o) { ctx in
                for i in 0..<n {
                    guard let page = d.page(at: i) else { continue }
                    p.update(i, n, "الصفحة \(i + 1) من \(n)")
                    let b = page.bounds(for: .mediaBox); ctx.beginPage(withBounds: b, pageInfo: [:])
                    let cg = ctx.cgContext; cg.saveGState(); cg.translateBy(x: 0, y: b.height); cg.scaleBy(x: 1, y: -1); page.draw(with: .mediaBox, to: cg); cg.restoreGState()
                    if skip && i == 0 { continue }
                    let ps = NSMutableParagraphStyle(); ps.alignment = .center; ps.baseWritingDirection = .rightToLeft
                    let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor(white: 0.3, alpha: 1), .paragraphStyle: ps]
                    if !h.isEmpty { (h as NSString).draw(in: CGRect(x: b.width * 0.1, y: 14, width: b.width * 0.8, height: 14), withAttributes: attrs) }
                    let numText = !num ? "" : st == 1 ? "صفحة \(i + 1) من \(n)" : st == 2 ? "- \(i + 1) -" : "\(i + 1)"
                    let bottom = [f, numText].filter { !$0.isEmpty }.joined(separator: "    •    ")
                    if !bottom.isEmpty { (bottom as NSString).draw(in: CGRect(x: b.width * 0.1, y: b.height - 28, width: b.width * 0.8, height: 14), withAttributes: attrs) }
                }
            }
            return [o]
        }
    }
}
