import SwiftUI

/// «مشاريعي»: named groups of kept result files and the tools used, on the device, to come back to earlier work.
enum Projects {
    static func all() -> [Rec] { Store.shared.list("projects") }
    private static func save(_ l: [Rec]) { Store.shared.saveList("projects", l) }
    @discardableResult static func create(_ name: String) -> Rec {
        let p: Rec = ["id": Date().timeIntervalSince1970 * 1000, "name": name.trimmingCharacters(in: .whitespaces), "files": [String](), "tools": [String]()]
        save(all() + [p]); return p
    }
    static func remove(_ id: Double) { save(all().filter { $0.d("id") != id }) }
    static func files(_ p: Rec) -> [URL] { ((p["files"] as? [String]) ?? []).map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) } }
    static func tools(_ p: Rec) -> [String] { (p["tools"] as? [String]) ?? [] }
    /// Keeps the file (no 24-hour clean-up) and records it in the project.
    static func add(_ id: Double, _ u: URL) {
        let kept = FilesX.isKept(u) ? u : (FilesX.keep(u) ?? u)
        save(all().map { p in
            guard p.d("id") == id else { return p }
            var q = p; var fs = files(p).map(\.path); if !fs.contains(kept.path) { fs.append(kept.path) }
            q["files"] = fs; q["updated"] = Date().timeIntervalSince1970; return q
        })
    }
    static func detach(_ id: Double, _ u: URL) { save(all().map { p in guard p.d("id") == id else { return p }; var q = p; q["files"] = files(p).map(\.path).filter { $0 != u.path }; return q }) }
}

struct ProjectsSection: View {
    @Binding var version: Int
    @State private var opened: Double?
    @State private var newName = ""; @State private var creating = false
    @State private var share: [URL] = []; @State private var sharing = false
    var body: some View {
        let _ = version
        let list = Projects.all()
        Button { creating = true } label: { Label("مشروع جديد", systemImage: "folder.badge.plus").frame(maxWidth: .infinity) }.accessibilityIdentifier("projectNew")
        if list.isEmpty { ContentUnavailableView("لا توجد مشاريع بعد", systemImage: "folder", description: Text("اجمع ملفات عمل واحد (تقرير، اختبار، معاملة) في مشروع لتعود إليه وتكمله. أضف أي ملف من تبويب «الملفات» بالسحب عليه.")) }
        ForEach(list.indices, id: \.self) { i in
            let p = list[i], id = p.d("id"), fs = Projects.files(p)
            DisclosureGroup(isExpanded: Binding(get: { opened == id }, set: { opened = $0 ? id : nil })) {
                ForEach(fs, id: \.self) { u in
                    HStack { Text(u.lastPathComponent).font(.plex(.footnote)).lineLimit(1); Spacer()
                        Button { share = [u]; sharing = true } label: { Image(systemName: "square.and.arrow.up") }.buttonStyle(.borderless)
                        Button { Projects.detach(id, u); version += 1 } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("إزالة من المشروع")
                    }
                }
                HStack {
                    if !fs.isEmpty { Button("مشاركة الكل") { share = fs; sharing = true }.buttonStyle(.bordered) }
                    Button("حذف المشروع", role: .destructive) { Projects.remove(id); version += 1 }.buttonStyle(.bordered)
                }
            } label: { Label("\(p.s("name")) • \(fs.count) ملف", systemImage: "folder.fill") }
        }
        Color.clear.frame(height: 0)
            .alert("مشروع جديد", isPresented: $creating) {
                TextField("اسم المشروع", text: $newName)
                Button("إنشاء") { if !newName.isEmpty { Projects.create(newName); newName = ""; version += 1 } }
                Button("إلغاء", role: .cancel) {}
            }
            .sheet(isPresented: $sharing) { ShareSheet(items: share) }
    }
}
