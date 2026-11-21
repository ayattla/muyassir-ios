import SwiftUI
import UniformTypeIdentifiers

/// Teacher pack: grade sheet, sharing the student list with attendance.
struct GradesTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var students: [String] = []
    @State var items: [Rec] = []          // ["name", "max"]
    @State var marks: Rec = [:]           // "student|item" -> String
    @State var newName = ""; @State var itemName = ""; @State var itemMax = ""; @State var sel = 0
    @State var files: [URL] = []
    var total: Double { items.reduce(0) { $0 + $1.d("max") } }
    func score(_ s: String, _ i: String) -> Double? { Double(marks["\(s)|\(i)"] as? String ?? "") }
    func sum(_ s: String) -> Double { items.reduce(0) { $0 + (score(s, $1.s("name")) ?? 0) } }
    var body: some View {
        ToolScreen(tool: tool) {
            Panel(title: "الطلاب (\(students.count))") {
                HStack {
                    Field(label: "اسم الطالب أو عدة أسماء بفاصلة", text: $newName)
                    Button { addNames() } label: { Image(systemName: "person.badge.plus").font(.title3) }.accessibilityLabel("إضافة").accessibilityIdentifier("addStudent")
                }
                Hint(text: "نفس قائمة الطلاب في أداة متابعة الحضور.")
            }
            Panel(title: "التقييمات (المجموع \(fmt(total, 1)))") {
                ForEach(items.indices, id: \.self) { i in LabelValue(label: items[i].s("name"), value: "من \(fmt(items[i].d("max"), 1))") }
                HStack { Field(label: "اسم التقييم (اختبار 1، مشاركة…)", text: $itemName); NumField(label: "الدرجة العظمى", text: $itemMax).frame(width: 130) }
                SecondaryButton(title: "إضافة التقييم", icon: "plus") {
                    let n = itemName.trimmingCharacters(in: .whitespaces)
                    guard let m = Double(itemMax), !n.isEmpty, !items.contains(where: { $0.s("name") == n }) else { return }
                    items.append(["name": n, "max": m]); store.saveList("grade_items", items); itemName = ""; itemMax = ""
                }.accessibilityIdentifier("addItem")
            }
            if !students.isEmpty && !items.isEmpty {
                let k = min(sel, items.count - 1), iname = items[k].s("name"), mx = items[k].d("max")
                Panel(title: "رصد الدرجات") {
                    ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(items.indices, id: \.self) { i in Chip(text: items[i].s("name"), selected: i == k) { sel = i } } } }
                    ForEach(students, id: \.self) { s in
                        HStack {
                            Text(s).font(.plex(.subheadline)); Spacer()
                            NumField(label: "من \(fmt(mx, 1))", text: Binding(get: { marks["\(s)|\(iname)"] as? String ?? "" }, set: { v in
                                var c = v; if let d = Double(v), d > mx { c = fmt(mx, 1) }
                                marks["\(s)|\(iname)"] = c; store.saveObj("grades", marks)
                            })).frame(width: 120)
                        }
                    }
                }
                Panel(title: "النتائج") {
                    ForEach(students.sorted { sum($0) > sum($1) }, id: \.self) { s in
                        LabelValue(label: s, value: "\(fmt(sum(s), 1)) / \(fmt(total, 1)) • \(total > 0 ? fmt(100 * sum(s) / total, 0) : "0")%")
                    }
                    Hint(text: "متوسط الصف \(fmt(students.map(sum).reduce(0, +) / Double(students.count), 1)) من \(fmt(total, 1))")
                    SecondaryButton(title: "تصدير Excel وPDF", icon: "tablecells") { export() }.accessibilityIdentifier("exportGrades")
                }
            }
            if !files.isEmpty { ResultFiles(files: files) }
        }
        .onAppear { students = store.list("students").map { $0.s("name") }; items = store.list("grade_items"); marks = store.obj("grades") }
    }
    private func addNames() {
        let names = newName.split(whereSeparator: { $0 == "," || $0 == "،" || $0 == "\n" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !students.contains($0) }
        guard !names.isEmpty else { return }
        students += names; newName = ""; store.saveList("students", students.map { ["name": $0] })
    }
    private func export() {
        guard Plus.shared.allow(.export) else { return }
        let header = ["الطالب"] + items.map { "\($0.s("name")) (\(fmt($0.d("max"), 1)))" } + ["المجموع", "النسبة"]
        let rows = students.map { s in [s] + items.map { i in score(s, i.s("name")).map { fmt($0, 1) } ?? "-" } + [fmt(sum(s), 1), total > 0 ? "\(fmt(100 * sum(s) / total, 0))%" : "-"] }
        let dir = FilesX.outDir(), u = dir.appendingPathComponent("كشف-الدرجات.xlsx")
        try? Office.writeXlsx(u, [("الدرجات", [header] + rows)])
        files = [u, exportTablePdf("كشف الدرجات", header: header, rows: rows, dir: dir)].compactMap { $0 }; store.used(tool.id)
    }
}

/// Reads a list of names from Excel, CSV or text (first column, header row skipped).
func readNames(_ url: URL) -> [String] {
    let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
    let raw: [String]
    if url.pathExtension.lowercased() == "xlsx" { raw = ((try? Office.readXlsx(url))?.first?.1 ?? []).map { $0.first ?? "" } }
    else { raw = ((try? String(contentsOf: url, encoding: .utf8)) ?? "").components(separatedBy: .newlines).map { String($0.split(whereSeparator: { ",;\t".contains($0) }).first ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) } }
    return raw.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !["الاسم", "name", "Name", "الطالب"].contains($0) }
}
