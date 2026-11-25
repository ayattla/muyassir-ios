import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// PDF editor: add text, highlight, white-out, and fill interactive forms, all on the device (PDFKit).
struct PdfEditTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @ObservedObject private var plus = Plus.shared
    @State var doc: PDFDocument?; @State var src: URL?
    @State var mode = 0; @State var note = ""; @State var size = "14"; @State var colorIdx = 0
    @State var added: [(PDFPage, PDFAnnotation)] = []
    @State var picking = false; @State var flatten = false; @State var files: [URL] = []; @State var error: String?
    let modes = ["كتابة", "تظليل", "إخفاء", "تعبئة النموذج"]
    let inks: [(String, UIColor)] = [("أسود", .black), ("أزرق", UIColor(red: 0.1, green: 0.25, blue: 0.85, alpha: 1)), ("أحمر", UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1))]
    var fields: Int { guard let doc else { return 0 }; return (0..<doc.pageCount).reduce(0) { $0 + (doc.page(at: $1)?.annotations.filter { $0.type == "Widget" }.count ?? 0) } }
    var body: some View {
        ToolScreen(tool: tool) {
            if doc == nil {
                PrimaryButton(title: "اختر ملف PDF", icon: "doc.badge.plus") { picking = true }.accessibilityIdentifier("pick")
                Hint(text: "اكتب على أي ملف PDF، ظلل أو أخف أجزاء منه، أو عبئ حقول النماذج. كل شيء على جهازك.")
            } else if let doc {
                Panel {
                    Seg(options: modes, selection: $mode)
                    switch mode {
                    case 0:
                        Field(label: "النص", text: $note).accessibilityIdentifier("editText")
                        HStack { NumField(label: "حجم الخط", text: $size).frame(width: 120); ForEach(inks.indices, id: \.self) { i in Chip(text: inks[i].0, selected: i == colorIdx) { colorIdx = i } } }
                        Hint(text: "اكتب النص ثم اضغط مكانه على الصفحة.")
                    case 1: Hint(text: "اضغط على السطر الذي تريد تظليله.")
                    case 2: Hint(text: "اضغط على ما تريد إخفاءه ليغطى بمستطيل أبيض.")
                    default: Hint(text: fields > 0 ? "في الملف \(fields) حقلا. اضغط أي حقل في الصفحة واكتب فيه مباشرة." : "هذا الملف لا يحتوي حقول نموذج قابلة للتعبئة. استخدم «كتابة» لإضافة نص فوقه.")
                    }
                }
                PDFKitView(document: doc, interactive: mode == 3) { page, pt in place(page, pt) }
                    .frame(height: 520).clipShape(RoundedRectangle(cornerRadius: Radius.m)).accessibilityIdentifier("pagePreview")
                HStack {
                    SecondaryButton(title: "تراجع", icon: "arrow.uturn.backward") { if let (p, a) = added.popLast() { p.removeAnnotation(a) } }
                    SecondaryButton(title: "ملف آخر", icon: "doc") { self.doc = nil; added = []; files = [] }
                }
                Toggle("دمج التعديلات في الصفحات (لا تعدل لاحقا)", isOn: $flatten).font(.plex(.subheadline))
                PrimaryButton(title: "حفظ الملف", icon: "square.and.arrow.down") { save(doc) }.accessibilityIdentifier("action")
                if let error { Text(error).font(.plex(.caption)).foregroundStyle(.red) }
                if !files.isEmpty { ResultFiles(files: files) }
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.pdf]) { r in
            guard case .success(let u) = r, let t = try? FilesX.toTemp(u) else { return }
            if let d = PDFDocument(url: t) { if d.isLocked { error = "الملف محمي بكلمة مرور. افتحه أولا بأداة «إزالة حماية PDF»." } else { doc = d; src = t; error = nil } }
        }
        .onAppear {
            #if DEBUG
            if doc == nil, let spec = ProcessInfo.processInfo.environment["MYS_TEST_INPUTS"], let u = TestInputs.make(spec).first(where: { $0.pathExtension == "pdf" }), let d = PDFDocument(url: u) { doc = d; src = u }
            #endif
        }
    }

    private func place(_ page: PDFPage, _ pt: CGPoint) {
        let a: PDFAnnotation
        switch mode {
        case 0:
            let t = note.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
            let fs = CGFloat(min(max(size.num, 6), 72)), font = UIFont(name: "IBMPlexSansArabic-Regular", size: fs) ?? .systemFont(ofSize: fs)
            let w = (t as NSString).size(withAttributes: [.font: font]).width + fs
            a = PDFAnnotation(bounds: CGRect(x: pt.x - w / 2, y: pt.y - fs * 0.7, width: w, height: fs * 1.5), forType: .freeText, withProperties: nil)
            a.contents = t; a.font = font; a.fontColor = inks[colorIdx].1; a.color = .clear; a.alignment = .center
            let b = PDFBorder(); b.lineWidth = 0; a.border = b
        case 1:
            a = PDFAnnotation(bounds: CGRect(x: pt.x - 90, y: pt.y - 9, width: 180, height: 18), forType: .highlight, withProperties: nil)
            a.color = UIColor.systemYellow.withAlphaComponent(0.45)
        case 2:
            a = PDFAnnotation(bounds: CGRect(x: pt.x - 80, y: pt.y - 12, width: 160, height: 24), forType: .square, withProperties: nil)
            a.color = .white; a.interiorColor = .white; let b = PDFBorder(); b.lineWidth = 0; a.border = b
        default: return
        }
        page.addAnnotation(a); added.append((page, a))
    }

    private func save(_ d: PDFDocument) {
        let sz = src.map { FilesX.size($0) } ?? 0
        if let r = plus.check(tool.id, sizes: [sz]) { plus.paywall = r; return }
        let name = (src.map(FilesX.base) ?? "ملف") + "-معدل.pdf"
        let out = FilesX.outDir().appendingPathComponent(name)
        var opts: [PDFDocumentWriteOption: Any] = [:]
        if flatten { opts[.burnInAnnotationsOption] = true }
        if d.write(to: out, withOptions: opts) { files = [out]; plus.counted(tool.id); store.used(tool.id, name); ReviewAsk.success(); error = nil }
        else { error = "تعذر حفظ الملف" }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument; let interactive: Bool; let tap: (PDFPage, CGPoint) -> Void
    func makeCoordinator() -> C { C(self) }
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView(); v.document = document; v.autoScales = true; v.displayMode = .singlePageContinuous; v.backgroundColor = .secondarySystemBackground
        let g = UITapGestureRecognizer(target: context.coordinator, action: #selector(C.tapped(_:))); g.cancelsTouchesInView = false; v.addGestureRecognizer(g)
        context.coordinator.gesture = g
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) {
        if v.document !== document { v.document = document }
        context.coordinator.parent = self; context.coordinator.gesture?.isEnabled = !interactive
    }
    final class C: NSObject {
        var parent: PDFKitView; weak var gesture: UITapGestureRecognizer?
        init(_ p: PDFKitView) { parent = p }
        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard let v = g.view as? PDFView else { return }
            let p = g.location(in: v)
            guard let page = v.page(for: p, nearest: true) else { return }
            parent.tap(page, v.convert(p, to: page))
        }
    }
}
