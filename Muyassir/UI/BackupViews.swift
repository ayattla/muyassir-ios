import SwiftUI
import UniformTypeIdentifiers

/// The encrypted backup file. Exported through the system "Save to Files" sheet: the app never uploads it.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupSection: View {
    @ObservedObject private var plus = Plus.shared
    @State private var mode: String?            // "export" | "restore"
    @State private var pass = ""; @State private var pass2 = ""
    @State private var exportDoc: BackupFile?; @State private var exporting = false
    @State private var importing = false; @State private var pending: Data?
    @State private var msg: String?; @State private var busy = false
    var body: some View {
        Section {
            HStack { Button { if plus.allow(.backup) { msg = nil; mode = "export" } } label: { Label("إنشاء نسخة احتياطية", systemImage: "externaldrive.badge.plus") }.accessibilityIdentifier("backupExport"); Spacer(); PlusBadge() }
            Button { if plus.allow(.backup) { msg = nil; importing = true } } label: { Label("استعادة من نسخة", systemImage: "arrow.counterclockwise") }.accessibilityIdentifier("backupRestore")
            if busy { ProgressView() }
            if let msg { Text(msg).foregroundStyle(Brand.text1).font(.plex(.footnote)) }
        } header: { Text("النسخ الاحتياطي المشفر") } footer: {
            Text("احفظ ملاحظاتك ووثائقك ومصاريفك وجداولك في ملف مشفر بكلمة مرور، وضعه حيث تريد: الملفات أو iCloud Drive أو غيرهما. التطبيق لا يرفع شيئا بنفسه.")
        }
        .sheet(isPresented: Binding(get: { mode != nil }, set: { if !$0 { mode = nil; pass = ""; pass2 = "" } })) {
            NavigationStack {
                Form {
                    Section {
                        SecureField("كلمة المرور", text: $pass).accessibilityIdentifier("backupPass")
                        if mode == "export" { SecureField("تأكيد كلمة المرور", text: $pass2).accessibilityIdentifier("backupPass2") }
                    } footer: {
                        Text(mode == "export" ? "8 أحرف على الأقل. لا نستطيع استعادتها إن نسيتها." : "ستستبدل بياناتك الحالية ببيانات النسخة.")
                    }
                }
                .navigationTitle(mode == "export" ? "كلمة مرور النسخة" : "كلمة مرور النسخة المحفوظة").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { mode = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(mode == "export" ? "متابعة" : "استعادة") { confirm() }
                            .disabled(mode == "export" ? (pass.count < 8 || pass != pass2) : pass.isEmpty).accessibilityIdentifier("backupConfirm")
                    }
                }
            }.presentationDetents([.medium])
        }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .data, defaultFilename: "ميسر-نسخة-\(Self.stamp()).mysb") { r in
            if case .success = r { msg = "حفظت النسخة المشفرة. احتفظ بكلمة المرور، لا يمكن استرجاعها." }
            exportDoc = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { r in
            guard case .success(let u) = r else { return }
            let ok = u.startAccessingSecurityScopedResource(); defer { if ok { u.stopAccessingSecurityScopedResource() } }
            if let d = try? Data(contentsOf: u) { pending = d; mode = "restore" } else { msg = "تعذرت قراءة الملف" }
        }
    }
    private static func stamp() -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f.string(from: Date()) }
    private func confirm() {
        let p = pass, m = mode, d = pending; mode = nil; pass = ""; pass2 = ""; busy = true
        Task.detached {
            if m == "export" {
                let r = Result { try Backup.encrypt(Backup.pack(Backup.dataDir), password: p) }
                await MainActor.run { busy = false; switch r { case .success(let data): exportDoc = BackupFile(data: data); exporting = true; case .failure(let e): msg = "تعذر الحفظ: \(e.localizedDescription)" } }
            } else if let d {
                let r = Result { try Backup.restore(password: p, from: d) }
                await MainActor.run {
                    busy = false; pending = nil
                    switch r { case .success: msg = "استعيدت بياناتك. أغلق ميسر تماما من مبدل التطبيقات ثم افتحه لتظهر."; case .failure(let e): msg = e.localizedDescription }
                }
            }
        }
    }
}
