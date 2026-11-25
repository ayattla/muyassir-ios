import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import QuickLookThumbnailing

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
    var validate: ([URL]) -> String? = { $0.isEmpty ? "اختر ملفا أولا" : nil }
    @ViewBuilder var options: ([URL]) -> Options
    @ViewBuilder var after: () -> After
    let run: ([URL], URL, Progress) async throws -> [URL]

    init(tool: Tool, types: [UTType], multiple: Bool = false, pickLabel: String, actionLabel: String, reorderable: Bool = false,
         validate: @escaping ([URL]) -> String? = { $0.isEmpty ? "اختر ملفا أولا" : nil },
         @ViewBuilder options: @escaping ([URL]) -> Options, @ViewBuilder after: @escaping () -> After,
         run: @escaping ([URL], URL, Progress) async throws -> [URL]) {
        self.tool = tool; self.types = types; self.multiple = multiple; self.pickLabel = pickLabel; self.actionLabel = actionLabel
        self.reorderable = reorderable; self.validate = validate; self.options = options; self.after = after; self.run = run
    }

    @EnvironmentObject var store: Store
    @ObservedObject private var plus = Plus.shared
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
                        Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 24, weight: .semibold)).foregroundStyle(Brand.accent)
                            .frame(width: 52, height: 52).background(Brand.surface, in: RoundedRectangle(cornerRadius: 16))
                        Text(inputs.isEmpty ? pickLabel : (multiple ? "إضافة ملفات أخرى" : "تغيير الملف")).font(.plex(.subheadline, .semibold)).foregroundStyle(Brand.accent)
                        Text(multiple ? "يمكنك اختيار عدة ملفات دفعة واحدة" : "اختر ملفا من جهازك أو من iCloud").font(.plex(.caption)).foregroundStyle(Brand.text2)
                        Label("تتم المعالجة على جهازك ولا ترفع ملفاتك", systemImage: "lock.fill").font(.plex(.caption2)).foregroundStyle(Brand.text3)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .background(Brand.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.l))
                    .overlay(RoundedRectangle(cornerRadius: Radius.l).strokeBorder(Brand.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])))
                }.buttonStyle(PressStyle())
                // iPad split view / Stage Manager: files can be dragged in from another app.
                .dropDestination(for: URL.self) { urls, _ in
                    let copied = urls.compactMap { try? FilesX.toTemp($0) }
                    guard !copied.isEmpty else { return false }
                    if multiple { inputs += copied } else { inputs = Array(copied.prefix(1)) }
                    results = []; return true
                }
                if Plus.isMetered(tool.id) && !plus.unlocked {
                    HStack(spacing: 6) {
                        Text(plus.opsLeft > 0 ? "متبق لك اليوم \(plus.opsLeft) من \(Plus.freeOpsPerDay) عمليات مجانية" : "انتهت عملياتك المجانية لليوم").font(.plex(.caption, .semibold)).foregroundStyle(Brand.text2)
                        Button("بلا حدود مع بلس") { plus.paywall = .menu }.font(.plex(.caption, .semibold))
                    }.frame(maxWidth: .infinity).accessibilityElement(children: .combine).accessibilityIdentifier("opsLeft")
                }
                if !inputs.isEmpty { Text("\(inputs.count) \(inputs.count == 1 ? "ملف" : "ملفات") جاهزة").font(.plex(.caption, .semibold)).foregroundStyle(Brand.text2).frame(maxWidth: .infinity) }
                ForEach(Array(inputs.enumerated()), id: \.element) { i, u in
                    HStack {
                        Thumb(url: u)
                        VStack(alignment: .leading) { Text(u.lastPathComponent).font(.plex(.subheadline)).foregroundStyle(Brand.text1).lineLimit(1); Text(FilesX.human(FilesX.size(u))).font(.plex(.caption)).foregroundStyle(Brand.text3) }
                        Spacer()
                        if reorderable && inputs.count > 1 {
                            Button { inputs.swapAt(i, i - 1) } label: { Image(systemName: "chevron.up") }.disabled(i == 0).accessibilityLabel("أعلى")
                            Button { inputs.swapAt(i, i + 1) } label: { Image(systemName: "chevron.down") }.disabled(i == inputs.count - 1).accessibilityLabel("أسفل")
                        }
                        Button { inputs.remove(at: i); results = [] } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.text3) }.accessibilityLabel("إزالة")
                    }
                    .padding(8).background(Brand.sunken, in: RoundedRectangle(cornerRadius: Radius.m))
                    .buttonStyle(.borderless)
                }
            }
            if !inputs.isEmpty { options(inputs) }
            if let error { Text(error).font(.plex(.subheadline)).foregroundStyle(.red).accessibilityIdentifier("error") }
            if busy {
                Panel {
                    HStack(spacing: 8) { ProgressView(); Text(progress.label.isEmpty ? "جار المعالجة على جهازك…" : progress.label).font(.plex(.subheadline)).foregroundStyle(Brand.text1) }.frame(maxWidth: .infinity)
                    if progress.value >= 0 {
                        ProgressView(value: progress.value).tint(Brand.accent).animation(.easeOut, value: progress.value)
                        Text("\(Int(progress.value * 100))%").font(.plex(.caption)).foregroundStyle(Brand.text3).frame(maxWidth: .infinity)
                    }
                }
            } else {
                PrimaryButton(title: actionLabel, icon: "bolt.fill", enabled: !inputs.isEmpty) { start() }.accessibilityIdentifier("action")
            }
            if !results.isEmpty {
                if inputs.count == 1, results.count == 1, ["jpg", "jpeg", "png", "heic"].contains(results[0].pathExtension.lowercased()), ["jpg", "jpeg", "png", "heic", "webp"].contains(inputs[0].pathExtension.lowercased()) {
                    BeforeAfter(before: inputs[0], after: results[0])
                }
                ResultFiles(files: results)
            }
            after()
        }
        .task {
            #if DEBUG
            if inputs.isEmpty, let spec = ProcessInfo.processInfo.environment["MYS_TEST_INPUTS"] { inputs = TestInputs.make(spec) }
            #endif
            if inputs.isEmpty, let l = Incoming.shared.take() { inputs = multiple ? l : Array(l.prefix(1)) }
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
        if let r = plus.check(tool.id, sizes: inputs.map { FilesX.size($0) }) { plus.paywall = r; return }
        busy = true; progress.value = -1; progress.label = ""
        let ins = inputs
        Task {
            do {
                let out = FilesX.outDir()
                let started = Date()
                let r = try await Task.detached(priority: .userInitiated) { try await run(ins, out, progress) }.value
                // Nothing came out: the inputs could not be read (broken or of another type). Say so instead of an empty result.
                if r.isEmpty { throw UserError("تعذر فتح الملف. تأكد أنه سليم ومن النوع المطلوب.") }
                results = r
                store.used(tool.id, results.first?.lastPathComponent ?? "")
                plus.counted(tool.id)
                ReviewAsk.success()
                if Date().timeIntervalSince(started) > 6 { Notify.done(tool.title, results.count) }
            } catch { self.error = friendly(error) }
            busy = false
        }
    }
}

extension FileTool where After == EmptyView {
    init(tool: Tool, types: [UTType], multiple: Bool = false, pickLabel: String, actionLabel: String, reorderable: Bool = false,
         validate: @escaping ([URL]) -> String? = { $0.isEmpty ? "اختر ملفا أولا" : nil },
         @ViewBuilder options: @escaping ([URL]) -> Options, run: @escaping ([URL], URL, Progress) async throws -> [URL]) {
        self.init(tool: tool, types: types, multiple: multiple, pickLabel: pickLabel, actionLabel: actionLabel, reorderable: reorderable, validate: validate, options: options, after: { EmptyView() }, run: run)
    }
}

extension FileTool where After == EmptyView, Options == EmptyView {
    init(tool: Tool, types: [UTType], multiple: Bool = false, pickLabel: String, actionLabel: String, reorderable: Bool = false,
         validate: @escaping ([URL]) -> String? = { $0.isEmpty ? "اختر ملفا أولا" : nil }, run: @escaping ([URL], URL, Progress) async throws -> [URL]) {
        self.init(tool: tool, types: types, multiple: multiple, pickLabel: pickLabel, actionLabel: actionLabel, reorderable: reorderable, validate: validate, options: { _ in EmptyView() }, after: { EmptyView() }, run: run)
    }
}

func friendly(_ e: Error) -> String {
    let m = e.localizedDescription
    if m.unicodeScalars.contains(where: { (0x0600...0x06FF).contains($0.value) }) { return m }
    return "تعذرت المعالجة: تأكد أن الملف سليم ومن النوع الصحيح."
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
            if files.count > 60 { Text("و\(files.count - 60) ملفا آخر").font(.plex(.caption)) }
            HStack {
                SecondaryButton(title: "مشاركة", icon: "square.and.arrow.up") { sharing = true }
                SecondaryButton(title: "حفظ في الملفات", icon: "folder") { exportCopies = files.map { copy($0) }; exporting = true }
            }
            Text("تجدها أيضا في تطبيق «الملفات» ← على الـiPhone ← ميسر.").font(.plex(.caption)).foregroundStyle(.secondary)
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


/// Small preview of a picked file (image or first PDF page) using Quick Look thumbnails.
struct Thumb: View {
    let url: URL
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Brand.surface)
            if let img { Image(uiImage: img).resizable().scaledToFill() } else { Image(systemName: fileIcon(url)).foregroundStyle(Brand.text3) }
        }
        .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: url) {
            let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 88, height: 88), scale: 2, representationTypes: .thumbnail)
            img = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: req).uiImage
        }
    }
}

/// Before/after comparison: drag to reveal the result over the original.
struct BeforeAfter: View {
    let before: URL, after: URL
    @State private var split: CGFloat = 0.5
    var body: some View {
        if let a = ImageEngine.load(before, maxSide: 1400), let b = ImageEngine.load(after, maxSide: 1400) {
            Panel(title: "قبل وبعد") {
                GeometryReader { g in
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: b).resizable().scaledToFit().frame(width: g.size.width, height: g.size.height)
                        Image(uiImage: a).resizable().scaledToFit().frame(width: g.size.width, height: g.size.height)
                            .mask(HStack(spacing: 0) { Rectangle().frame(width: g.size.width * split); Spacer(minLength: 0) })
                        Rectangle().fill(.white).frame(width: 3).offset(x: g.size.width * split - 1.5).shadow(radius: 2)
                        HStack { tag("قبل"); Spacer(); tag("بعد") }.padding(8)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { split = min(max($0.location.x / g.size.width, 0), 1) })
                }
                .environment(\.layoutDirection, .leftToRight)
                .aspectRatio(max(min(a.size.width / max(a.size.height, 1), 2), 0.5), contentMode: .fit)
                .background(Brand.sunken).clipShape(RoundedRectangle(cornerRadius: Radius.m))
                Text("اسحب للمقارنة").font(.plex(.caption2)).foregroundStyle(Brand.text3).frame(maxWidth: .infinity)
            }
        }
    }
    private func tag(_ t: String) -> some View { Text(t).font(.plex(.caption2, .semibold)).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6)) }
}
