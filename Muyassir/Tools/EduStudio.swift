import SwiftUI
import UniformTypeIdentifiers

/// Shared vocabulary of the education studio.
enum Edu {
    static let types = ["اختيار من متعدد", "صح وخطأ", "مقالي", "إكمال الفراغ", "توصيل"]
    static let stages = ["ابتدائي", "متوسط", "ثانوي", "جامعي"]
    static let levels = ["سهل", "متوسط", "صعب"]
    static func blanked(_ s: String) -> String { s.replacingOccurrences(of: "_{2,}|…+|\\.{4,}", with: "..................", options: .regularExpression) }
    static func pairs(_ s: String) -> [(String, String)] {
        s.components(separatedBy: "\n").compactMap { l in
            let p = l.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            return p.count == 2 && !p[0].isEmpty ? (p[0], p[1]) : nil
        }
    }
    static func shuffled<T>(_ l: [T], _ seed: Int) -> [T] { var g = TextAi.Seeded(UInt64(seed)); return l.shuffled(using: &g) }

    /// Reads a bank from Excel/CSV rows: السؤال، النوع، أ، ب، ج، د، الإجابة، الدرجة، المادة، الصف، الدرس، الصعوبة.
    static func importRows(_ rows: [[String]]) -> [Rec] {
        guard let head = rows.first?.map({ $0.trimmingCharacters(in: .whitespaces) }) else { return [] }
        let hasHead = head.contains { ["السؤال", "question", "Question"].contains($0) }
        func col(_ r: [String], _ name: String, _ idx: Int) -> String {
            let i = hasHead ? head.firstIndex(of: name) : idx
            guard let i, i < r.count else { return "" }; return r[i].trimmingCharacters(in: .whitespaces)
        }
        return (hasHead ? Array(rows.dropFirst()) : rows).compactMap { r in
            let q = col(r, "السؤال", 0); if q.isEmpty { return nil }
            let opts = ["أ", "ب", "ج", "د"].enumerated().map { col(r, $0.element, 2 + $0.offset) }
            let t = types.firstIndex(of: col(r, "النوع", 1)) ?? (opts.filter { !$0.isEmpty }.count >= 2 ? 0 : (q.contains("__") || q.contains("…")) ? 3 : 2)
            let ans = col(r, "الإجابة", 6)
            var o: Rec = ["q": q, "type": t, "mark": col(r, "الدرجة", 7).isEmpty ? "1" : col(r, "الدرجة", 7), "lines": "3", "opts": opts,
                          "subject": col(r, "المادة", 8), "grade": col(r, "الصف", 9), "lesson": col(r, "الدرس", 10), "level": col(r, "الصعوبة", 11)]
            switch t {
            case 0: o["ans"] = ["أ", "ب", "ج", "د"].firstIndex(of: ans) ?? opts.firstIndex(of: ans) ?? 0
            case 1: o["ans"] = (ans.hasPrefix("خ") || ans.lowercased() == "false") ? 1 : 0
            default: o["answer"] = ans
            }
            return o
        }
    }
}

struct QuizMaker: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    struct Q: Identifiable { let id = UUID(); var type = 0; var text = ""; var opts = ["", "", "", ""]; var ans = 0; var lines = "3"; var mark = "1"; var answer = ""; var pairs = ""
        init(type: Int = 0) { self.type = type }
        init(_ r: Rec) { type = r["type"] as? Int ?? 0; text = r.s("q"); opts = Array(((r["opts"] as? [String]) ?? []) + ["", "", "", ""]).prefix(4).map { $0 }
            ans = r["ans"] as? Int ?? 0; lines = r.s("lines").isEmpty ? "3" : r.s("lines"); mark = r.s("mark").isEmpty ? "1" : r.s("mark"); answer = r.s("answer"); pairs = r.s("pairs") }
        var rec: Rec { ["type": type, "q": text, "opts": opts, "ans": ans, "lines": lines, "mark": mark, "answer": answer, "pairs": pairs] }
    }
    @State var title = "اختبار قصير"; @State var school = ""; @State var stage = 0; @State var grade = ""; @State var subject = ""; @State var lesson = ""
    @State var level = 1; @State var minutes = ""; @State var english = false
    @State var qs: [Q] = []; @State var addType = 0; @State var withKey = true; @State var word = true; @State var result: [URL] = []
    var body: some View {
        ToolScreen(tool: tool) {
            Panel(title: "إعدادات الاختبار") {
                Field(label: "عنوان الاختبار", text: $title); Field(label: "المدرسة/الجهة", text: $school)
                Seg(options: Edu.stages, selection: $stage)
                HStack { Field(label: "الصف", text: $grade); Field(label: "المادة", text: $subject) }
                Field(label: "الدرس أو الوحدة", text: $lesson)
                Text("مستوى الصعوبة").font(.plex(.caption, .medium)).foregroundStyle(Brand.text2); Seg(options: Edu.levels, selection: $level)
                NumField(label: "مدة الاختبار", text: $minutes, suffix: "دقيقة")
                Toggle("اختبار باللغة الإنجليزية (من اليسار لليمين)", isOn: $english).font(.plex(.subheadline))
            }
            ForEach($qs) { $q in
                Panel(title: "السؤال \((qs.firstIndex { $0.id == q.id } ?? 0) + 1)") {
                    Picker("نوع السؤال", selection: $q.type) { ForEach(Edu.types.indices, id: \.self) { Text(Edu.types[$0]).tag($0) } }
                    Field(label: q.type == 3 ? "نص السؤال (اكتب ___ مكان الفراغ)" : "نص السؤال", text: $q.text, lines: 2)
                    switch q.type {
                    case 0: ForEach(0..<4, id: \.self) { k in HStack { Button { q.ans = k } label: { Image(systemName: q.ans == k ? "largecircle.fill.circle" : "circle") }.buttonStyle(.plain); Field(label: "الخيار \(Array("أبجد")[k])", text: $q.opts[k]) } }
                    case 1: Seg(options: ["صح", "خطأ"], selection: $q.ans)
                    case 2: NumField(label: "عدد أسطر الإجابة", text: $q.lines); Field(label: "معيار التصحيح (يظهر في نموذج الإجابة)", text: $q.answer, lines: 2)
                    case 3: Field(label: "الإجابة الصحيحة", text: $q.answer)
                    default: Field(label: "الأزواج: سطر لكل زوج بصيغة «العمود الأول = ما يقابله»", text: $q.pairs, lines: 4)
                    }
                    NumField(label: "الدرجة", text: $q.mark)
                    Button("حذف السؤال", role: .destructive) { qs.removeAll { $0.id == q.id } }
                }
            }
            Panel {
                Picker("نوع السؤال الجديد", selection: $addType) { ForEach(Edu.types.indices, id: \.self) { Text(Edu.types[$0]).tag($0) } }.accessibilityIdentifier("newType")
                SecondaryButton(title: "إضافة سؤال", icon: "plus") { qs.append(Q(type: addType)) }
            }
            QuestionBank(qs: $qs, subject: subject, grade: grade, lesson: lesson, level: Edu.levels[level])
            Toggle("إنشاء نموذج إجابة منفصل مع معايير التقويم", isOn: $withKey).font(.plex(.subheadline))
            Toggle("ملف Word قابل للتعديل أيضًا", isOn: $word).font(.plex(.subheadline))
            TemplatePanel()
            PrimaryButton(title: "إنشاء PDF", icon: "doc.richtext", enabled: !qs.isEmpty) { build() }.accessibilityIdentifier("action")
            if !result.isEmpty { ResultFiles(files: result) }
        }
        .onAppear {
            let m = store.obj("quiz_meta")
            if !m.s("title").isEmpty { title = m.s("title"); school = m.s("school"); stage = m["stage"] as? Int ?? 0; grade = m.s("grade"); subject = m.s("subject"); lesson = m.s("lesson"); level = m["level"] as? Int ?? 1; minutes = m.s("minutes") }
            let d = store.list("quiz_draft"); if !d.isEmpty { qs += d.map(Q.init); store.saveList("quiz_draft", []) }
            let pre = Assistant.takePrefill(); if !pre.s("grade").isEmpty { grade = pre.s("grade") }; if !pre.s("subject").isEmpty { subject = pre.s("subject") }
        }
    }

    @MainActor private func build() {
        store.saveObj("quiz_meta", ["title": title, "school": school, "stage": stage, "grade": grade, "subject": subject, "lesson": lesson, "level": level, "minutes": minutes])
        let out = FilesX.outDir(), total = fmt(qs.reduce(0) { $0 + $1.mark.num })
        let L: [String: String] = english
            ? ["name": "Student name", "score": "Score", "key": " — Answer key", "t": "True", "f": "False", "ans": "Answer", "mark": "mark", "rubric": "Marking guide"]
            : ["name": "اسم الطالب", "score": "الدرجة", "key": " — نموذج الإجابة", "t": "صح", "f": "خطأ", "ans": "الإجابة", "mark": "درجة", "rubric": "معيار التصحيح"]
        let letters = Array(english ? "ABCD" : "أبجد")
        var info: [(String, String)] = [(english ? "Level" : "المرحلة", Edu.stages[stage])]
        if !grade.isEmpty { info.append((english ? "Grade" : "الصف", grade)) }
        if !lesson.isEmpty { info.append((english ? "Lesson" : "الدرس", lesson)) }
        if !minutes.isEmpty { info.append((english ? "Time" : "الزمن", english ? "\(minutes) min" : "\(minutes) دقيقة")) }
        info.append((english ? "Difficulty" : "الصعوبة", Edu.levels[level]))
        func pdf(_ key: Bool) -> URL? {
            let b = Templates.apply(DocBuilder()); b.ltr = english
            b.add(.title(title + (key ? L["key"]! : ""), sub: [school, subject].filter { !$0.isEmpty }.joined(separator: " • ")))
            b.add(.keyValues(info + (key ? [] : [(L["name"]!, "........................................"), (L["score"]!, "......... / \(total)")])))
            for (i, q) in qs.enumerated() {
                b.add(.para("\(i + 1)) \(q.type == 3 ? Edu.blanked(q.text) : q.text)   (\(fmt(q.mark.num)) \(L["mark"]!))", size: 12, bold: true))
                switch q.type {
                case 0: for k in 0..<4 where !q.opts[k].isEmpty { b.add(.para("   \(key && q.ans == k ? "✔" : "○") \(letters[k])) \(q.opts[k])")) }
                case 1: b.add(.para(key ? "   \(L["ans"]!): \(q.ans == 0 ? L["t"]! : L["f"]!)" : "   (     ) \(L["t"]!)          (     ) \(L["f"]!)"))
                case 2: if !key { b.add(.lines(min(max(Int(q.lines.num), 1), 15))) } else if !q.answer.isEmpty { b.add(.para("   \(L["rubric"]!): \(q.answer)")) }
                case 3: if key { b.add(.para("   \(L["ans"]!): \(q.answer)")) }
                default:
                    let ps = Edu.pairs(q.pairs), right = Edu.shuffled(ps.map(\.1), i + 7)
                    b.add(.table(header: [], rows: ps.indices.map { k in ["\(k + 1)) \(ps[k].0)", key ? (right.firstIndex(of: ps[k].1).map { String(letters[min($0, 3)]) } ?? "-") : "(     )", "\(k < 4 ? String(letters[k]) : "-")) \(right[k])"] }))
                }
                b.add(.space(6))
            }
            return try? b.save(to: out.appendingPathComponent(key ? "\(title)-الإجابة.pdf" : "\(title).pdf"))
        }
        func docx() -> URL? {
            var p: [Office.Para] = [.text(title, heading: 1), .text(([school, subject] + info.map { "\($0.0): \($0.1)" }).filter { !$0.isEmpty }.joined(separator: " • ")),
                                    .text("\(L["name"]!): ........................    \(L["score"]!): ...... / \(total)")]
            for (i, q) in qs.enumerated() {
                p.append(.text("\(i + 1)) \(q.type == 3 ? Edu.blanked(q.text) : q.text)", bold: true))
                switch q.type {
                case 0: for k in 0..<4 where !q.opts[k].isEmpty { p.append(.text("    \(letters[k])) \(q.opts[k])")) }
                case 1: p.append(.text("    (     ) \(L["t"]!)        (     ) \(L["f"]!)"))
                case 2: for _ in 0..<min(max(Int(q.lines.num), 1), 15) { p.append(.text("    ..............................................................")) }
                case 4: let ps = Edu.pairs(q.pairs), right = Edu.shuffled(ps.map(\.1), i + 7); p.append(.table(ps.indices.map { k in ["\(k + 1)) \(ps[k].0)", "(     )", "\(k < 4 ? String(letters[k]) : "-")) \(right[k])"] }))
                default: break
                }
            }
            let u = out.appendingPathComponent("\(title).docx"); return (try? Office.writeDocx(u, p)) != nil ? u : nil
        }
        result = [pdf(false), withKey ? pdf(true) : nil, word ? docx() : nil].compactMap { $0 }; store.used(tool.id, title)
    }
}

/// The question bank: classified by subject, grade, lesson and difficulty; imported from Excel/CSV; tests built from it.
struct QuestionBank: View {
    @Binding var qs: [QuizMaker.Q]
    let subject: String, grade: String, lesson: String, level: String
    @EnvironmentObject var store: Store
    @State private var msg: String?; @State private var show = false; @State private var importing = false
    @State private var bank: [Rec] = []; @State private var picked = Set<Int>()
    @State private var fSubject = "الكل"; @State private var fGrade = "الكل"; @State private var fLevel = "الكل"; @State private var search = ""; @State private var random = ""
    var shown: [Int] { bank.indices.filter { i in let b = bank[i]
        return (fSubject == "الكل" || b.s("subject") == fSubject) && (fGrade == "الكل" || b.s("grade") == fGrade) && (fLevel == "الكل" || b.s("level") == fLevel) && (search.isEmpty || b.s("q").contains(search)) } }
    func opts(_ k: String) -> [String] { var seen = Set<String>(); return ["الكل"] + bank.map { $0.s(k) }.filter { !$0.isEmpty && seen.insert($0).inserted } }
    var body: some View {
        Panel(title: "بنك الأسئلة") {
            HStack {
                SecondaryButton(title: "حفظ في البنك", icon: "archivebox") {
                    let old = store.list("qbank"), have = Set(old.map { $0.s("q") })
                    let add: [Rec] = qs.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty && !have.contains($0.text) }
                        .map { var r = $0.rec; r["subject"] = subject; r["grade"] = grade; r["lesson"] = lesson; r["level"] = level; return r }
                    store.saveList("qbank", old + add); msg = "أُضيف \(add.count) سؤالًا إلى البنك (\(old.count + add.count) إجمالًا)"
                }
                SecondaryButton(title: "من البنك", icon: "tray.and.arrow.down") { bank = store.list("qbank"); picked = []; show = true }
            }
            SecondaryButton(title: "استيراد أسئلة من Excel أو CSV", icon: "tablecells") { importing = true }
            if let msg { Text(msg).font(.plex(.caption)).foregroundStyle(Brand.mint) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .data, .commaSeparatedText, .plainText]) { r in
            guard case .success(let u) = r else { return }
            let ok = u.startAccessingSecurityScopedResource(); defer { if ok { u.stopAccessingSecurityScopedResource() } }
            let rows: [[String]] = u.pathExtension.lowercased() == "xlsx" ? ((try? Office.readXlsx(u))?.first?.1 ?? [])
                : ((try? String(contentsOf: u, encoding: .utf8)) ?? "").components(separatedBy: .newlines).map { $0.split(omittingEmptySubsequences: false, whereSeparator: { ",;\t".contains($0) }).map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) } }
            let add = Edu.importRows(rows)
            if add.isEmpty { msg = "تعذّرت قراءة الملف. استخدم Excel أو CSV بالأعمدة: السؤال، النوع، أ، ب، ج، د، الإجابة، الدرجة، المادة، الصف، الدرس، الصعوبة."; return }
            let old = store.list("qbank"), have = Set(old.map { $0.s("q") }); let fresh = add.filter { !have.contains($0.s("q")) }
            store.saveList("qbank", old + fresh); msg = "استُورد \(fresh.count) سؤالًا إلى البنك"
        }
        .sheet(isPresented: $show) {
            NavigationStack {
                List {
                    if bank.isEmpty { Text("البنك فارغ. احفظ أسئلة اختبار أو استوردها من Excel لتعيد استخدامها لاحقًا.") }
                    else {
                        Section {
                            TextField("بحث في الأسئلة", text: $search)
                            Picker("المادة", selection: $fSubject) { ForEach(opts("subject"), id: \.self) { Text($0) } }
                            Picker("الصف", selection: $fGrade) { ForEach(opts("grade"), id: \.self) { Text($0) } }
                            Picker("الصعوبة", selection: $fLevel) { ForEach(["الكل"] + Edu.levels, id: \.self) { Text($0) } }
                            HStack { TextField("عدد عشوائي", text: $random).keyboardType(.numberPad); Button("اختر") { picked = Set(shown.shuffled().prefix(max(0, Int(random) ?? 0))) } }
                        }
                        Section {
                            ForEach(shown, id: \.self) { i in
                                Button { if picked.contains(i) { picked.remove(i) } else { picked.insert(i) } } label: {
                                    let b = bank[i], tags = [b.s("subject"), b.s("grade"), b.s("level")].filter { !$0.isEmpty }.joined(separator: " • ")
                                    Label(b.s("q") + (tags.isEmpty ? "" : " — \(tags)"), systemImage: picked.contains(i) ? "checkmark.circle.fill" : "circle")
                                }.foregroundStyle(Brand.text1)
                            }
                            .onDelete { idx in let ids = idx.map { shown[$0] }; bank = bank.enumerated().filter { !ids.contains($0.offset) }.map(\.element); store.saveList("qbank", bank); picked = [] }
                        }
                    }
                }
                .navigationTitle("بنك الأسئلة (\(shown.count) من \(bank.count))").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { show = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("إضافة \(picked.count)") { qs += picked.sorted().map { QuizMaker.Q(bank[$0]) }; show = false }.disabled(picked.isEmpty) }
                }
            }
        }
    }
}

/// Teaching-strategy templates: each section is a heading, a prompt, and answer space (lines or a table).
enum Strategies {
    struct Sec { var head: String; var prompt = ""; var lines = 3; var table: [String] = []; var rows = 0 }
    struct T { var name: String; var about: String; var sections: [Sec]; var perPage = 1 }
    static let all: [T] = [
        T(name: "ورقة عمل حرة", about: "اكتب أنشطتك سطرًا سطرًا", sections: []),
        T(name: "مستويات بلوم", about: "أسئلة متدرجة من التذكر إلى الإبداع", sections: [Sec(head: "تذكّر", prompt: "عرّف أو اذكر…"), Sec(head: "افهم", prompt: "اشرح بأسلوبك…"), Sec(head: "طبّق", prompt: "استخدم ما تعلمته في…"), Sec(head: "حلّل", prompt: "قارن أو صنّف…"), Sec(head: "قيّم", prompt: "ما رأيك ولماذا؟"), Sec(head: "ابتكر", prompt: "صمّم أو اقترح…")]),
        T(name: "فكّر، زاوج، شارك", about: "تفكير فردي ثم نقاش ثنائي ثم مشاركة", sections: [Sec(head: "فكّر بمفردك (دقيقتان)", prompt: "اكتب إجابتك الأولية"), Sec(head: "زاوج مع زميلك (3 دقائق)", prompt: "ما الذي أضافه زميلك؟"), Sec(head: "شارك الصف", prompt: "الفكرة التي سنعرضها", lines: 2)]),
        T(name: "الخبراء (Jigsaw)", about: "كل مجموعة تتقن جزءًا ثم تعلّمه للآخرين", sections: [Sec(head: "جزئي في مجموعة الخبراء", prompt: "الجزء: ............  أهم ثلاث أفكار", lines: 4), Sec(head: "ما تعلمته من زملائي في المجموعة الأم", table: ["الجزء", "الفكرة الرئيسة", "مثال"], rows: 4)]),
        T(name: "القبعات الست", about: "التفكير في الموضوع من ست زوايا", sections: [Sec(head: "القبعة البيضاء: الحقائق", prompt: "ما المعلومات المتوفرة؟", lines: 2), Sec(head: "القبعة الحمراء: المشاعر", prompt: "بماذا تشعر تجاه الموضوع؟", lines: 2), Sec(head: "القبعة السوداء: المخاطر", prompt: "ما السلبيات أو العقبات؟", lines: 2), Sec(head: "القبعة الصفراء: الإيجابيات", prompt: "ما الفوائد؟", lines: 2), Sec(head: "القبعة الخضراء: الأفكار الجديدة", prompt: "ما البدائل والحلول المبتكرة؟", lines: 2), Sec(head: "القبعة الزرقاء: التنظيم", prompt: "ما الخلاصة والخطوة التالية؟", lines: 2)]),
        T(name: "التعلم التعاوني", about: "أدوار واضحة لكل عضو ومهمة مشتركة", sections: [Sec(head: "أدوار المجموعة", table: ["الدور", "الاسم"]), Sec(head: "المهمة", prompt: "ما المطلوب من المجموعة؟"), Sec(head: "ناتج المجموعة", lines: 5), Sec(head: "تقييم العمل الجماعي", prompt: "ما الذي نجح؟ وما الذي نحسّنه؟", lines: 2)]),
        T(name: "التعلم القائم على حل المشكلات", about: "من تحديد المشكلة إلى تقييم الحل", sections: [Sec(head: "المشكلة", prompt: "صف المشكلة بجملة واحدة", lines: 2), Sec(head: "ماذا نعرف؟"), Sec(head: "ماذا نحتاج أن نعرف؟"), Sec(head: "الحلول المقترحة", table: ["الحل", "المزايا", "العيوب"], rows: 3), Sec(head: "الحل المختار ولماذا"), Sec(head: "كيف سنعرف أنه نجح؟", lines: 2)]),
        T(name: "المحطات التعليمية", about: "مهام قصيرة يتنقل الطلاب بينها", sections: (1...4).map { Sec(head: "المحطة \($0)", prompt: "المهمة: ............  الزمن: ..... دقائق") }),
        T(name: "بطاقات الخروج (3-2-1)", about: "ثلاث بطاقات قصيرة في الصفحة تُجمع آخر الحصة", sections: [Sec(head: "3 أشياء تعلمتها اليوم"), Sec(head: "2 سؤالان ما زالا لديّ", lines: 2), Sec(head: "1 كيف سأطبّق ما تعلمته", lines: 1)], perPage: 3),
        T(name: "الاستبيان القبلي والبعدي", about: "قبل الدرس وبعده لقياس التعلم", sections: [Sec(head: "قبل الدرس: ماذا أعرف؟"), Sec(head: "ماذا أريد أن أعرف؟", lines: 2), Sec(head: "بعد الدرس: ماذا تعلمت؟"), Sec(head: "قيّم فهمك", table: ["العبارة", "قبل (1-5)", "بعد (1-5)"], rows: 4)]),
        T(name: "خطة علاجية", about: "لطلاب يحتاجون دعمًا في مهارة محددة", sections: [Sec(head: "المهارة المستهدفة", lines: 1), Sec(head: "خطة الدعم", table: ["الطالب", "مستواه الحالي", "الإجراء العلاجي", "الموعد", "النتيجة"], rows: 6)]),
        T(name: "خطة إثرائية", about: "لطلاب متقدمين يحتاجون تحديًا أكبر", sections: [Sec(head: "الهدف الإثرائي", lines: 2), Sec(head: "الأنشطة", table: ["الطالب", "النشاط الإثرائي", "المصدر", "موعد التسليم"], rows: 5)]),
        T(name: "خطة دراسية أسبوعية", about: "توزيع المذاكرة على أيام الأسبوع", sections: [Sec(head: "الأهداف هذا الأسبوع"), Sec(head: "الجدول", table: ["اليوم", "المادة", "ما سأذاكره", "المدة", "تم"], rows: 7)]),
    ]
}

struct WorksheetTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var kind = 0; @State var title = "ورقة عمل"; @State var subject = ""; @State var goal = ""; @State var minutes = ""; @State var topic = ""
    @State var bodyText = "1) \n2) \n3) "; @State var lines = "3"; @State var word = true; @State var result: [URL] = []
    var body: some View {
        let tpl = Strategies.all[kind]
        ToolScreen(tool: tool) {
            Panel(title: "الاستراتيجية") {
                Picker("القالب", selection: Binding(get: { kind }, set: { v in kind = v; if title == "ورقة عمل" || Strategies.all.contains(where: { $0.name == title }) { title = v == 0 ? "ورقة عمل" : Strategies.all[v].name } })) {
                    ForEach(Strategies.all.indices, id: \.self) { Text(Strategies.all[$0].name).tag($0) }
                }.accessibilityIdentifier("template")
                Hint(text: tpl.about)
            }
            Panel {
                Field(label: "العنوان", text: $title); Field(label: "المادة والصف", text: $subject); Field(label: "الهدف من الدرس", text: $goal)
                if kind != 0 { Field(label: "الموضوع أو السؤال المحوري", text: $topic) }
                NumField(label: "مدة النشاط", text: $minutes, suffix: "دقيقة")
                if kind == 0 { Field(label: "الأنشطة/الأسئلة (سطر لكل سؤال)", text: $bodyText, lines: 6); NumField(label: "أسطر إجابة بعد كل سؤال", text: $lines) }
                else { ForEach(tpl.sections.indices, id: \.self) { i in Text("• \(tpl.sections[i].head)\(tpl.sections[i].prompt.isEmpty ? "" : ": \(tpl.sections[i].prompt)")").font(.plex(.footnote)) } }
            }
            Toggle("ملف Word قابل للتعديل أيضًا", isOn: $word).font(.plex(.subheadline))
            TemplatePanel()
            PrimaryButton(title: "إنشاء PDF", icon: "doc.richtext") { build(tpl) }.accessibilityIdentifier("action")
            if !result.isEmpty { ResultFiles(files: result) }
        }
        .onAppear { let p = Assistant.takePrefill(); let sg = [p.s("subject"), p.s("grade")].filter { !$0.isEmpty }.joined(separator: " — "); if !sg.isEmpty { subject = sg } }
    }
    @MainActor private func build(_ tpl: Strategies.T) {
        let b = Templates.apply(DocBuilder()); var doc: [Office.Para] = []
        let sub = [subject, minutes.isEmpty ? "" : "\(minutes) دقيقة"].filter { !$0.isEmpty }.joined(separator: " • ")
        let dots = ".............................................................."
        for copy in 0..<tpl.perPage {
            let first = copy == 0
            if !first { b.add(.space(18)) }
            b.add(.title(title, sub: sub)); if first { doc.append(.text(title, heading: 1)); if !sub.isEmpty { doc.append(.text(sub)) } }
            b.add(.keyValues([("الاسم", "................................."), ("التاريخ", "....../....../........")])); if first { doc.append(.text("الاسم: .......................     التاريخ: ....../....../........")) }
            if first && !goal.isEmpty { b.add(.heading("الهدف")); b.add(.para(goal)); doc += [.text("الهدف", heading: 2), .text(goal)] }
            if !topic.isEmpty { b.add(.para(topic, size: 13, bold: true)); if first { doc.append(.text(topic, bold: true)) } }
            if kind == 0 {
                b.add(.heading("الأنشطة")); if first { doc.append(.text("الأنشطة", heading: 2)) }
                let n = min(max(Int(lines.num), 0), 12)
                for l in bodyText.components(separatedBy: "\n") where !l.trimmingCharacters(in: .whitespaces).isEmpty {
                    b.add(.para(l, size: 12)); b.add(.lines(n)); b.add(.space(6)); if first { doc.append(.text(l)); doc += Array(repeating: .text(dots), count: n) }
                }
            } else {
                for s in tpl.sections {
                    b.add(.heading(s.head)); if first { doc.append(.text(s.head, heading: 2)) }
                    if !s.prompt.isEmpty { b.add(.para(s.prompt, size: 11, color: DocBuilder.muted)); if first { doc.append(.text(s.prompt)) } }
                    if !s.table.isEmpty {
                        let rows = s.head == "أدوار المجموعة" ? ["القائد", "المقرر", "الموقّت", "المتحدث"].map { [$0, ""] } : Array(repeating: Array(repeating: "", count: s.table.count), count: s.rows)
                        b.add(.table(header: s.table, rows: rows)); if first { doc.append(.table([s.table] + rows.map { $0.map { $0.isEmpty ? " " : $0 } })) }
                    } else { b.add(.lines(s.lines)); if first { doc += Array(repeating: .text(dots), count: s.lines) } }
                }
            }
        }
        let out = FilesX.outDir()
        var files: [URL] = []
        if let p = try? b.save(to: out.appendingPathComponent("\(title).pdf")) { files.append(p) }
        if word { let u = out.appendingPathComponent("\(title).docx"); if (try? Office.writeDocx(u, doc)) != nil { files.append(u) } }
        result = files; store.used(tool.id, title)
    }
}
