import SwiftUI

struct Category: Identifiable, Hashable { let id, title, blurb, icon: String; let hex: UInt32; var color: Color { Color(hex: hex) } }
struct Tool: Identifiable, Hashable { let id: String; let cats: [String]; let title, sub, icon, keys: String }

enum Tools {
    static let categories: [Category] = [
        Category(id: "files", title: "تحويل الملفات", blurb: "PDF وWord وExcel وPowerPoint والضغط", icon: "arrow.left.arrow.right.square", hex: 0x3346D3),
        Category(id: "images", title: "الصور والتصميم", blurb: "ضغط وقص وإزالة خلفية وتحسين", icon: "photo", hex: 0x7340D0),
        Category(id: "study", title: "الطالب والمعلم", blurb: "المعدل والجداول والاختبارات", icon: "graduationcap", hex: 0x0B7F7A),
        Category(id: "saudi", title: "خدمات سعودية", blurb: "الضريبة والرواتب ونهاية الخدمة", icon: "building.columns", hex: 0x23814A),
        Category(id: "productivity", title: "الإنتاجية والتنظيم", blurb: "مفكرة ومهام وميزانية وتذكيرات", icon: "checklist", hex: 0xB0600A),
        Category(id: "docs", title: "إنشاء المستندات", blurb: "سيرة ذاتية وفواتير وخطابات وتوقيع", icon: "doc.badge.plus", hex: 0xC02A63),
        Category(id: "calc", title: "الحسابات والمحولات", blurb: "علمية ووحدات وعملات ومساحات", icon: "function", hex: 0x1F6FB8),
        Category(id: "smart", title: "أدوات ذكية", blurb: "QR ونصوص وصوت", icon: "sparkles", hex: 0xA14522),
    ]

    static let all: [Tool] = [
        Tool(id: "img_word", cats: ["files", "docs"], title: "صور إلى Word", sub: "نص وعناوين وجداول قابلة للتعديل من الصور", icon: "doc.text.viewfinder", keys: "صور الى وورد word تحويل صوره مستند جدول"),
        Tool(id: "exam_doc", cats: ["study", "files"], title: "اختبار مصوّر إلى مستند", sub: "يستخرج الأسئلة والاختيارات من صورة الاختبار", icon: "checklist", keys: "اختبار مصور اسئلة استخراج تحويل ورقة"),
        Tool(id: "pdf_pages", cats: ["files"], title: "ترويسة وتذييل وترقيم", sub: "أضفها لكل صفحات ملف PDF", icon: "list.number", keys: "ترقيم صفحات ترويسة تذييل header footer"),
        Tool(id: "pdf_edit", cats: ["files"], title: "محرر PDF", sub: "كتابة وتظليل وإخفاء وتعبئة النماذج", icon: "pencil.and.outline", keys: "تعديل pdf كتابة تظليل نموذج تعبئة توقيع"),
        Tool(id: "pdf_word", cats: ["files"], title: "PDF إلى Word", sub: "استخراج النص إلى ملف DOCX قابل للتعديل", icon: "doc.richtext", keys: "pdf word docx تحويل وورد"),
        Tool(id: "word_pdf", cats: ["files"], title: "Word إلى PDF", sub: "تحويل DOCX إلى PDF بخط عربي سليم", icon: "doc.text", keys: "word pdf docx وورد"),
        Tool(id: "pdf_excel", cats: ["files"], title: "PDF إلى Excel", sub: "الأسطر والجداول إلى XLSX", icon: "tablecells", keys: "pdf excel xlsx اكسل جدول"),
        Tool(id: "excel_pdf", cats: ["files"], title: "Excel إلى PDF", sub: "جداول XLSX إلى PDF منسّق", icon: "tablecells.badge.ellipsis", keys: "excel pdf xlsx اكسل"),
        Tool(id: "pdf_ppt", cats: ["files"], title: "PDF إلى PowerPoint", sub: "كل صفحة شريحة بشكلها الأصلي", icon: "play.rectangle", keys: "pdf powerpoint pptx عرض شرائح"),
        Tool(id: "ppt_pdf", cats: ["files"], title: "PowerPoint إلى PDF", sub: "نصوص الشرائح إلى صفحات PDF", icon: "rectangle.stack", keys: "powerpoint pptx pdf شرائح"),
        Tool(id: "pdf_img", cats: ["files", "images"], title: "PDF إلى صور", sub: "كل صفحة صورة JPG أو PNG", icon: "photo.on.rectangle", keys: "pdf صور jpg png"),
        Tool(id: "img_pdf", cats: ["files", "images"], title: "صور إلى PDF", sub: "اجمع صورك في ملف واحد", icon: "doc.badge.plus", keys: "صور pdf تحويل"),
        Tool(id: "pdf_merge", cats: ["files"], title: "دمج PDF", sub: "اجمع عدة ملفات بالترتيب الذي تختاره", icon: "arrow.triangle.merge", keys: "دمج pdf merge"),
        Tool(id: "pdf_split", cats: ["files"], title: "تقسيم PDF", sub: "حسب نطاقات أو كل صفحة ملف", icon: "arrow.triangle.branch", keys: "تقسيم split pdf"),
        Tool(id: "pdf_compress", cats: ["files"], title: "ضغط PDF", sub: "تصغير حجم الملف بثلاث درجات", icon: "arrow.down.right.and.arrow.up.left", keys: "ضغط تصغير حجم pdf"),
        Tool(id: "pdf_reorder", cats: ["files"], title: "ترتيب صفحات PDF", sub: "غيّر ترتيب الصفحات أو اعكسه", icon: "arrow.up.arrow.down", keys: "ترتيب صفحات pdf"),
        Tool(id: "pdf_delete", cats: ["files"], title: "حذف صفحات PDF", sub: "احذف صفحات محددة", icon: "trash", keys: "حذف صفحات pdf"),
        Tool(id: "pdf_extract", cats: ["files"], title: "استخراج صفحات PDF", sub: "ملف جديد بالصفحات التي تريدها", icon: "scissors", keys: "استخراج صفحات pdf"),
        Tool(id: "pdf_rotate", cats: ["files"], title: "تدوير صفحات PDF", sub: "90 أو 180 درجة", icon: "rotate.right", keys: "تدوير pdf"),
        Tool(id: "ocr", cats: ["files", "images", "smart"], title: "استخراج النص (OCR)", sub: "عربي وإنجليزي من الصور وملفات PDF، دون إنترنت", icon: "text.viewfinder", keys: "ocr نص استخراج تعرف ضوئي"),
        Tool(id: "scan", cats: ["files"], title: "مسح المستندات بالكاميرا", sub: "قصّ تلقائي وتحسين وحفظ PDF", icon: "doc.viewfinder", keys: "مسح سكانر كاميرا scan"),
        Tool(id: "pdf_protect", cats: ["files"], title: "حماية PDF بكلمة مرور", sub: "تشفير ومنع النسخ والطباعة", icon: "lock.doc", keys: "حماية كلمة مرور تشفير pdf"),
        Tool(id: "pdf_unlock", cats: ["files"], title: "إزالة حماية PDF", sub: "لملف تعرف كلمة مروره", icon: "lock.open", keys: "فك حماية pdf"),
        Tool(id: "zip", cats: ["files"], title: "ضغط ZIP", sub: "اجمع ملفات في أرشيف واحد", icon: "doc.zipper", keys: "zip ضغط ارشيف"),
        Tool(id: "unzip", cats: ["files"], title: "فك ضغط ZIP", sub: "استخرج محتويات الأرشيف", icon: "archivebox", keys: "unzip فك ضغط"),
        Tool(id: "img_convert", cats: ["files", "images"], title: "تحويل صيغ الصور", sub: "JPG وPNG وHEIC", icon: "arrow.left.arrow.right", keys: "تحويل صيغة jpg png webp"),
        Tool(id: "img_compress", cats: ["images"], title: "ضغط الصور", sub: "بجودة تختارها أو حجم مستهدف", icon: "arrow.down.right.and.arrow.up.left", keys: "ضغط صور تصغير"),
        Tool(id: "img_resize", cats: ["images"], title: "تغيير الأبعاد", sub: "بالبكسل أو بالنسبة المئوية", icon: "aspectratio", keys: "ابعاد مقاس resize"),
        Tool(id: "img_crop", cats: ["images"], title: "قص الصور", sub: "نسب جاهزة أو قص حر", icon: "crop", keys: "قص crop"),
        Tool(id: "img_rotate", cats: ["images"], title: "تدوير وقلب", sub: "تدوير وقلب أفقي وعمودي", icon: "rotate.right", keys: "تدوير قلب"),
        Tool(id: "img_enhance", cats: ["images"], title: "تحسين الصور", sub: "إضاءة وتباين وحدّة تلقائية", icon: "wand.and.stars", keys: "تحسين جودة سطوع"),
        Tool(id: "img_bg", cats: ["images"], title: "إزالة الخلفية", sub: "على الجهاز، بصيغة PNG شفافة", icon: "person.and.background.dotted", keys: "ازالة خلفية"),
        Tool(id: "img_batch", cats: ["images"], title: "معالجة دفعة واحدة", sub: "ضغط وتحجيم وتحويل عشرات الصور", icon: "square.stack.3d.down.right", keys: "دفعة جماعي batch"),
        Tool(id: "id_photo", cats: ["images"], title: "صور الوثائق", sub: "مقاسات الجواز والهوية والتأشيرة", icon: "person.text.rectangle", keys: "صورة شخصية جواز هوية"),
        Tool(id: "gpa", cats: ["study"], title: "حاسبة المعدل", sub: "فصلي وتراكمي، من 5 أو من 4", icon: "graduationcap", keys: "معدل gpa تراكمي"),
        Tool(id: "percent", cats: ["study", "calc"], title: "النسب والدرجات", sub: "النسبة المئوية والتقدير", icon: "percent", keys: "نسبة مئوية درجة"),
        Tool(id: "timetable", cats: ["study"], title: "الجدول الدراسي", sub: "حصص الأسبوع في جدول واحد", icon: "calendar.day.timeline.left", keys: "جدول دراسي حصص"),
        Tool(id: "exams", cats: ["study"], title: "جدول الاختبارات", sub: "مع عدّ تنازلي وتذكير", icon: "calendar.badge.clock", keys: "اختبارات امتحانات"),
        Tool(id: "homework", cats: ["study"], title: "تنظيم الواجبات", sub: "حسب المادة وموعد التسليم", icon: "checklist", keys: "واجبات"),
        Tool(id: "attendance", cats: ["study"], title: "متابعة الحضور", sub: "سجل حضور وغياب الطلاب", icon: "person.crop.circle.badge.checkmark", keys: "حضور غياب طلاب"),
        Tool(id: "grades", cats: ["study"], title: "كشف الدرجات", sub: "رصد درجات الطلاب وتصديرها Excel وPDF", icon: "list.number", keys: "درجات كشف رصد طلاب معلم"),
        Tool(id: "quiz_maker", cats: ["study"], title: "إنشاء الاختبارات", sub: "أسئلة اختيار وصح وخطأ إلى PDF", icon: "questionmark.square.dashed", keys: "انشاء اختبار اسئلة"),
        Tool(id: "worksheet", cats: ["study"], title: "أوراق العمل", sub: "ورقة عمل جاهزة للطباعة", icon: "doc.plaintext", keys: "ورقة عمل"),
        Tool(id: "flashcards", cats: ["study"], title: "بطاقات المراجعة", sub: "احفظ بالتكرار المتباعد", icon: "rectangle.on.rectangle.angled", keys: "بطاقات مراجعة"),
        Tool(id: "study_timer", cats: ["study"], title: "مؤقت المذاكرة", sub: "جلسات تركيز واستراحات", icon: "timer", keys: "مؤقت مذاكرة بومودورو"),
        Tool(id: "certificate", cats: ["study", "docs"], title: "شهادات الإنجاز", sub: "شهادة واحدة أو شهادات جماعية من قائمة أسماء", icon: "rosette", keys: "شهادة شكر تقدير"),
        Tool(id: "vat", cats: ["saudi", "calc"], title: "ضريبة القيمة المضافة", sub: "15% إضافة أو استخراج", icon: "doc.text.below.ecg", keys: "ضريبة vat قيمة مضافة"),
        Tool(id: "salary", cats: ["saudi"], title: "حاسبة الراتب", sub: "الإجمالي وخصم التأمينات والصافي", icon: "banknote", keys: "راتب تأمينات gosi"),
        Tool(id: "eos", cats: ["saudi"], title: "مكافأة نهاية الخدمة", sub: "وفق المادتين 84 و85", icon: "briefcase", keys: "نهاية خدمة مكافأة"),
        Tool(id: "leave", cats: ["saudi"], title: "حاسبة الإجازات", sub: "الرصيد المستحق وقيمته", icon: "beach.umbrella", keys: "اجازة سنوية رصيد"),
        Tool(id: "finance", cats: ["saudi", "calc"], title: "التمويل والأقساط", sub: "ثابت أو متناقص مع النسبة الفعلية", icon: "creditcard", keys: "تمويل قسط قرض"),
        Tool(id: "discount", cats: ["saudi", "calc"], title: "حاسبة الخصومات", sub: "خصم واحد أو خصومات متتالية", icon: "tag", keys: "خصم تخفيض"),
        Tool(id: "hijri", cats: ["saudi", "calc"], title: "التاريخ الهجري والميلادي", sub: "تقويم أم القرى الرسمي", icon: "calendar", keys: "هجري ميلادي تحويل تاريخ"),
        Tool(id: "gov_dir", cats: ["saudi"], title: "دليل المنصات الحكومية", sub: "روابط المنصات الرسمية", icon: "building.columns", keys: "منصات حكومية ابشر توكلنا"),
        Tool(id: "emergency", cats: ["saudi"], title: "أرقام الطوارئ", sub: "اتصال مباشر بلمسة", icon: "cross.case", keys: "طوارئ اسعاف شرطة"),
        Tool(id: "zakat", cats: ["saudi", "calc"], title: "حاسبة الزكاة", sub: "النقد والذهب والتجارة مع النصاب", icon: "hands.and.sparkles", keys: "زكاه زكاة نصاب ذهب"),
        Tool(id: "overtime", cats: ["saudi"], title: "العمل الإضافي", sub: "وفق المادة 107 من نظام العمل", icon: "clock.badge", keys: "اضافي اوفر تايم overtime ساعات"),
        Tool(id: "electricity", cats: ["saudi", "calc"], title: "فاتورة الكهرباء", sub: "تقدير بالتعرفة السكنية الحالية والجديدة", icon: "bolt.fill", keys: "كهرباء فاتوره استهلاك كيلو"),
        Tool(id: "date_diff", cats: ["calc", "saudi"], title: "حساب العمر والمدة", sub: "الفرق بين تاريخين بالميلادي والهجري", icon: "birthday.cake", keys: "عمر مده فرق تاريخين ميلاد"),
        Tool(id: "translate", cats: ["smart", "study"], title: "الترجمة على الجهاز", sub: "عربي وإنجليزي لنص أو صورة أو ملف", icon: "translate", keys: "ترجمه ترجم translate انجليزي عربي"),
        Tool(id: "summarize", cats: ["smart", "study"], title: "التلخيص الذكي", sub: "أهم الجمل والكلمات المفتاحية من أي نص أو ملف", icon: "text.badge.star", keys: "تلخيص ملخص لخص summary"),
        Tool(id: "quiz_gen", cats: ["study", "smart"], title: "مولّد أسئلة المراجعة", sub: "أسئلة اختيار من ملاحظاتك وبطاقات مراجعة", icon: "questionmark.bubble", keys: "اسئله مراجعه اختبار توليد بطاقات"),
        Tool(id: "read_aloud", cats: ["smart", "study"], title: "اقرأ لي", sub: "صوّر ورقة أو اختر ملفًا ليُقرأ بصوت عربي", icon: "speaker.wave.2", keys: "اقرا صوت قراءه نطق مكفوفين"),
        Tool(id: "documents", cats: ["saudi", "productivity"], title: "الوثائق والمواعيد", sub: "تنبيه قبل انتهاء الوثائق", icon: "folder.badge.person.crop", keys: "وثائق انتهاء هوية جواز موعد"),
        Tool(id: "notes", cats: ["productivity"], title: "المفكرة", sub: "ملاحظات سريعة محفوظة على جهازك", icon: "note.text", keys: "مفكرة ملاحظات"),
        Tool(id: "tasks", cats: ["productivity"], title: "المهام", sub: "قائمة مهام بأولويات", icon: "checklist.checked", keys: "مهام todo"),
        Tool(id: "calendar", cats: ["productivity"], title: "التقويم", sub: "مواعيدك ومهامك واختباراتك", icon: "calendar", keys: "تقويم"),
        Tool(id: "reminders", cats: ["productivity"], title: "التذكيرات", sub: "تنبيه في الوقت الذي تختاره", icon: "alarm", keys: "تذكير منبه"),
        Tool(id: "budget", cats: ["productivity"], title: "الميزانية الشخصية", sub: "الدخل والمصروف لكل فئة", icon: "chart.pie", keys: "ميزانية"),
        Tool(id: "expenses", cats: ["productivity"], title: "إدارة المصروفات", sub: "سجّل مصروفاتك وصدّرها", icon: "cart", keys: "مصروفات"),
        Tool(id: "cv", cats: ["docs"], title: "السيرة الذاتية", sub: "سيرة عربية أنيقة بصيغة PDF", icon: "person.crop.rectangle", keys: "سيرة ذاتية cv"),
        Tool(id: "invoice", cats: ["docs"], title: "إنشاء الفواتير", sub: "فاتورة ضريبية مبسطة", icon: "doc.text", keys: "فاتورة"),
        Tool(id: "quote", cats: ["docs"], title: "عروض الأسعار", sub: "عرض سعر احترافي", icon: "doc.text.magnifyingglass", keys: "عرض سعر"),
        Tool(id: "letter", cats: ["docs"], title: "التقارير والخطابات", sub: "خطاب رسمي أو تقرير", icon: "envelope", keys: "خطاب تقرير"),
        Tool(id: "sign_pdf", cats: ["docs"], title: "توقيع المستندات", sub: "ارسم توقيعك وضعه على PDF", icon: "signature", keys: "توقيع"),
        Tool(id: "text_pdf", cats: ["docs"], title: "إنشاء PDF", sub: "من نص تكتبه", icon: "doc.badge.plus", keys: "انشاء pdf نص"),
        Tool(id: "scientific", cats: ["calc"], title: "الحاسبة العلمية", sub: "دوال ومثلثات وأسس", icon: "function", keys: "حاسبة علمية"),
        Tool(id: "units", cats: ["calc"], title: "محول الوحدات", sub: "طول ووزن وحرارة وبيانات", icon: "ruler", keys: "وحدات تحويل"),
        Tool(id: "currency", cats: ["calc"], title: "محول العملات", sub: "بأسعار محدّثة عند الطلب", icon: "dollarsign.arrow.circlepath", keys: "عملات دولار ريال"),
        Tool(id: "area_volume", cats: ["calc"], title: "المساحات والأحجام", sub: "12 شكلًا هندسيًا", icon: "square.dashed", keys: "مساحة حجم"),
        Tool(id: "qr_make", cats: ["smart"], title: "إنشاء رمز QR", sub: "رابط أو نص أو واي فاي أو جهة اتصال", icon: "qrcode", keys: "qr باركود انشاء"),
        Tool(id: "qr_read", cats: ["smart"], title: "قراءة QR والباركود", sub: "بالكاميرا أو من صورة", icon: "qrcode.viewfinder", keys: "قراءة qr باركود"),
        Tool(id: "text_compare", cats: ["smart"], title: "مقارنة النصوص", sub: "إبراز الإضافات والحذف", icon: "rectangle.split.2x1", keys: "مقارنة نصوص"),
        Tool(id: "word_count", cats: ["smart"], title: "عداد الكلمات والحروف", sub: "مع زمن القراءة", icon: "textformat.size", keys: "عداد كلمات حروف"),
        Tool(id: "dedupe", cats: ["smart"], title: "إزالة التكرار", sub: "حذف الأسطر المكررة", icon: "line.3.horizontal.decrease", keys: "تكرار حذف"),
        Tool(id: "tts", cats: ["smart"], title: "تحويل النص إلى صوت", sub: "قراءة بصوت عربي وحفظ ملف", icon: "speaker.wave.2", keys: "نص صوت"),
        Tool(id: "stt", cats: ["smart"], title: "تحويل الصوت إلى نص", sub: "إملاء بالعربية والإنجليزية", icon: "mic", keys: "صوت نص املاء"),
    ]

    static let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func inCat(_ c: String) -> [Tool] { all.filter { $0.cats.contains(c) } }
    static func category(_ id: String) -> Category { categories.first { $0.id == id }! }
    static func color(_ t: Tool) -> Color { category(t.cats[0]).color }

    static func norm(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "[\u{064B}-\u{0652}\u{0640}]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[أإآ]", with: "ا", options: .regularExpression).replacingOccurrences(of: "ى", with: "ي").replacingOccurrences(of: "ة", with: "ه")
    }

    static func hex(_ t: Tool) -> UInt32 { category(t.cats[0]).hex }

    /// Words people type → words the tools are described with (Arabic and English), same table as Android.
    static let synonymGroups: [[String]] = [
        ["تصغير", "ضغط", "تقليل", "صغر", "حجم", "compress", "shrink", "reduce", "smaller"], ["دمج", "جمع", "ضم", "merge", "combine", "join"],
        ["تحويل", "حول", "convert"], ["تقسيم", "فصل", "قسم", "split"], ["صوره", "صور", "image", "photo", "picture", "jpg", "png"],
        ["pdf", "بي دي اف", "مستند"], ["ورد", "word", "docx"], ["اكسل", "excel", "xlsx", "جدول"], ["بوربوينت", "powerpoint", "pptx", "عرض"],
        ["نص", "كتابه", "ocr", "text", "استخراج"], ["مسح", "سكانر", "scan", "scanner", "كاميرا"], ["خلفيه", "background", "bg"],
        ["ابعاد", "مقاس", "resize", "size", "تكبير"], ["قص", "crop"], ["تدوير", "rotate", "قلب"], ["حمايه", "قفل", "كلمه مرور", "password", "protect", "lock", "تشفير"],
        ["ضريبه", "vat", "قيمه مضافه"], ["راتب", "رواتب", "salary", "تامينات", "gosi"], ["معدل", "gpa", "درجات", "نسبه"], ["هجري", "تاريخ", "hijri", "ميلادي"],
        ["qr", "كيو ار", "باركود", "barcode", "رمز"], ["صوت", "اقرا", "tts", "speech", "نطق"], ["املاء", "تفريغ", "stt", "dictation"],
        ["فاتوره", "invoice"], ["سيره", "cv", "resume"], ["توقيع", "sign", "signature"], ["عمله", "عملات", "currency", "دولار", "صرف"],
        ["وحدات", "units"], ["ملاحظه", "ملاحظات", "notes", "مفكره"], ["مهام", "tasks", "todo"], ["تذكير", "منبه", "reminder"],
    ].map { $0.map(norm) }
    static func expand(_ w: String) -> [String] {
        if let g = synonymGroups.first(where: { $0.contains(w) }) { return g + [w] }
        if let g = synonymGroups.first(where: { g in g.contains { $0.count > 2 && (w.hasPrefix($0) || $0.hasPrefix(w)) } }) { return g + [w] }
        return [w]
    }
    private static let stop: Set<String> = ["ال", "من", "في", "على", "الى", "ملف", "ملفات", "اريد", "ابي", "ابغى", "كيف"]

    /// Instant search by name, purpose or synonym; best matches first.
    static func search(_ q: String, usage: [String: Int]) -> [Tool] {
        let n = norm(q.trimmingCharacters(in: .whitespaces)); if n.isEmpty { return [] }
        var words = n.split(separator: " ").map(String.init).filter { !stop.contains($0) || n.count <= 3 }
        if words.isEmpty { words = [n] }
        func score(_ t: Tool) -> Int {
            let h = norm("\(t.title) \(t.sub) \(t.keys) \(t.id.replacingOccurrences(of: "_", with: " "))"), title = norm(t.title)
            var s = 0, hits = 0
            for w in words { let alts = expand(w); if alts.contains(where: { h.contains($0) }) { hits += 1; s += alts.contains(where: { title.contains($0) }) ? 6 : 3 } }
            if hits == 0 { return 0 }
            if hits == words.count { s += 10 }
            if title.hasPrefix(n) { s += 12 }
            return s + min(usage[t.id] ?? 0, 5)
        }
        return all.map { ($0, score($0)) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    /// What each kind of user reaches for first (chosen on first run, changeable in Settings).
    static let byRole: [String: [String]] = [
        "student": ["gpa", "flashcards", "study_timer", "exams", "ocr", "scan"],
        "teacher": ["quiz_maker", "worksheet", "exam_doc", "grades", "certificate", "quiz_gen"],
        "employee": ["salary", "overtime", "eos", "letter", "sign_pdf", "pdf_compress"],
        "business": ["invoice", "quote", "vat", "sign_pdf", "expenses", "scan"],
    ]
    static let roles: [(String, String)] = [("student", "طالب"), ("teacher", "معلم"), ("employee", "موظف"), ("business", "صاحب منشأة")]

    static func suggestions(last: String?) -> [Tool] {
        let follow: [String: [String]] = ["scan": ["ocr", "pdf_compress", "sign_pdf"], "pdf_merge": ["pdf_compress", "pdf_protect"], "img_bg": ["id_photo", "img_resize"],
            "ocr": ["word_count", "tts"], "invoice": ["vat", "sign_pdf"], "pdf_word": ["word_pdf"], "salary": ["eos", "leave"], "gpa": ["percent", "study_timer"]]
        var ids = (last.flatMap { follow[$0] } ?? []) + (byRole[UserDefaults.standard.string(forKey: "role") ?? ""] ?? ["scan", "pdf_merge", "img_bg", "vat", "qr_make", "gpa"])
        var seen = Set<String>(); ids = ids.filter { $0 != last && seen.insert($0).inserted }
        return ids.prefix(6).compactMap { byId[$0] }
    }
}

extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255) }
}
