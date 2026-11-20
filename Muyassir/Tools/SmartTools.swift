import SwiftUI
import PhotosUI
import AVFoundation
import Speech
import VisionKit

// MARK: QR

struct QrMake: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var kind = 0; @State var a = ""; @State var b = ""; @State var c = 0; @State var result: [URL] = []
    let kinds = ["نص/رابط", "شبكة Wi‑Fi", "اتصال", "بريد", "رسالة SMS"]
    var payload: String {
        switch kind {
        case 1: let esc = { (s: String) in s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: ";", with: "\\;").replacingOccurrences(of: ",", with: "\\,").replacingOccurrences(of: ":", with: "\\:") }
            return "WIFI:T:\(["WPA", "WEP", "nopass"][c]);S:\(esc(a));P:\(c == 2 ? "" : esc(b));;"
        case 2: return "tel:\(a.filter { $0.isNumber || $0 == "+" })"
        case 3: return "mailto:\(a)" + (b.isEmpty ? "" : "?subject=\(b.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        case 4: return "SMSTO:\(a):\(b)"
        default: return a
        }
    }
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Picker("النوع", selection: $kind) { ForEach(kinds.indices, id: \.self) { Text(kinds[$0]).tag($0) } }.pickerStyle(.menu)
                switch kind {
                case 1: Field(label: "اسم الشبكة", text: $a); Seg(options: ["WPA/WPA2", "WEP", "مفتوحة"], selection: $c); if c != 2 { Field(label: "كلمة مرور الشبكة", text: $b) }
                case 2: Field(label: "رقم الجوال", text: $a, kind: .phonePad)
                case 3: Field(label: "البريد الإلكتروني", text: $a, kind: .emailAddress); Field(label: "الموضوع (اختياري)", text: $b)
                case 4: Field(label: "رقم الجوال", text: $a, kind: .phonePad); Field(label: "نص الرسالة", text: $b, lines: 2)
                default: Field(label: "النص أو الرابط", text: $a, lines: 3)
                }
            }
            if !a.isEmpty {
                Image(uiImage: ImageEngine.qr(payload, size: 600)).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 260).padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16)).frame(maxWidth: .infinity).accessibilityLabel("رمز QR")
                PrimaryButton(title: "حفظ صورة PNG", icon: "square.and.arrow.down") {
                    result = [try? ImageEngine.save(ImageEngine.qr(payload, size: 1200), .png, quality: 1, to: FilesX.outDir().appendingPathComponent("رمز-QR.png"))].compactMap { $0 }; store.used(tool.id)
                }
            }
            if !result.isEmpty { ResultFiles(files: result) }
        }
    }
}

struct LiveScanner: UIViewControllerRepresentable {
    let found: (String) -> Void
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let v = DataScannerViewController(recognizedDataTypes: [.barcode()], qualityLevel: .balanced, isHighlightingEnabled: true)
        v.delegate = context.coordinator; try? v.startScanning(); return v
    }
    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}
    func makeCoordinator() -> C { C(found) }
    final class C: NSObject, DataScannerViewControllerDelegate {
        let found: (String) -> Void; init(_ f: @escaping (String) -> Void) { found = f }
        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for i in items { if case let .barcode(b) = i, let v = b.payloadStringValue { s.stopScanning(); found(v); return } }
        }
    }
}

struct QrRead: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var item: PhotosPickerItem?; @State var value = ""; @State var scanning = false; @State var error: String?
    var body: some View {
        ToolScreen(tool: tool) {
            if DataScannerViewController.isSupported {
                PrimaryButton(title: "مسح بالكاميرا", icon: "camera.viewfinder") { scanning = true }
            }
            PhotosPicker(selection: $item, matching: .images) { Label("اختيار صورة من المعرض", systemImage: "photo").font(.plex(.subheadline, .semibold)).frame(maxWidth: .infinity, minHeight: 48) }
                .buttonStyle(.bordered)
            if let error { Text(error).font(.plex(.footnote)).foregroundStyle(.red) }
            if !value.isEmpty {
                TextResult(text: value, label: "المحتوى")
                if let u = URL(string: value), ["http", "https"].contains(u.scheme?.lowercased() ?? "") { Link(destination: u) { Label("فتح الرابط", systemImage: "safari") }.frame(maxWidth: .infinity) }
            }
            Hint(text: "القراءة تتم على جهازك بالكامل. لا تُفتح الروابط إلا عند ضغطك.")
        }
        .onChange(of: item) {
            Task {
                guard let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) else { return }
                let codes = (try? ImageEngine.readCodes(img)) ?? []
                if let f = codes.first { value = f; error = nil; store.used(tool.id) } else { error = "لم يُعثر على رمز في الصورة" }
            }
        }
        .sheet(isPresented: $scanning) {
            LiveScanner { v in value = v; error = nil; scanning = false; store.used(tool.id) }.ignoresSafeArea()
        }
    }
}

// MARK: Text

struct TextCompare: View {
    let tool: Tool
    @State var a = ""; @State var b = ""; @State var byWord = 0
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { Field(label: "النص الأول", text: $a, lines: 5); Field(label: "النص الثاني", text: $b, lines: 5); Seg(options: ["كلمات", "أسطر"], selection: $byWord) }
            if !a.isEmpty || !b.isEmpty {
                let p = TextTools.diff(a, b, byWord: byWord == 0)
                ResultCard(main: ("نسبة التشابه", "\(fmt(TextTools.similarity(p) * 100, 1))%"), rows: [("مضاف", "\(p.filter { $0.op == .added }.count)"), ("محذوف", "\(p.filter { $0.op == .removed }.count)")])
                Panel(title: "الفروق") {
                    p.reduce(Text("")) { t, x in
                        t + Text(x.text + (byWord == 0 ? " " : "\n")).foregroundColor(x.op == .added ? Color(hex: 0x15803D) : x.op == .removed ? .red : .primary)
                            .strikethrough(x.op == .removed).underline(x.op == .added)
                    }.font(.plex(.body)).textSelection(.enabled)
                    Text("الأخضر مضاف في النص الثاني، والأحمر محذوف منه.").font(.plex(.caption)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct WordCount: View {
    let tool: Tool; @State var text = ""
    var body: some View {
        let c = TextTools.count(text)
        ToolScreen(tool: tool) {
            Panel { Field(label: "الصق النص هنا", text: $text, lines: 10) }
            ResultCard(main: ("الكلمات", "\(c.words)"), rows: [("الأحرف", "\(c.chars)"), ("الأحرف بلا مسافات", "\(c.charsNoSpaces)"), ("الجمل", "\(c.sentences)"), ("الفقرات", "\(c.paragraphs)"), ("الأسطر", "\(c.lines)"), ("وقت القراءة", "\(fmt(max(c.readMinutes, 0), 1)) دقيقة")])
        }
    }
}

struct Dedupe: View {
    let tool: Tool; @State var text = ""; @State var ic = true; @State var trim = true; @State var blank = false
    var body: some View {
        let r = TextTools.dedupe(text, ignoreCase: ic, trim: trim, keepBlank: blank)
        ToolScreen(tool: tool) {
            Panel { Field(label: "سطر لكل عنصر", text: $text, lines: 8)
                Toggle("تجاهل حالة الأحرف الإنجليزية", isOn: $ic); Toggle("إزالة المسافات الزائدة", isOn: $trim); Toggle("الإبقاء على الأسطر الفارغة", isOn: $blank) }.font(.plex(.subheadline))
            if !text.isEmpty { ResultCard(main: ("المحذوف", "\(r.1) سطر")); TextResult(text: r.0) }
        }
    }
}

// MARK: Speech

final class TtsEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    let synth = AVSpeechSynthesizer()
    @Published var speaking = false
    override init() { super.init(); synth.delegate = self }
    func utterance(_ text: String, ar: Bool, rate: Double) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: text); u.voice = AVSpeechSynthesisVoice(language: ar ? "ar-SA" : "en-US"); u.rate = Float(rate) * AVSpeechUtteranceDefaultSpeechRate; return u
    }
    func speak(_ text: String, ar: Bool, rate: Double) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio); try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate); synth.speak(utterance(text, ar: ar, rate: rate))
    }
    func stop() { synth.stopSpeaking(at: .immediate) }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { DispatchQueue.main.async { self.speaking = true } }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { DispatchQueue.main.async { self.speaking = false } }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { DispatchQueue.main.async { self.speaking = false } }

    private let fileSynth = AVSpeechSynthesizer()
    private var file: AVAudioFile?
    /// Renders speech to an audio file on the device.
    func export(_ text: String, ar: Bool, rate: Double, to url: URL, done: @escaping (URL?) -> Void) {
        file = nil; try? FileManager.default.removeItem(at: url)
        var finished = false
        fileSynth.write(utterance(text, ar: ar, rate: rate)) { [weak self] buf in
            guard let self, !finished, let pcm = buf as? AVAudioPCMBuffer else { return }
            if pcm.frameLength == 0 { finished = true; self.file = nil; DispatchQueue.main.async { done(FileManager.default.fileExists(atPath: url.path) ? url : nil) }; return }
            if self.file == nil {
                let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: pcm.format.sampleRate, AVNumberOfChannelsKey: pcm.format.channelCount]
                self.file = try? AVAudioFile(forWriting: url, settings: settings, commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
            }
            try? self.file?.write(from: pcm)
        }
    }
}

struct TtsTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @StateObject var tts = TtsEngine()
    @State var text = ""; @State var lang = 0; @State var rate = 1.0; @State var result: [URL] = []; @State var busy = false
    var body: some View {
        ToolScreen(tool: tool) {
            Panel { Field(label: "النص", text: $text, lines: 8); Seg(options: ["عربي", "إنجليزي"], selection: $lang)
                VStack(alignment: .leading) { Text("السرعة \(fmt(rate, 1))×").font(.plex(.caption)); Slider(value: $rate, in: 0.5...1.6).environment(\.layoutDirection, .leftToRight) } }
            HStack {
                PrimaryButton(title: tts.speaking ? "إيقاف" : "استماع", icon: tts.speaking ? "stop.fill" : "play.fill", enabled: !text.isEmpty) { tts.speaking ? tts.stop() : tts.speak(text, ar: lang == 0, rate: rate) }
                SecondaryButton(title: busy ? "جارٍ الحفظ…" : "حفظ ملف صوتي", icon: "waveform") {
                    busy = true
                    tts.export(text, ar: lang == 0, rate: rate, to: FilesX.outDir().appendingPathComponent("نص-مقروء.m4a")) { u in busy = false; result = [u].compactMap { $0 }; store.used(tool.id) }
                }.disabled(text.isEmpty || busy)
            }
            if !result.isEmpty { ResultFiles(files: result) }
            Hint(text: "يستخدم أصوات آيفون المثبتة. لتحسين الصوت العربي: الإعدادات ← تسهيلات الاستخدام ← المحتوى المنطوق ← الأصوات ← العربية.")
        }
        .onDisappear { tts.stop() }
    }
}

final class SttEngine: ObservableObject {
    @Published var text = ""; @Published var running = false; @Published var error: String?
    private let engine = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private var req: SFSpeechAudioBufferRecognitionRequest?
    func recognizer(_ ar: Bool) -> SFSpeechRecognizer? { SFSpeechRecognizer(locale: Locale(identifier: ar ? "ar-SA" : "en-US")) }
    func onDevice(_ ar: Bool) -> Bool { recognizer(ar)?.supportsOnDeviceRecognition ?? false }

    func start(ar: Bool) {
        error = nil
        SFSpeechRecognizer.requestAuthorization { st in
            AVAudioApplication.requestRecordPermission { ok in
                DispatchQueue.main.async {
                    guard st == .authorized, ok else { self.error = "اسمح للتطبيق بالميكروفون والتعرف على الكلام من الإعدادات."; return }
                    self.begin(ar: ar)
                }
            }
        }
    }
    private func begin(ar: Bool) {
        guard let r = recognizer(ar), r.isAvailable else { error = "التعرف على الكلام غير متاح الآن لهذه اللغة."; return }
        do {
            let s = AVAudioSession.sharedInstance(); try s.setCategory(.record, mode: .measurement, options: .duckOthers); try s.setActive(true, options: .notifyOthersOnDeactivation)
            let q = SFSpeechAudioBufferRecognitionRequest(); q.shouldReportPartialResults = true; q.addsPunctuation = true
            if r.supportsOnDeviceRecognition { q.requiresOnDeviceRecognition = true }
            req = q
            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { b, _ in q.append(b) }
            engine.prepare(); try engine.start(); running = true
            let base = text.isEmpty ? "" : text + " "
            task = r.recognitionTask(with: q) { res, err in
                DispatchQueue.main.async {
                    if let res { self.text = base + res.bestTranscription.formattedString }
                    if err != nil || (res?.isFinal ?? false) { self.stop() }
                }
            }
        } catch { self.error = "تعذّر تشغيل الميكروفون."; stop() }
    }
    func stop() {
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        req?.endAudio(); task?.cancel(); task = nil; req = nil; running = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct SttTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @StateObject var stt = SttEngine()
    @State var lang = 0; @State var consent = false
    var body: some View {
        let local = stt.onDevice(lang == 0)
        ToolScreen(tool: tool) {
            Panel { Seg(options: ["عربي", "إنجليزي"], selection: $lang).disabled(stt.running)
                if !local { Toggle("أوافق على إرسال الصوت لخدمة التعرف من Apple (لا يدعم جهازك التعرف المحلي لهذه اللغة)", isOn: $consent).font(.plex(.footnote)) } }
            PrimaryButton(title: stt.running ? "إيقاف التسجيل" : "ابدأ التحدث", icon: stt.running ? "stop.circle.fill" : "mic.fill", enabled: local || consent) {
                if stt.running { stt.stop(); store.used(tool.id) } else { stt.start(ar: lang == 0) }
            }
            if stt.running { Label("أستمع الآن…", systemImage: "waveform").font(.plex(.subheadline)).foregroundStyle(Brand.lapis).frame(maxWidth: .infinity) }
            if let e = stt.error { Text(e).font(.plex(.footnote)).foregroundStyle(.red) }
            if !stt.text.isEmpty { TextResult(text: stt.text, label: "النص"); Button("مسح النص") { stt.text = "" } }
            Hint(text: local ? "التعرف يتم على جهازك دون إرسال الصوت لأي خادم." : "جهازك لا يدعم التعرف المحلي لهذه اللغة، لذلك يحتاج موافقتك قبل البدء.")
        }
        .onDisappear { stt.stop() }
    }
}

// MARK: Calculators

struct ScientificCalc: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var expr = ""; @State var result = ""; @State var deg = 0; @State var ans = 0.0; @State var mem = 0.0; @State var history: [String] = []
    let keys: [[String]] = [["sin(", "cos(", "tan(", "π", "e"], ["ln(", "log(", "√(", "^", "!"], ["(", ")", "%", "AC", "⌫"],
                            ["7", "8", "9", "÷", "Ans"], ["4", "5", "6", "×", "M+"], ["1", "2", "3", "−", "MR"], ["0", ".", "00", "+", "="]]
    var body: some View {
        ToolScreen(tool: tool) {
            VStack(alignment: .trailing, spacing: 6) {
                Text(expr.isEmpty ? "0" : expr).font(.system(.title2, design: .rounded)).lineLimit(2).minimumScaleFactor(0.5)
                Text(result).font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(Brand.lapis).lineLimit(1).minimumScaleFactor(0.4).textSelection(.enabled)
            }.frame(maxWidth: .infinity, minHeight: 100, alignment: .trailing).padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)).environment(\.layoutDirection, .leftToRight)
            Seg(options: ["درجات", "راديان"], selection: $deg)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(keys, id: \.self) { row in
                    GridRow { ForEach(row, id: \.self) { k in
                        let op = ["÷", "×", "−", "+", "="].contains(k)
                        Button { press(k) } label: {
                            Text(k == "√(" ? "√" : k.replacingOccurrences(of: "(", with: "")).font(.system(.title3, design: .rounded).weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
                                .background(k == "=" ? Brand.lapis : op ? Brand.lapis.opacity(0.14) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(k == "=" ? .white : k == "AC" ? .red : .primary)
                        }.buttonStyle(.plain).accessibilityLabel(k == "⌫" ? "حذف" : k)
                    } }
                }
            }.environment(\.layoutDirection, .leftToRight)
            if !history.isEmpty { Panel(title: "السجل") { ForEach(history.indices.reversed(), id: \.self) { Text(history[$0]).font(.system(.footnote, design: .rounded)).environment(\.layoutDirection, .leftToRight) } } }
        }
        .onChange(of: expr) { result = (try? Expr.eval(expr.replacingOccurrences(of: "Ans", with: "(\(ans))"), degrees: deg == 0)).map { $0.isFinite ? fmt($0, 10) : "" } ?? "" }
    }
    func press(_ k: String) {
        switch k {
        case "AC": expr = ""; result = ""
        case "⌫": if expr.hasSuffix("Ans") { expr.removeLast(3) } else if !expr.isEmpty { expr.removeLast(); while let l = expr.last, l.isLetter, l != "e" && l != "π" { expr.removeLast() } }
        case "=":
            guard let v = try? Expr.eval(expr.replacingOccurrences(of: "Ans", with: "(\(ans))"), degrees: deg == 0), v.isFinite else { result = "خطأ في التعبير"; return }
            history.append("\(expr) = \(fmt(v, 10))"); if history.count > 20 { history.removeFirst() }
            ans = v; expr = fmt(v, 10).replacingOccurrences(of: ",", with: ""); store.used(tool.id)
        case "M+": if let v = Double(result.replacingOccurrences(of: ",", with: "")) { mem += v }
        case "MR": expr += "\(mem)"
        default: expr += k
        }
    }
}

struct UnitsTool: View {
    let tool: Tool
    @State var kind = Units.kinds[0]; @State var from = Units.kinds[0].units[2]; @State var to = Units.kinds[0].units[1]; @State var value = "1"
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Picker("النوع", selection: $kind) { ForEach(Units.kinds, id: \.self) { Text($0.name).tag($0) } }.pickerStyle(.menu)
                    .onChange(of: kind) { from = kind.units[0]; to = kind.units[min(1, kind.units.count - 1)] }
                NumField(label: "القيمة", text: $value)
                HStack {
                    Picker("من", selection: $from) { ForEach(kind.units, id: \.self) { Text($0.name).tag($0) } }.pickerStyle(.menu)
                    Button { swap(&from, &to) } label: { Image(systemName: "arrow.left.arrow.right") }.accessibilityLabel("تبديل")
                    Picker("إلى", selection: $to) { ForEach(kind.units, id: \.self) { Text($0.name).tag($0) } }.pickerStyle(.menu)
                }
            }
            let r = Units.convert(kind, value.num, from: from, to: to)
            ResultCard(main: ("\(fmt(value.num, 6)) \(from.name) =", "\(fmt(r, 6)) \(to.name)"))
            Panel(title: "كل الوحدات") { ForEach(kind.units, id: \.self) { u in LabelValue(label: u.name, value: fmt(Units.convert(kind, value.num, from: from, to: u), 6)) } }
        }
    }
}

struct AreaVolume: View {
    let tool: Tool
    @State var shape = Units.shapes[0]; @State var vals = ["", "", ""]
    var body: some View {
        ToolScreen(tool: tool) {
            Panel {
                Picker("الشكل", selection: $shape) { ForEach(Units.shapes, id: \.self) { Text("\($0.name) (\($0.volume ? "حجم" : "مساحة"))").tag($0) } }.pickerStyle(.menu)
                ForEach(shape.fields.indices, id: \.self) { i in NumField(label: shape.fields[i], text: $vals[i]) }
            }
            let v = shape.calc(vals.map { $0.num })
            ResultCard(main: (shape.volume ? "الحجم" : "المساحة", "\(fmt(v, 4)) \(shape.volume ? "وحدة³" : "وحدة²")"),
                       rows: shape.volume ? [("باللتر (إذا كانت الأبعاد بالمتر)", fmt(v * 1000, 2))] : [("بالسنتيمتر² (إذا كانت الأبعاد بالمتر)", fmt(v * 10000, 2))])
        }
        .onChange(of: shape) { vals = ["", "", ""] }
    }
}

struct CurrencyTool: View {
    let tool: Tool
    @EnvironmentObject var store: Store
    @State var rates: [String: Double] = [:]; @State var updated = ""; @State var amount = "100"; @State var from = "SAR"; @State var to = "USD"; @State var busy = false; @State var error: String?
    let names = ["SAR": "ريال سعودي", "USD": "دولار أمريكي", "EUR": "يورو", "GBP": "جنيه إسترليني", "AED": "درهم إماراتي", "KWD": "دينار كويتي", "QAR": "ريال قطري", "BHD": "دينار بحريني",
                 "OMR": "ريال عماني", "EGP": "جنيه مصري", "JOD": "دينار أردني", "TRY": "ليرة تركية", "INR": "روبية هندية", "PKR": "روبية باكستانية", "CNY": "يوان صيني", "JPY": "ين ياباني", "MYR": "رينغيت ماليزي", "IDR": "روبية إندونيسية"]
    var body: some View {
        let codes = names.keys.sorted { $0 == "SAR" ? true : $1 == "SAR" ? false : $0 < $1 }
        ToolScreen(tool: tool) {
            Panel {
                NumField(label: "المبلغ", text: $amount)
                HStack {
                    Picker("من", selection: $from) { ForEach(codes, id: \.self) { Text("\(names[$0]!) \($0)").tag($0) } }.pickerStyle(.menu)
                    Button { swap(&from, &to) } label: { Image(systemName: "arrow.left.arrow.right") }.accessibilityLabel("تبديل")
                    Picker("إلى", selection: $to) { ForEach(codes, id: \.self) { Text("\(names[$0]!) \($0)").tag($0) } }.pickerStyle(.menu)
                }
            }
            SecondaryButton(title: busy ? "جارٍ التحديث…" : rates.isEmpty ? "جلب أسعار اليوم" : "تحديث الأسعار", icon: "arrow.clockwise") { Task { await fetch() } }.disabled(busy)
            if let error { Text(error).font(.plex(.footnote)).foregroundStyle(.red) }
            if let a = rates[from], let b = rates[to], a > 0 {
                let r = amount.num / a * b
                ResultCard(main: ("\(fmt(amount.num)) \(from) =", "\(fmt(r, 4)) \(to)"), rows: [("سعر الوحدة", "1 \(from) = \(fmt(b / a, 6)) \(to)"), ("آخر تحديث", updated)])
            }
            Hint(text: "الأسعار إرشادية من الخدمة المجانية open.er-api.com وتُجلب فقط عند ضغطك الزر، وتُحفظ لاستخدامها دون إنترنت. لا يُرسل أي من بياناتك. الريال مربوط بالدولار عند 3.75.")
        }
        .onAppear {
            let o = store.obj("rates"); rates = (o["rates"] as? [String: Double]) ?? [:]; updated = o.s("updated")
            if rates.isEmpty { rates = ["SAR": 1, "USD": 1 / 3.75]; updated = "سعر الربط الرسمي فقط" }
        }
    }
    func fetch() async {
        busy = true; defer { busy = false }
        do {
            let (d, _) = try await URLSession.shared.data(from: URL(string: "https://open.er-api.com/v6/latest/SAR")!)
            guard let j = try JSONSerialization.jsonObject(with: d) as? [String: Any], let r = j["rates"] as? [String: Double] else { throw UserError("رد غير متوقع") }
            rates = r; updated = (j["time_last_update_utc"] as? String) ?? dtFmt.string(from: Date()); error = nil
            store.saveObj("rates", ["rates": r, "updated": updated]); store.used(tool.id)
        } catch { self.error = "تعذّر جلب الأسعار. تحقق من الاتصال وحاول مجددًا." }
    }
}
