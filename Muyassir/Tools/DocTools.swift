import SwiftUI
import PDFKit
import PhotosUI
import UniformTypeIdentifiers

/// Text form whose values are remembered on the device between visits.
final class FormState: ObservableObject {
    let name: String
    @Published var v: [String: String]
    init(_ name: String) { self.name = name; v = (Store.shared.obj("form_\(name)") as? [String: String]) ?? [:] }
    subscript(_ k: String) -> String { v[k] ?? "" }
    func bind(_ k: String) -> Binding<String> { Binding(get: { self.v[k] ?? "" }, set: { self.v[k] = $0 }) }
    func save() { Store.shared.saveObj("form_\(name)", v) }
}

struct CvTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @StateObject var f = FormState("cv")
    @State var result: [URL] = []
    @State var lang = 0
    var body: some View {
        ToolScreen(tool: tool) {
            Panel(title: "البيانات الشخصية") {
                Field(label: "الاسم الكامل", text: f.bind("name")); Field(label: "المسمى المهني", text: f.bind("title"))
                Field(label: "الجوال", text: f.bind("phone"), kind: .phonePad); Field(label: "البريد الإلكتروني", text: f.bind("email"), kind: .emailAddress)
                Field(label: "المدينة", text: f.bind("city")); Field(label: "رابط (لينكدإن/موقع)", text: f.bind("link"), kind: .URL)
            }
            Panel(title: "المحتوى (سطر لكل عنصر)") {
                Field(label: "نبذة مختصرة", text: f.bind("summary"), lines: 3)
                Field(label: "الخبرات العملية", text: f.bind("exp"), lines: 4); Field(label: "التعليم", text: f.bind("edu"), lines: 3)
                Field(label: "المهارات", text: f.bind("skills"), lines: 3); Field(label: "الشهادات والدورات", text: f.bind("certs"), lines: 3); Field(label: "اللغات", text: f.bind("langs"), lines: 2)
            }
            Panel { Seg(options: ["سيرة عربية", "English CV"], selection: $lang); if lang == 1 { Hint(text: "اكتب البيانات بالإنجليزية؛ تُكتب العناوين بالإنجليزية ويُحاذى النص لليسار.") } }
            TemplatePanel(useLogo: false)
            PrimaryButton(title: "إنشاء السيرة الذاتية PDF", icon: "doc.richtext", enabled: !f["name"].isEmpty) {
                f.save()
                let en = lang == 1
                let h: [String: String] = en ? ["نبذة": "Summary", "الخبرات العملية": "Experience", "التعليم": "Education", "المهارات": "Skills", "الشهادات والدورات": "Courses & certificates", "اللغات": "Languages"] : [:]
                let b = Templates.apply(DocBuilder(), logo: false); b.ltr = en
                b.add(.title(f["name"], sub: f["title"]))
                b.add(.para([f["phone"], f["email"], f["city"], f["link"]].filter { !$0.isEmpty }.joined(separator: "   |   "), size: 10, color: DocBuilder.muted))
                b.add(.rule)
                func sec(_ title: String, _ k: String, bullets: Bool = true) {
                    let lines = f[k].components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    guard !lines.isEmpty else { return }
                    b.add(.heading(h[title] ?? title)); for l in lines { b.add(.para(bullets ? "• \(l)" : l)) }
                }
                sec("نبذة", "summary", bullets: false); sec("الخبرات العملية", "exp"); sec("التعليم", "edu"); sec("المهارات", "skills"); sec("الشهادات والدورات", "certs"); sec("اللغات", "langs")
                result = [try? b.save(to: FilesX.outDir().appendingPathComponent((en ? "CV-" : "السيرة-الذاتية-") + "\(f["name"]).pdf"))].compactMap { $0 }; store.used(tool.id, f["name"])
            }
            if !result.isEmpty { ResultFiles(files: result) }
        }
    }
}

struct BillingDoc: View {
    let tool: Tool; let quote: Bool
    @EnvironmentObject var store: Store
    @StateObject var f: FormState
    struct Item: Identifiable { let id = UUID(); var d = ""; var q = "1"; var p = "" }
    @State var items = [Item()]; @State var withVat = true; @State var result: [URL] = []
    @State var clients: [[String: String]] = (UserDefaults.standard.array(forKey: "clients") as? [[String: String]]) ?? []
    @State var toInvoice = false
    init(tool: Tool, quote: Bool) { self.tool = tool; self.quote = quote; _f = StateObject(wrappedValue: FormState(quote ? "quote" : "invoice")) }
    var body: some View {
        let sub = items.reduce(0) { $0 + $1.q.num * $1.p.num }
        let v = withVat ? Calc.vat(sub, inclusive: false) : Calc.Vat(net: sub, vat: 0, total: sub)
        ToolScreen(tool: tool) {
            Panel(title: "البائع") { Field(label: "اسم المنشأة", text: f.bind("seller")); Field(label: "الرقم الضريبي", text: f.bind("vatNo"), kind: .numberPad); Field(label: "العنوان والتواصل", text: f.bind("sellerInfo"), lines: 2) }
            Panel(title: "العميل") {
                if !clients.isEmpty {
                    Text("عملاء سابقون").font(.plex(.caption, .semibold))
                    ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(clients.prefix(12), id: \.self) { c in Chip(text: c["buyer"] ?? "", selected: false) { f.v["buyer"] = c["buyer"]; f.v["buyerInfo"] = c["buyerInfo"] } } } }
                }
                Field(label: "اسم العميل", text: f.bind("buyer")); Field(label: "بيانات العميل (اختياري)", text: f.bind("buyerInfo"), lines: 2)
            }
            Panel { Field(label: quote ? "رقم العرض (فارغ = ترقيم تلقائي)" : "رقم الفاتورة (فارغ = ترقيم تلقائي)", text: f.bind("no")); Field(label: quote ? "الشروط ومدة صلاحية العرض" : "ملاحظات وطريقة الدفع", text: f.bind("notes"), lines: 3) }
            Panel(title: "البنود") {
                ForEach($items) { $it in
                    HStack {
                        Field(label: "الوصف", text: $it.d); NumField(label: "الكمية", text: $it.q).frame(width: 80); NumField(label: "السعر", text: $it.p).frame(width: 100)
                        Button { if items.count > 1 { items.removeAll { $0.id == it.id } } } label: { Image(systemName: "xmark") }.buttonStyle(.borderless).accessibilityLabel("حذف البند")
                    }
                }
                SecondaryButton(title: "إضافة بند", icon: "plus") { items.append(Item()) }
                Toggle("إضافة ضريبة القيمة المضافة 15%", isOn: $withVat).font(.plex(.subheadline))
            }
            ResultCard(main: ("الإجمالي", money(v.total)), rows: [("المجموع قبل الضريبة", money(v.net)), ("الضريبة", money(v.vat))])
            TemplatePanel()
            PrimaryButton(title: quote ? "إنشاء عرض السعر" : "إنشاء الفاتورة", icon: "doc.richtext", enabled: sub > 0) {
                // automatic numbering and the saved clients list
                let key = quote ? "counter_q" : "counter_i", n = UserDefaults.standard.integer(forKey: key) + 1
                let number = f["no"].isEmpty ? (quote ? "Q-" : "INV-") + String(format: "%04d", n) : f["no"]
                if f["no"].isEmpty { UserDefaults.standard.set(n, forKey: key) }
                if !f["buyer"].isEmpty {
                    clients.removeAll { $0["buyer"] == f["buyer"] }; clients.insert(["buyer": f["buyer"], "buyerInfo": f["buyerInfo"]], at: 0)
                    clients = Array(clients.prefix(30)); UserDefaults.standard.set(clients, forKey: "clients")
                }
                let typed = f["no"]; f.v["no"] = ""; f.save(); f.v["no"] = typed
                let b = Templates.apply(DocBuilder())
                b.add(.title(quote ? "عرض سعر" : withVat ? "فاتورة ضريبية مبسطة" : "فاتورة", sub: f["seller"] + (f["vatNo"].isEmpty ? "" : "  •  الرقم الضريبي: \(f["vatNo"])")))
                var kv: [(String, String)] = [(quote ? "رقم العرض" : "رقم الفاتورة", number), ("التاريخ", dayFmt.string(from: Date())), ("العميل", f["buyer"])]
                if !f["buyerInfo"].isEmpty { kv.append(("بيانات العميل", f["buyerInfo"])) }
                if !f["sellerInfo"].isEmpty { kv.append(("بيانات البائع", f["sellerInfo"])) }
                b.add(.keyValues(kv))
                let rows = items.filter { !$0.d.isEmpty || $0.p.num > 0 }.enumerated().map { i, x in ["\(i + 1)", x.d, fmt(x.q.num), fmt(x.p.num), fmt(x.q.num * x.p.num)] }
                b.add(.table(header: ["#", "الوصف", "الكمية", "السعر", "المجموع"], rows: rows, weights: [0.4, 3, 0.8, 1, 1.2]))
                var tot: [(String, String)] = [("المجموع قبل الضريبة", money(v.net))]
                if withVat { tot.append(("ضريبة القيمة المضافة 15%", money(v.vat))) }
                tot.append(("الإجمالي المستحق", money(v.total))); b.add(.keyValues(tot))
                if !f["notes"].isEmpty { b.add(.heading(quote ? "الشروط" : "ملاحظات")); b.add(.para(f["notes"])) }
                if !quote && withVat { b.add(.para("تنبيه: هذا مستند مبسط. الفوترة الإلكترونية الإلزامية (فاتورة) تتطلب نظامًا معتمدًا من هيئة الزكاة والضريبة والجمارك.", size: 8.5, color: DocBuilder.muted)) }
                let name = "\(quote ? "عرض-سعر" : "فاتورة")-\(f["buyer"].isEmpty ? "عميل" : f["buyer"]).pdf"
                result = [try? b.save(to: FilesX.outDir().appendingPathComponent(name))].compactMap { $0 }; store.used(tool.id, f["buyer"])
            }
            if !result.isEmpty {
                ResultFiles(files: result)
                if quote {
                    SecondaryButton(title: "تحويل العرض إلى فاتورة", icon: "doc.text") {
                        BillingDraft.pending = (["seller": f["seller"], "vatNo": f["vatNo"], "sellerInfo": f["sellerInfo"], "buyer": f["buyer"], "buyerInfo": f["buyerInfo"]], items.map { ($0.d, $0.q, $0.p) })
                        toInvoice = true
                    }.accessibilityIdentifier("quoteToInvoice")
                }
            }
        }
        .navigationDestination(isPresented: $toInvoice) { if let t = Tools.byId["invoice"] { InvoiceTool(tool: t) } }
        .onAppear {
            // A quote turned into an invoice arrives with its items.
            if !quote, let d = BillingDraft.pending { BillingDraft.pending = nil; d.0.forEach { f.v[$0.key] = $0.value }; items = d.1.map { Item(d: $0.0, q: $0.1, p: $0.2) } }
        }
    }
}
/// Hands a quote's details to the invoice screen.
enum BillingDraft { static var pending: ([String: String], [(String, String, String)])? }
struct InvoiceTool: View { let tool: Tool; var body: some View { BillingDoc(tool: tool, quote: false) } }
struct QuoteTool: View { let tool: Tool; var body: some View { BillingDoc(tool: tool, quote: true) } }

struct LetterTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @StateObject var f = FormState("letter")
    @State var kind = 0; @State var result: [URL] = []
    let kinds = ["خطاب رسمي", "تعريف بالراتب/الخدمة", "طلب إجازة", "استقالة", "شكوى أو طلب"]
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Picker("نوع الخطاب", selection: $kind) { ForEach(kinds.indices, id: \.self) { Text(kinds[$0]).tag($0) } }.onChange(of: kind) { fillTemplate() }
                Field(label: "الجهة المرسلة", text: f.bind("from")); Field(label: "إلى (الجهة/الشخص)", text: f.bind("to")); Field(label: "الموضوع", text: f.bind("subject"))
                Field(label: "نص الخطاب", text: f.bind("body"), lines: 8); Field(label: "الاسم والصفة للتوقيع", text: f.bind("sign"))
            }
            Hint(text: "اختر نوع الخطاب لملء نص مقترح، ثم عدّله كما تريد.")
            TemplatePanel()
            PrimaryButton(title: "إنشاء الخطاب PDF", icon: "doc.richtext", enabled: !f["body"].isEmpty) {
                f.save()
                let b = Templates.apply(DocBuilder())
                if !f["from"].isEmpty { b.add(.para(f["from"], size: 13, bold: true)) }
                b.add(.para("التاريخ: \(dayFmt.string(from: Date()))", size: 10, color: DocBuilder.muted)); b.add(.rule)
                if !f["to"].isEmpty { b.add(.para("\(f["to"])     المحترم", size: 12, bold: true)); b.add(.para("السلام عليكم ورحمة الله وبركاته،")) }
                if !f["subject"].isEmpty { b.add(.para("الموضوع: \(f["subject"])", size: 12, bold: true, center: true)) }
                b.add(.para(f["body"], size: 12)); b.add(.space(10)); b.add(.para("وتقبلوا خالص التحية والتقدير،"))
                if !f["sign"].isEmpty { b.add(.space(16)); b.add(.para(f["sign"], size: 12, bold: true)); b.add(.para("التوقيع: ...............................")) }
                result = [try? b.save(to: FilesX.outDir().appendingPathComponent("خطاب-\(f["subject"].isEmpty ? kinds[kind] : f["subject"]).pdf"))].compactMap { $0 }; store.used(tool.id, f["subject"])
            }
            if !result.isEmpty { ResultFiles(files: result) }
        }
    }
    func fillTemplate() {
        let t: [(String, String)] = [
            ("", ""),
            ("طلب خطاب تعريف", "نفيدكم بأن الموظف/ ........ يعمل لدينا بوظيفة ........ منذ تاريخ ........ ولا يزال على رأس العمل، وقد أُعطي هذا الخطاب بناءً على طلبه دون أدنى مسؤولية على المنشأة."),
            ("طلب إجازة", "أتقدم إليكم بطلب إجازة ........ لمدة (....) أيام اعتبارًا من تاريخ ........ وحتى ........، وذلك لظروف ........، آملًا الموافقة."),
            ("استقالة", "أتقدم إليكم باستقالتي من العمل بوظيفة ........ اعتبارًا من تاريخ ........، مع الالتزام بفترة الإشعار المنصوص عليها في العقد ونظام العمل، شاكرًا لكم ما قدمتموه من دعم."),
            ("طلب", "أتقدم إليكم بهذا الطلب بخصوص ........، وأرجو التكرم بالنظر فيه واتخاذ اللازم."),
        ]
        guard kind > 0 else { return }
        f.v["subject"] = t[kind].0; f.v["body"] = t[kind].1
    }
}

struct TextPdfTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var title = ""; @State var text = ""; @State var size = 1; @State var result: [URL] = []
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { Field(label: "العنوان (اختياري)", text: $title); Field(label: "النص", text: $text, lines: 12); Seg(options: ["صغير", "متوسط", "كبير"], selection: $size) }
            TemplatePanel()
            PrimaryButton(title: "تحويل إلى PDF", icon: "doc.richtext", enabled: !text.isEmpty) {
                let b = Templates.apply(DocBuilder()); if !title.isEmpty { b.add(.title(title)) }
                for p in text.components(separatedBy: "\n\n") { b.add(.para(p, size: [10, 12, 14][size])) }
                result = [try? b.save(to: FilesX.outDir().appendingPathComponent("\(title.isEmpty ? "مستند" : title).pdf"))].compactMap { $0 }; store.used(tool.id, title)
            }
            if !result.isEmpty { ResultFiles(files: result) }
        }
    }
}

struct SignPdfTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var strokes: [[CGPoint]] = []; @State var current: [CGPoint] = []; @State var padSize = CGSize(width: 1, height: 1)
    @State var pdf: URL?; @State var pages = 0; @State var page = 1; @State var preview: UIImage?
    @State var x = 0.6; @State var y = 0.8; @State var w = 0.28
    @State var picking = false; @State var result: [URL] = []; @State var error: String?
    // Plus: a saved signature and stamps (any image, e.g. a company stamp)
    @ObservedObject private var plus = Plus.shared
    @State var source = 0; @State var saved: UIImage? = UIImage(contentsOfFile: SignPdfTool.sigURL.path); @State var stampImg: UIImage?; @State var stampItem: PhotosPickerItem?
    static var sigURL: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("data/signature.png") }
    private var chosen: UIImage? { source == 1 ? saved : source == 2 ? stampImg : (strokes.isEmpty ? nil : signature()) }
    private var ratio: CGFloat { (source == 1 ? saved : source == 2 ? stampImg : nil).map { $0.size.height / max($0.size.width, 1) } ?? padSize.height / max(padSize.width, 1) }
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Seg(options: ["ارسم توقيعًا", "توقيعي المحفوظ", "ختم أو صورة"], selection: Binding(get: { source }, set: { v in if v == 0 || plus.allow(.sign) { source = v } }))
                PlusBadge().frame(maxWidth: .infinity)
            }
            if source == 1 {
                Panel(title: "توقيعي المحفوظ") {
                    if let saved { Image(uiImage: saved).resizable().scaledToFit().frame(height: 120).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 14)) }
                    else { Hint(text: "لا يوجد توقيع محفوظ بعد. ارسم توقيعك في «ارسم توقيعًا» ثم اضغط «حفظ هذا التوقيع».") }
                }
            }
            if source == 2 {
                Panel(title: "الختم") {
                    if let stampImg { Image(uiImage: stampImg).resizable().scaledToFit().frame(height: 140).frame(maxWidth: .infinity) }
                    PhotosPicker(selection: $stampItem, matching: .images) {
                        Label(stampImg == nil ? "اختر صورة الختم (PNG شفاف أفضل)" : "تغيير الصورة", systemImage: "seal").font(.plex(.subheadline, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
            if source == 0 { Panel(title: "ارسم توقيعك") {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(.white).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator)))
                    Path { p in for s in strokes + [current] where s.count > 1 { p.move(to: s[0]); for q in s.dropFirst() { p.addLine(to: q) } } }
                        .stroke(Color(hex: 0x0B1F6B), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    if strokes.isEmpty && current.isEmpty { Text("وقّع هنا بإصبعك").foregroundStyle(.gray) }
                }
                .frame(height: 180)
                .background(GeometryReader { g in Color.clear.onAppear { padSize = g.size } })
                .gesture(DragGesture(minimumDistance: 0).onChanged { current.append($0.location) }.onEnded { _ in strokes.append(current); current = [] })
                .environment(\.layoutDirection, .leftToRight)
                HStack {
                    Button("مسح التوقيع") { strokes = [] }
                    Spacer()
                    Button("حفظ هذا التوقيع") {
                        guard plus.allow(.sign), let png = signature().pngData() else { return }
                        try? FileManager.default.createDirectory(at: Self.sigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try? png.write(to: Self.sigURL); saved = UIImage(data: png); error = nil
                    }.disabled(strokes.isEmpty)
                }
            } }
            Panel(title: "المستند") {
                SecondaryButton(title: pdf == nil ? "اختر ملف PDF" : "تغيير الملف", icon: "doc") { picking = true }
                if pdf != nil {
                    Stepper("الصفحة \(page) من \(pages)", value: $page, in: 1...max(pages, 1))
                    if let preview {
                        Image(uiImage: preview).resizable().scaledToFit().overlay(GeometryReader { g in
                            Rectangle().stroke(Brand.lapis, lineWidth: 2).background(Brand.lapis.opacity(0.12))
                                .frame(width: g.size.width * w, height: g.size.width * w * ratio)
                                .position(x: g.size.width * (x + w / 2), y: g.size.height * y + g.size.width * w * ratio / 2)
                        }).environment(\.layoutDirection, .leftToRight)
                    }
                    VStack(alignment: .leading) { Text("الموضع الأفقي").font(.plex(.caption)); Slider(value: $x, in: 0...0.95).environment(\.layoutDirection, .leftToRight)
                        Text("الموضع الرأسي").font(.plex(.caption)); Slider(value: $y, in: 0...0.95); Text("الحجم").font(.plex(.caption)); Slider(value: $w, in: 0.1...0.6) }
                }
            }
            if let error { Text(error).font(.plex(.footnote)).foregroundStyle(.red) }
            PrimaryButton(title: "توقيع وحفظ", icon: "signature", enabled: pdf != nil && chosen != nil) {
                guard let pdf, let img = chosen else { return }
                do { result = [try PdfEngine.stamp(pdf, page: page - 1, image: img, rx: x, ry: y, rw: w, to: FilesX.outDir().appendingPathComponent("مستند-موقع.pdf"))]; store.used(tool.id); error = nil }
                catch { self.error = friendly(error) }
            }
            if !result.isEmpty { ResultFiles(files: result) }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.pdf]) { r in
            guard case let .success(u) = r, let t = try? FilesX.toTemp(u), let d = PDFDocument(url: t) else { return }
            pdf = t; pages = d.pageCount; page = d.pageCount; render()
        }
        .onChange(of: page) { render() }
        .onChange(of: stampItem) { _, it in Task { if let d = try? await it?.loadTransferable(type: Data.self) { stampImg = UIImage(data: d) } } }
    }
    func render() { guard let pdf, let d = PDFDocument(url: pdf), let p = d.page(at: page - 1) else { return }; preview = PdfEngine.render(p, dpi: 60) }
    func signature() -> UIImage {
        let r = UIGraphicsImageRenderer(size: padSize, format: { let f = UIGraphicsImageRendererFormat(); f.opaque = false; f.scale = 3; return f }())
        return r.image { ctx in
            let p = UIBezierPath(); p.lineWidth = 3.5; p.lineCapStyle = .round; p.lineJoinStyle = .round
            for s in strokes where s.count > 1 { p.move(to: s[0]); for q in s.dropFirst() { p.addLine(to: q) } }
            UIColor(red: 0.043, green: 0.122, blue: 0.42, alpha: 1).setStroke(); p.stroke()
        }
    }
}
