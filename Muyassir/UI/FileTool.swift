import SwiftUI
import UniformTypeIdentifiers
import QuickLook

final class Progress: ObservableObject {
    @Published var value: Double = -1
    @Published var label = ""
    /// Safe to call from background work.
    func update(_ i: Int, _ n: Int, _ text: String = "") { DispatchQueue.main.async { self.value = n > 0 ? Double(i) / Double(n) : -1; if !text.isEmpty { self.label = text } } }
    func say(_ text: String) { DispatchQueue.main.async { self.label = text } }
}

/// Generic "pick files → options → run → results" screen used by conversion, PDF, image and ZIP tools.
struct FileTool<Options: View, After: View>: View {
    let tool: Tool
    let types: [UTType]
    var multiple = false
    let pickLabel: String
    let actionLabel: String
    var reorderable = false
    var validate: ([URL]) -> String? = { $0.isEmpty ? "اختر ملفًا أولًا" : nil }
    @ViewBuilder var options: ([URL]) -> Options
    @ViewBuilder var after: () -> After
    let run: ([URL], URL, Progress) async throws -> [URL]

    init(tool: Tool, types: [UTType], multiple: Bool = false, pickLabel: String, actionLabel: String, reorderable: Bool = false,
         validate: @escaping ([URL]) -> String? = { $0.isEmpty ? "اختر ملفًا أولًا" : nil },
         @ViewBuilder options: @escaping ([URL]) -> Options, @ViewBuilder after: @escaping () -> After,
         run: @escaping ([URL], URL, Progress) async throws -> [URL]) {
        self.tool = tool; self.types = types; self.multiple = multiple; self.pickLabel = pickLabel; self.actionLabel = actionLabel
        self.reorderable = reorderable; self.validate = validate; self.options = options; self.after = after; self.run = run
    }

    @EnvironmentObject var store: Store
    @State private var inputs: [URL] = []
    @State private var results: [URL] = []
    @State private var busy = false
    @State private var error: String?
    @State private var picking = false
    @StateObject private var progress = Progress()

    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Button { picking = true } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 30)).foregroundStyle(Brand.lapis)
                        Text(pickLabel).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.lapis)
                        Text("تتم المعالجة على جهازك ولا تُرفع ملفاتك").font(.plex(.caption)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 24).background(Brand.lapis.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
                ForEach(Array(inputs.enumerated()), id: \.element) { i, u in
                    HStack {
                        Image(systemName: "doc").foregroundStyle(.secondary)
                        VStack(alignment: .leading) { Text(u.lastPathComponent).font(.plex(.subheadline)).lineLimit(1); Text(FilesX.human(FilesX.size(u))).font(.plex(.caption)).foregroundStyle(.secondary) }
                        Spacer()
                        if reorderable && inputs.count > 1 {
                            Button { inputs.swapAt(i, i - 1) } label: { Image(systemName: "chevron.up") }.disabled(i == 0).accessibilityLabel("أعلى")
                            Button { inputs.swapAt(i, i + 1) } label: { Image(systemName: "chevron.down") }.disabled(i == inputs.count - 1).accessibilityLabel("أسفل")
                        }
                        Button { inputs.remove(at: i); results = [] } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.accessibilityLabel("إزالة")
                    }.buttonStyle(.borderless)
                }
            }
            if !inputs.isEmpty { options(inputs) }
            if let error { Text(error).font(.plex(.subheadline)).foregroundStyle(.red).accessibilityIdentifier("error") }
            if busy {
                Panel {
                    Text(progress.label.isEmpty ? "جارٍ المعالجة…" : progress.label).font(.plex(.subheadline))
                    if progress.value >= 0 { ProgressView(value: progress.value) } else { ProgressView().frame(maxWidth: .infinity) }
                }
            } else {
                PrimaryButton(title: actionLabel, icon: "bolt.fill", enabled: !inputs.isEmpty) { start() }.accessibilityIdentifier("action")
            }
            if !results.isEmpty { ResultFiles(files: results) }
            after()
        }
        .task {
            #if DEBUG
            if inputs.isEmpty, let spec = ProcessInfo.processInfo.environment["MYS_TEST_INPUTS"] { inputs = TestInputs.make(spec) }
            #endif
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: types, allowsMultipleSelection: multiple) { r in
            guard case let .success(urls) = r else { return }
            Task {
                let copied = urls.compactMap { try? FilesX.toTemp($0) }
                if multiple { inputs += copied } else { inputs = Array(copied.prefix(1)) }
                results = []
            }
        }
    }

    private func start() {
        error = validate(inputs); guard error == nil else { return }
        busy = true; progress.value = -1; progress.label = ""
        let ins = inputs
        Task {
            do {
                let out = FilesX.outDir()
                results = try await Task.detached(priority: .userInitiated) { try await run(ins, out, progress) }.value
                store.used(tool.id, results.first?.lastPathComponent ?? "")
            } catch { self.error = friendly(error) }
            busy = false
        }
    }
}

extension FileTool where After == EmptyView {
    init(tool: Tool, types: [UTType], multiple: Bool = false, pickLabel: String, actionLabel: String, reorderable: Bool = false,
         validate: @escaping ([URL]) -> String? = { $0.isEmpty ? "اختر ملفًا أولًا" : nil },
         @ViewBuilder options: @escaping ([URL]) -> Options, run: @escaping ([URL], URL, Progress) async throws -> [URL]) {
        self.init(tool: tool, types: types, multiple: multiple, pickLabel: pickLabel, actionLabel: actionLabel, reorderable: reorderable, validate: validate, options: options, after: { EmptyView() }, run: run)
    }
}

extension FileTool where After == EmptyView, Options == EmptyView {
    init(tool: Tool, types: [UTType], multiple: Bool = false, pickLabel: String, actionLabel: String, reorderable: Bool = false,
         validate: @escaping ([URL]) -> String? = { $0.isEmpty ? "اختر ملفًا أولًا" : nil }, run: @escaping ([URL], URL, Progress) async throws -> [URL]) {
        self.init(tool: tool, types: types, multiple: multiple, pickLabel: pickLabel, actionLabel: actionLabel, reorderable: reorderable, validate: validate, options: { _ in EmptyView() }, after: { EmptyView() }, run: run)
    }
}

func friendly(_ e: Error) -> String {
    let m = e.localizedDescription
    if m.unicodeScalars.contains(where: { (0x0600...0x06FF).contains($0.value) }) { return m }
    return "تعذّرت المعالجة: تأكد أن الملف سليم ومن النوع الصحيح."
}

struct UserError: LocalizedError { let message: String; init(_ m: String) { message = m }; var errorDescription: String? { message } }

struct ResultFiles: View {
    let files: [URL]
    @State private var sharing = false
    @State private var exporting = false
    @State private var preview: URL?
    @State private var exportCopies: [URL] = []
    var body: some View {
        Panel(title: "الناتج (\(files.count))") {
            ForEach(files.prefix(60), id: \.self) { f in
                Button { preview = f } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.mint)
                        VStack(alignment: .leading) { Text(f.lastPathComponent).font(.plex(.subheadline)).lineLimit(1); Text(FilesX.human(FilesX.size(f))).font(.plex(.caption)).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "eye").foregroundStyle(Brand.lapis)
                    }
                }.buttonStyle(.plain)
            }
            if files.count > 60 { Text("و\(files.count - 60) ملفًا آخر").font(.plex(.caption)) }
            HStack {
                SecondaryButton(title: "مشاركة", icon: "square.and.arrow.up") { sharing = true }
                SecondaryButton(title: "حفظ في الملفات", icon: "folder") { exportCopies = files.map { copy($0) }; exporting = true }
            }
            Text("تجدها أيضًا في تطبيق «الملفات» ← على الـiPhone ← مُيسّر.").font(.plex(.caption)).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $sharing) { ShareSheet(items: files) }
        .fileMover(isPresented: $exporting, files: exportCopies) { _ in }
        .quickLookPreview($preview, in: files)
    }

    /// fileMover moves files; hand it copies so the originals stay available in the app.
    private func copy(_ u: URL) -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("export/\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let c = d.appendingPathComponent(u.lastPathComponent); try? FileManager.default.copyItem(at: u, to: c); return c
    }
}
