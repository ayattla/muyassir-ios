import Foundation

/// Offline helper: reads what the user wants and suggests tools in order. It only guides; it never claims to have done anything.
enum Assistant {
    struct Step: Identifiable { let tool: Tool; let why: String; var id: String { tool.id } }
    struct Plan { let steps: [Step]; let note: String? }
    private struct Rule { let tool: String; let why: String; let all: [[String]]; var none: [String] = [] }

    private static let rules: [Rule] = [
        Rule(tool: "img_pdf", why: "اجمع الصور في ملف PDF واحد", all: [["صور", "صوره", "image", "photo"], ["pdf"]]),
        Rule(tool: "pdf_img", why: "حوّل صفحات PDF إلى صور", all: [["pdf"], ["الى صور", "الى صوره", "to image", "to jpg"]]),
        Rule(tool: "pdf_merge", why: "ادمج ملفات PDF بالترتيب الذي تريده", all: [["دمج", "اجمع", "جمع", "ضم", "merge"], ["pdf", "ملفات", "مستندات"]], none: ["صور"]),
        Rule(tool: "pdf_compress", why: "صغّر حجم ملف PDF", all: [["ضغط", "تصغير", "تقليل", "صغر", "حجم", "compress"], ["pdf", "ملف", "مستند"]]),
        Rule(tool: "img_compress", why: "صغّر حجم الصور مع الحفاظ على الوضوح", all: [["ضغط", "تصغير", "تقليل", "حجم", "compress"], ["صور", "صوره", "image", "photo"]], none: ["pdf"]),
        Rule(tool: "pdf_word", why: "حوّل PDF إلى ملف Word قابل للتعديل", all: [["pdf"], ["ورد", "word", "تعديل"]]),
        Rule(tool: "word_pdf", why: "حوّل ملف Word إلى PDF", all: [["ورد", "word", "docx"], ["pdf"]], none: ["pdf الى ورد", "pdf الى word"]),
        Rule(tool: "pdf_excel", why: "استخرج الجداول من PDF إلى Excel", all: [["pdf"], ["اكسل", "excel"]]),
        Rule(tool: "ocr", why: "استخرج النص من الصورة أو الملف الممسوح", all: [["نص", "كلام", "كتابه", "ocr", "text", "انسخ"], ["صور", "صوره", "ممسوح", "مصور", "image", "pdf", "استخراج", "استخرج"]]),
        Rule(tool: "scan", why: "صوّر الأوراق بالكاميرا مع قص وتحسين تلقائي", all: [["مسح", "اسكان", "scan", "اصور", "كاميرا", "ورقه", "اوراق"]]),
        Rule(tool: "img_bg", why: "أزل خلفية الصورة", all: [["خلفيه", "background"]]),
        Rule(tool: "id_photo", why: "جهّز صورة بمقاس الجواز أو الهوية", all: [["جواز", "هويه", "شخصيه", "passport", "تاشيره"]]),
        Rule(tool: "img_resize", why: "غيّر أبعاد الصورة", all: [["ابعاد", "مقاس", "resize", "تكبير"]]),
        Rule(tool: "pdf_protect", why: "احمِ الملف بكلمة مرور", all: [["حمايه", "احمي", "احمها", "كلمه مرور", "قفل", "password", "protect"]]),
        Rule(tool: "pdf_split", why: "قسّم الملف إلى أجزاء", all: [["تقسيم", "قسم", "split"]]),
        Rule(tool: "sign_pdf", why: "وقّع المستند بخط يدك", all: [["توقيع", "وقع", "امضاء", "sign"]]),
        Rule(tool: "vat", why: "احسب ضريبة القيمة المضافة", all: [["ضريبه", "vat", "قيمه مضافه"]]),
        Rule(tool: "salary", why: "احسب صافي الراتب وخصم التأمينات", all: [["راتب", "salary", "تامينات"]]),
        Rule(tool: "eos", why: "احسب مكافأة نهاية الخدمة", all: [["نهايه الخدمه", "مكافاه", "استقاله"]]),
        Rule(tool: "gpa", why: "احسب معدلك الفصلي والتراكمي", all: [["معدل", "gpa"]]),
        Rule(tool: "invoice", why: "أنشئ فاتورة", all: [["فاتوره", "invoice"]]),
        Rule(tool: "cv", why: "أنشئ سيرة ذاتية", all: [["سيره", "cv", "resume"]]),
        Rule(tool: "qr_make", why: "أنشئ رمز QR", all: [["qr", "باركود", "رمز"], ["انشاء", "انشئ", "اعمل", "صمم", "create", "make"]]),
        Rule(tool: "qr_read", why: "اقرأ رمز QR", all: [["qr", "باركود"], ["اقرا", "قراءه", "مسح", "scan", "read"]]),
        Rule(tool: "tts", why: "حوّل النص إلى صوت", all: [["صوت", "نطق", "tts"]]),
        Rule(tool: "zip", why: "اجمع الملفات في أرشيف ZIP", all: [["zip", "ارشيف", "مضغوط"]]),
        Rule(tool: "currency", why: "حوّل بين العملات", all: [["عمله", "عملات", "دولار", "صرف", "currency"]]),
    ]

    static func plan(_ request: String) -> Plan {
        let text = Tools.norm(request)
        if text.trimmingCharacters(in: .whitespaces).isEmpty { return Plan(steps: [], note: nil) }
        var hits: [(Int, Step)] = []
        for r in rules {
            guard r.all.allSatisfy({ g in g.contains { text.contains(Tools.norm($0)) } }), !r.none.contains(where: { text.contains(Tools.norm($0)) }), let t = Tools.byId[r.tool] else { continue }
            let pos = r.all[0].compactMap { w in text.range(of: Tools.norm(w)).map { text.distance(from: text.startIndex, to: $0.lowerBound) } }.min() ?? 0
            if !hits.contains(where: { $0.1.tool.id == t.id }) { hits.append((pos, Step(tool: t, why: r.why))) }
        }
        var steps = hits.sorted { $0.0 < $1.0 }.map { $0.1 }
        let ids = steps.map { $0.tool.id }
        if ids.contains("img_pdf") && ids.contains("pdf_compress") { steps = steps.filter { $0.tool.id == "img_pdf" } + steps.filter { $0.tool.id != "img_pdf" } }
        if steps.isEmpty {
            let found = Array(Tools.search(request, usage: [:]).prefix(3))
            return Plan(steps: found.map { Step(tool: $0, why: $0.sub) }, note: found.isEmpty ? "لم أفهم الطلب بعد. جرّب وصفًا مثل: «حوّل خمس صور إلى PDF وصغّر حجمه»." : "أقرب الأدوات لطلبك:")
        }
        return Plan(steps: steps, note: steps.count > 1 ? "نفّذ الخطوات بالترتيب. افتح كل أداة واختر ملفاتك فيها." : nil)
    }

    /// A built-in recipe that does the whole plan in one tap, if there is one.
    static func recipeFor(_ ids: [String]) -> String? {
        let set = Set(ids)
        if set.contains("img_pdf") && set.contains("pdf_compress") { return "doc" }
        if set.contains("pdf_merge") && set.contains("pdf_compress") { return "merge" }
        if set == ["ocr"] { return "text" }
        if !set.isEmpty && set.isSubset(of: ["img_compress", "img_resize"]) { return "light" }
        return nil
    }
}
