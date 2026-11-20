import SwiftUI
import VisionKit
import PDFKit

struct ImagePreview: View {
    let url: URL?
    var overlay: CGRect? = nil // relative rect
    @State var img: UIImage?
    var body: some View {
        Group {
            if let img {
                VStack(alignment: .leading, spacing: 4) {
                    Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 380)
                        .overlay { GeometryReader { g in if let r = overlay { Rectangle().stroke(Brand.saffron, lineWidth: 3).frame(width: r.width * g.size.width, height: r.height * g.size.height).offset(x: r.minX * g.size.width, y: r.minY * g.size.height) } } }
                        .environment(\.layoutDirection, .leftToRight)
                        .frame(maxWidth: .infinity).background(Color(hex: 0x1B2140), in: RoundedRectangle(cornerRadius: 14))
                    Text("\(Int(img.size.width))×\(Int(img.size.height)) (معاينة)").font(.plex(.caption)).foregroundStyle(.secondary)
                }
            }
        }
        .task(id: url) { img = url.flatMap { ImageEngine.load($0, maxSide: 1200) } }
    }
}

private func name(_ u: URL, _ suffix: String, _ f: ImageEngine.Fmt) -> String { "\(FilesX.base(u))\(suffix).\(f.ext)" }

struct ImgConvert: View {
    let tool: Tool; @State var fmt = 0; @State var q = 90.0
    var body: some View {
        FileTool(tool: tool, types: [.image], multiple: true, pickLabel: "اختر صورة أو أكثر", actionLabel: "تحويل", options: { _ in
            Panel { Seg(options: ImageEngine.Fmt.allCases.map(\.rawValue), selection: $fmt); if fmt != 1 { Text("الجودة \(Int(q))%"); Slider(value: $q, in: 40...100) } }
        }) { ins, out, p in
            let f = ImageEngine.Fmt.allCases[fmt]
            return try ins.enumerated().compactMap { i, u in p.update(i, ins.count); guard let img = ImageEngine.load(u) else { return nil }; return try ImageEngine.save(img, f, quality: q / 100, to: out.appendingPathComponent(name(u, "", f))) }
        }
    }
}

struct ImgCompress: View {
    let tool: Tool; @State var mode = 0; @State var q = 70.0; @State var kb = "200"
    var body: some View {
        FileTool(tool: tool, types: [.image], multiple: true, pickLabel: "اختر الصور", actionLabel: "ضغط", options: { _ in
            Panel { Seg(options: ["حسب الجودة", "حجم مستهدف"], selection: $mode)
                if mode == 0 { Text("الجودة \(Int(q))%"); Slider(value: $q, in: 20...95) } else { NumField(label: "الحجم الأقصى لكل صورة", text: $kb, suffix: "ك.ب") }
                Hint(text: "مفيد لرفع الصور على المنصات التي تحدد حجمًا أقصى للمرفقات.") }
        }) { ins, out, p in
            try ins.enumerated().compactMap { i, u in
                p.update(i, ins.count); guard let img = ImageEngine.load(u) else { return nil }
                let o = out.appendingPathComponent(name(u, "-مضغوط", .jpg))
                return mode == 0 ? try ImageEngine.save(img, .jpg, quality: q / 100, to: o) : try ImageEngine.compressToSize(img, kb: max(Int(kb.num), 10), to: o)
            }
        }
    }
}

struct ImgResize: View {
    let tool: Tool; @State var mode = 0; @State var w = "1080"; @State var h = "1080"; @State var pct = 50.0; @State var keep = true
    var body: some View {
        FileTool(tool: tool, types: [.image], multiple: true, pickLabel: "اختر الصور", actionLabel: "تغيير الأبعاد", options: { ins in
            ImagePreview(url: ins.first)
            Panel { Seg(options: ["بالبكسل", "بالنسبة"], selection: $mode)
                if mode == 0 { HStack { NumField(label: "العرض", text: $w); NumField(label: "الارتفاع", text: $h) }; Toggle("الحفاظ على النسبة", isOn: $keep) }
                else { Text("\(Int(pct))%"); Slider(value: $pct, in: 5...200) } }
        }) { ins, out, p in
            try ins.enumerated().compactMap { i, u in
                p.update(i, ins.count); guard let img = ImageEngine.load(u, maxSide: 8000) else { return nil }
                let r = mode == 0 ? ImageEngine.resize(img, w: w.num, h: h.num, keep: keep) : ImageEngine.resize(img, w: img.size.width * pct / 100, h: img.size.height * pct / 100, keep: false)
                return try ImageEngine.save(r, .jpg, quality: 0.92, to: out.appendingPathComponent(name(u, "-\(Int(r.size.width))x\(Int(r.size.height))", .jpg)))
            }
        }
    }
}

struct ImgCrop: View {
    let tool: Tool
    private let ratios: [(String, CGFloat)] = [("حر", 0), ("1:1", 1), ("4:3", 4 / 3), ("3:4", 3 / 4), ("16:9", 16 / 9), ("9:16", 9 / 16)]
    @State var ratio = 0; @State var l = 0.1; @State var t = 0.1; @State var r = 0.9; @State var b = 0.9
    var body: some View {
        FileTool(tool: tool, types: [.image], pickLabel: "اختر صورة", actionLabel: "قص", options: { ins in
            Panel { ScrollView(.horizontal) { HStack { ForEach(ratios.indices, id: \.self) { i in Chip(text: ratios[i].0, selected: i == ratio) { ratio = i } } } } }
            ImagePreview(url: ins.first, overlay: ratio == 0 ? CGRect(x: l, y: t, width: max(r - l, 0.01), height: max(b - t, 0.01)) : nil)
            if ratio == 0 {
                Panel {
                    Text("الحد الأيسر \(Int(l * 100))%"); Slider(value: $l, in: 0...max(r - 0.05, 0.01))
                    Text("الحد الأيمن \(Int(r * 100))%"); Slider(value: $r, in: min(l + 0.05, 0.99)...1)
                    Text("الأعلى \(Int(t * 100))%"); Slider(value: $t, in: 0...max(b - 0.05, 0.01))
                    Text("الأسفل \(Int(b * 100))%"); Slider(value: $b, in: min(t + 0.05, 0.99)...1)
                }
            }
        }) { ins, out, _ in
            guard let img = ImageEngine.load(ins[0], maxSide: 8000) else { throw UserError("تعذّر فتح الصورة") }
            let res = ratio == 0 ? ImageEngine.cropRect(img, l: l, t: t, r: r, b: b) : ImageEngine.cropRatio(img, ratios[ratio].1, 1)
            return [try ImageEngine.save(res, .png, quality: 1, to: out.appendingPathComponent(name(ins[0], "-مقصوص", .png)))]
        }
    }
}

struct ImgRotate: View {
    let tool: Tool; @State var deg = 0; @State var fh = false; @State var fv = false
    var body: some View {
        FileTool(tool: tool, types: [.image], multiple: true, pickLabel: "اختر الصور", actionLabel: "تطبيق", options: { ins in
            ImagePreview(url: ins.first)
            Panel { Seg(options: ["بدون", "90°", "180°", "270°"], selection: $deg); Toggle("قلب أفقي", isOn: $fh); Toggle("قلب عمودي", isOn: $fv) }
        }) { ins, out, _ in
            try ins.compactMap { u in guard let img = ImageEngine.load(u, maxSide: 8000) else { return nil }
                return try ImageEngine.save(ImageEngine.rotate(img, degrees: CGFloat(deg * 90), flipH: fh, flipV: fv), .jpg, quality: 0.95, to: out.appendingPathComponent(name(u, "-مدور", .jpg))) }
        }
    }
}

struct ImgEnhance: View {
    let tool: Tool; @State var auto = true; @State var br = 0.0; @State var ct = 1.0; @State var sat = 1.0; @State var sharp = true; @State var gray = false
    var body: some View {
        FileTool(tool: tool, types: [.image], multiple: true, pickLabel: "اختر الصور", actionLabel: "تحسين", options: { ins in
            ImagePreview(url: ins.first)
            Panel {
                Toggle("تحسين تلقائي", isOn: $auto)
                if !auto {
                    Text("السطوع \(fmt(br, 2))"); Slider(value: $br, in: -0.4...0.4)
                    Text("التباين \(fmt(ct, 2))"); Slider(value: $ct, in: 0.5...2)
                    Text("التشبع \(fmt(sat, 2))"); Slider(value: $sat, in: 0...2)
                    Toggle("زيادة الحدّة", isOn: $sharp); Toggle("أبيض وأسود", isOn: $gray)
                }
            }
        }) { ins, out, p in
            try ins.enumerated().compactMap { i, u in
                p.update(i, ins.count); guard let img = ImageEngine.load(u, maxSide: 3000) else { return nil }
                let r = auto ? ImageEngine.autoEnhance(img) : ImageEngine.adjust(img, brightness: br, contrast: ct, saturation: sat, sharpen: sharp, gray: gray)
                return try ImageEngine.save(r, .jpg, quality: 0.94, to: out.appendingPathComponent(name(u, "-محسنة", .jpg)))
            }
        }
    }
}

struct ImgBackground: View {
    let tool: Tool; @State var bg = 0
    private let colors: [(String, UIColor?)] = [("شفاف", nil), ("أبيض", .white), ("أزرق", UIColor(red: 0.18, green: 0.29, blue: 1, alpha: 1)), ("رمادي", UIColor(white: 0.9, alpha: 1))]
    var body: some View {
        FileTool(tool: tool, types: [.image], multiple: true, pickLabel: "اختر صورة لشخص أو منتج", actionLabel: "إزالة الخلفية", options: { ins in
            ImagePreview(url: ins.first)
            Panel { Text("الخلفية الجديدة").font(.plex(.subheadline, .semibold)); HStack { ForEach(colors.indices, id: \.self) { i in Chip(text: colors[i].0, selected: i == bg) { bg = i } } }
                Hint(text: "يعمل على جهازك بتقنية Apple Vision دون رفع الصورة.") }
        }) { ins, out, p in
            try ins.enumerated().compactMap { i, u in
                p.update(i, ins.count, "صورة \(i + 1) من \(ins.count)")
                guard let img = ImageEngine.load(u, maxSide: 2048) else { return nil }
                let fg = try ImageEngine.removeBackground(img)
                if let c = colors[bg].1 { return try ImageEngine.save(ImageEngine.flatten(fg, c), .jpg, quality: 0.95, to: out.appendingPathComponent(name(u, "-خلفية", .jpg))) }
                return try ImageEngine.save(fg, .png, quality: 1, to: out.appendingPathComponent(name(u, "-بدون-خلفية", .png)))
            }
        }
    }
}

struct ImgBatch: View {
    let tool: Tool; @State var maxSide = "1600"; @State var q = 80.0; @State var fmt = 0; @State var enhance = false; @State var gray = false
    var body: some View {
        FileTool(tool: tool, types: [.image], multiple: true, pickLabel: "اختر عشرات الصور دفعة واحدة", actionLabel: "معالجة الكل", options: { ins in
            Panel(title: "الإعدادات (\(ins.count) صورة)") {
                NumField(label: "أقصى طول للضلع (0 = بدون تغيير)", text: $maxSide, suffix: "بكسل")
                Text("الجودة \(Int(q))%"); Slider(value: $q, in: 30...100)
                Seg(options: ImageEngine.Fmt.allCases.map(\.rawValue), selection: $fmt)
                Toggle("تحسين تلقائي", isOn: $enhance); Toggle("أبيض وأسود", isOn: $gray)
            }
        }) { ins, out, p in
            let f = ImageEngine.Fmt.allCases[fmt], m = CGFloat(maxSide.num)
            return try ins.enumerated().compactMap { i, u in
                try autoreleasepool {
                    p.update(i, ins.count, "صورة \(i + 1) من \(ins.count)")
                    guard var img = ImageEngine.load(u, maxSide: m > 0 ? m : 6000) else { return nil }
                    if enhance { img = ImageEngine.autoEnhance(img) }
                    if gray { img = ImageEngine.adjust(img, brightness: 0, contrast: 1, saturation: 0, sharpen: false, gray: true) }
                    return try ImageEngine.save(img, f, quality: q / 100, to: out.appendingPathComponent(name(u, "", f)))
                }
            }
        }
    }
}

struct IdPhoto: View {
    let tool: Tool
    private let sizes: [(String, CGFloat, CGFloat)] = [("جواز/هوية 4×6 سم", 40, 60), ("تأشيرة 3.5×4.5 سم", 35, 45), ("2×2 بوصة", 50.8, 50.8), ("3×4 سم", 30, 40)]
    private let bgs: [(String, UIColor)] = [("أبيض", .white), ("أزرق فاتح", UIColor(red: 0.86, green: 0.9, blue: 0.97, alpha: 1)), ("رمادي فاتح", UIColor(white: 0.94, alpha: 1))]
    @State var size = 0; @State var removeBg = true; @State var bg = 0
    var body: some View {
        FileTool(tool: tool, types: [.image], pickLabel: "اختر صورة شخصية واضحة", actionLabel: "تجهيز الصورة", options: { ins in
            ImagePreview(url: ins.first)
            Panel {
                Picker("المقاس", selection: $size) { ForEach(sizes.indices, id: \.self) { Text(sizes[$0].0).tag($0) } }
                Toggle("استبدال الخلفية", isOn: $removeBg)
                if removeBg { HStack { ForEach(bgs.indices, id: \.self) { i in Chip(text: bgs[i].0, selected: i == bg) { bg = i } } } }
                Hint(text: "تأكد من متطلبات الجهة (لون الخلفية والمقاس) قبل الطباعة. الدقة 300 نقطة لكل بوصة.")
            }
        }) { ins, out, _ in
            guard var img = ImageEngine.load(ins[0], maxSide: 2400) else { throw UserError("تعذّر فتح الصورة") }
            if removeBg { img = ImageEngine.flatten(try ImageEngine.removeBackground(img), bgs[bg].1) }
            let s = sizes[size]
            return [try ImageEngine.save(ImageEngine.idPhoto(img, wMm: s.1, hMm: s.2, bg: bgs[bg].1), .jpg, quality: 0.97, to: out.appendingPathComponent("صورة-وثيقة-\(Int(s.1))x\(Int(s.2)).jpg"))]
        }
    }
}

struct OcrTool: View {
    let tool: Tool; @State var lang = 0; @State var text = ""
    var body: some View {
        FileTool(tool: tool, types: [.image, .pdf], multiple: true, pickLabel: "اختر صورًا أو ملف PDF", actionLabel: "استخراج النص", options: { _ in
            Panel { Seg(options: Ocr.Lang.allCases.map(\.rawValue), selection: $lang); Hint(text: "يعمل دون إنترنت. للحصول على أفضل نتيجة استخدم صورة واضحة ومستقيمة.") }
        }, after: { if !text.isEmpty { TextResult(text: text, label: "النص المستخرج") } }) { ins, out, p in
            var all: [String] = []
            for (i, u) in ins.enumerated() {
                if u.pathExtension.lowercased() == "pdf", let d = PDFDocument(url: u) {
                    for pg in 0..<d.pageCount { p.update(pg, d.pageCount, "\(u.lastPathComponent): صفحة \(pg + 1)"); if let page = d.page(at: pg) { all.append(try Ocr.recognize(PdfEngine.render(page, dpi: 220), Ocr.Lang.allCases[lang])) } }
                } else if let img = ImageEngine.load(u, maxSide: 3000) {
                    p.update(i, ins.count, "صورة \(i + 1) من \(ins.count)"); all.append(try Ocr.recognize(img, Ocr.Lang.allCases[lang]))
                }
            }
            let t = all.joined(separator: "\n\n")
            await MainActor.run { text = t }
            let txt = out.appendingPathComponent("نص-مستخرج.txt"); try t.write(to: txt, atomically: true, encoding: .utf8)
            let docx = out.appendingPathComponent("نص-مستخرج.docx"); try Office.writeDocx(docx, t.components(separatedBy: "\n\n").map { .text($0) })
            return [txt, docx]
        }
    }
}

struct DocScanner: UIViewControllerRepresentable {
    let done: ([UIImage]) -> Void
    func makeCoordinator() -> C { C(done) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController { let v = VNDocumentCameraViewController(); v.delegate = context.coordinator; return v }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    final class C: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([UIImage]) -> Void; init(_ d: @escaping ([UIImage]) -> Void) { done = d }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) { done((0..<scan.pageCount).map { scan.imageOfPage(at: $0) }); c.dismiss(animated: true) }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { c.dismiss(animated: true) }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError e: Error) { c.dismiss(animated: true) }
    }
}

struct ScanTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var showing = false; @State var results: [URL] = []; @State var error: String?
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Text("صوّر المستند وسيُقص ويُحسَّن تلقائيًا، ويمكنك إضافة عدة صفحات.").font(.plex(.subheadline))
                PrimaryButton(title: "بدء المسح", icon: "doc.viewfinder") { if VNDocumentCameraViewController.isSupported { showing = true } else { error = "الماسح غير متاح على هذا الجهاز (يتطلب كاميرا)." } }
                Hint(text: "الماسح من Apple ويعمل على الجهاز دون رفع الصور.")
            }
            if let error { Text(error).foregroundStyle(.red).font(.plex(.subheadline)) }
            if !results.isEmpty { ResultFiles(files: results) }
        }
        .fullScreenCover(isPresented: $showing) {
            DocScanner { imgs in
                let out = FilesX.outDir()
                var r: [URL] = []
                if let pdf = try? PdfEngine.fromImages(imgs, a4: false, to: out.appendingPathComponent("مستند-ممسوح.pdf")) { r.append(pdf) }
                for (i, img) in imgs.enumerated() { if let u = try? ImageEngine.save(img, .jpg, quality: 0.9, to: out.appendingPathComponent("صفحة-\(i + 1).jpg")) { r.append(u) } }
                results = r; store.used(tool.id, r.first?.lastPathComponent ?? "")
            }.ignoresSafeArea()
        }
    }
}
