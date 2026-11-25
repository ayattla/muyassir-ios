import SwiftUI
import UIKit

/// Publishing the quiz as an online activity (link + QR, no student accounts) and reading its results.
struct OnlineQuizPanel: View {
    let title: String; let qs: [Rec]; let minutes: String
    @State private var days = 2
    @State private var busy = false
    @State private var error: String?
    @State private var last: Rec?
    @State private var note: String?
    @State private var ask = false
    @State private var qrFile: [URL] = []
    @State private var published: [Rec] = Store.shared.list("published")
    private let dayOptions = [1, 3, 7, 14]

    var body: some View {
        Panel(title: "اختبار إلكتروني برابط ورمز QR") {
            Hint(text: "يفتحه الطلاب من الجوال أو الحاسب دون حساب، ويصحح تلقائيا وتصلك النتائج هنا. ترسل الأسئلة وإجاباتها فقط إلى خادم ميسر، ولا يطلب من الطالب إلا اسمه.")
            Text("يبقى مفتوحا").font(.plex(.caption, .medium)).foregroundStyle(Brand.text2)
            Seg(options: ["يوم", "3 أيام", "أسبوع", "أسبوعان"], selection: $days)
            PrimaryButton(title: busy ? "جار النشر…" : "انشر برابط ورمز QR", icon: "globe", enabled: !qs.isEmpty && !busy) {
                if Cloud.consented { publish() } else { ask = true }
            }.accessibilityIdentifier("publishOnline")
            if let error { Text(error).font(.plex(.footnote)).foregroundStyle(.red).accessibilityIdentifier("onlineError") }
            if let item = last {
                let url = item.s("url")
                VStack(spacing: 8) {
                    Image(uiImage: ImageEngine.qr(url, size: 600)).interpolation(.none).resizable().frame(width: 200, height: 200).accessibilityLabel("رمز QR للاختبار")
                    Text(url).font(.plex(.subheadline)).multilineTextAlignment(.center).textSelection(.enabled).accessibilityIdentifier("onlineUrl")
                    Text("رمز الاختبار: \(item.s("code"))").font(.plex(.headline))
                    if let note { Text(note).font(.plex(.caption)).foregroundStyle(Brand.text2).multilineTextAlignment(.center) }
                    HStack {
                        SecondaryButton(title: "نسخ الرابط", icon: "doc.on.doc") { UIPasteboard.general.string = url }
                        ShareLink(item: URL(string: url)!, message: Text(item.s("title"))) { Label("مشاركة", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 46) }.buttonStyle(.bordered)
                    }
                    Button("حفظ رمز QR صورة للطباعة") {
                        let f = FilesX.outDir().appendingPathComponent("رمز-\(item.s("code")).png")
                        try? ImageEngine.qr(url, size: 900).pngData()?.write(to: f); qrFile = [f]
                    }.font(.plex(.subheadline))
                    if !qrFile.isEmpty { ResultFiles(files: qrFile) }
                }.frame(maxWidth: .infinity)
            }
        }
        .alert("نشر الاختبار على الإنترنت", isPresented: $ask) {
            Button("موافق، انشر") { Cloud.consent(); publish() }.accessibilityIdentifier("consentOk")
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("سيرسل عنوان الاختبار وأسئلته وإجاباتها الصحيحة ومدته إلى خادم ميسر (ayattla.com) لإنشاء صفحة للطلاب. لا ترسل ملفاتك ولا أي بيانات شخصية عنك. يغلق الاختبار في الموعد الذي اخترته، وتحذف نتائجه بعد 90 يوما من إغلاقه، ويمكنك حذفه متى شئت.")
        }
        if !published.isEmpty { PublishedList(items: published) { published = Store.shared.list("published") } }
    }

    private func publish() {
        let m = Cloud.toActivity(title: title, qs: qs, minutes: Int(Double(minutes) ?? 0), days: dayOptions[days])
        guard !((m.activity["questions"] as? [Rec]) ?? []).isEmpty else {
            error = "لا توجد أسئلة تصحح آليا. أضف سؤال اختيار أو صح وخطأ أو إكمال أو توصيل مكتملا."; return
        }
        busy = true; error = nil; qrFile = []
        Task { @MainActor in
            do {
                last = try await Cloud.publish(m.activity); published = Store.shared.list("published")
                note = m.skipped > 0 ? "لم ينشر \(m.skipped) سؤال: الأسئلة المقالية أو غير المكتملة لا تصحح آليا." : nil
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

private struct PublishedList: View {
    let items: [Rec]; let changed: () -> Void
    @State private var open: String?
    @State private var res: Rec?
    @State private var error: String?
    @State private var busy = false
    @State private var confirm: String?
    @State private var forget = false
    @State private var files: [URL] = []

    var body: some View {
        Panel(title: "اختباراتي المنشورة") {
            ForEach(items.indices, id: \.self) { i in
                let p = items[i]; let code = p.s("code")
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.s("title")).font(.plex(.subheadline, .semibold))
                    Text("الرمز \(code) • \(p["count"] as? Int ?? 0) سؤال • \(Date(timeIntervalSince1970: p["at"] as? Double ?? 0).formatted(.dateTime.day().month(.defaultDigits).year().locale(Locale(identifier: "en_US"))))")
                        .font(.plex(.caption)).foregroundStyle(Brand.text2)
                    HStack {
                        SecondaryButton(title: "النتائج", icon: "chart.bar") { load(code) }.accessibilityIdentifier("results-\(code)")
                        Button("نسخ الرابط") { UIPasteboard.general.string = p.s("url") }.font(.plex(.footnote))
                        Button("حذف", role: .destructive) { confirm = code }.font(.plex(.footnote))
                    }
                    if open == code { results(code) }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button("حذف كل اختباراتي ونتائجها من الخادم", role: .destructive) { forget = true }.font(.plex(.footnote)).frame(maxWidth: .infinity)
        }
        .confirmationDialog("حذف الاختبار نهائيا؟", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), titleVisibility: .visible) {
            Button("حذف نهائي", role: .destructive) { if let c = confirm { remove(c) } }
        } message: { Text("سيحذف الاختبار ونتائج الطلاب من الخادم نهائيا، ولن يفتح رابطه بعد الآن.") }
        .confirmationDialog("حذف بياناتك من الخادم؟", isPresented: $forget, titleVisibility: .visible) {
            Button("حذف نهائي", role: .destructive) {
                Task { @MainActor in do { try await Cloud.forgetMe(); open = nil; changed() } catch { self.error = error.localizedDescription } }
            }
        } message: { Text("ستحذف كل اختباراتك المنشورة ونتائج طلابها ومعرف جهازك من خادم ميسر نهائيا. ملفاتك على الجهاز لا تتأثر.") }
    }

    @ViewBuilder private func results(_ code: String) -> some View {
        if busy { ProgressView().frame(maxWidth: .infinity) }
        if let error { Text(error).font(.plex(.footnote)).foregroundStyle(.red) }
        if let r = res {
            let att = (r["attempts"] as? [Rec]) ?? []
            let total = att.first?["total"] as? Double ?? 0
            ResultCard(main: ("عدد المتقدمين", "\(att.count)"), rows: [
                ("متوسط الدرجة", att.isEmpty ? "—" : "\(fmt(r["average"] as? Double ?? 0)) من \(fmt(total))"),
                ("الحالة", (r["closed"] as? Bool ?? false) ? "مغلق" : "مفتوح"),
            ])
            if att.isEmpty { Text("لم يرسل أي طالب إجابته بعد.").font(.plex(.caption)).foregroundStyle(Brand.text2).accessibilityIdentifier("noAttempts") }
            ForEach(att.indices, id: \.self) { k in LabelValue(label: att[k].s("name"), value: "\(fmt(att[k]["score"] as? Double ?? 0)) / \(fmt(att[k]["total"] as? Double ?? 0))") }
            if !att.isEmpty, let pq = r["per_question"] as? [Rec] {
                Text("الإجابات الصحيحة لكل سؤال").font(.plex(.caption, .semibold))
                ForEach(pq.indices, id: \.self) { k in
                    LabelValue(label: "\(k + 1)) \(String((pq[k].s("text").split(separator: "\n").first ?? "").prefix(40)))", value: "\(pq[k]["correct"] as? Int ?? 0) من \(pq[k]["of"] as? Int ?? 0)")
                }
            }
            HStack {
                if !att.isEmpty { SecondaryButton(title: "تصدير إلى Excel", icon: "tablecells") { export(r, att) } }
                if !(r["closed"] as? Bool ?? false) {
                    Button("إغلاق الاختبار الآن") { Task { @MainActor in do { try await Cloud.close(code) } catch { self.error = error.localizedDescription }; load(code) } }.font(.plex(.footnote))
                }
            }
            if !files.isEmpty { ResultFiles(files: files) }
        }
    }

    private func load(_ code: String) {
        busy = true; error = nil; open = code; res = nil; files = []
        Task { @MainActor in
            do { res = try await Cloud.results(code) } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func remove(_ code: String) {
        Task { @MainActor in
            do { try await Cloud.delete(code); if open == code { open = nil }; changed() } catch { self.error = error.localizedDescription; open = code }
        }
    }
    private func export(_ r: Rec, _ att: [Rec]) {
        let f = DateFormatter(); f.dateFormat = "d/M/yyyy HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
        let rows = [["الاسم", "الدرجة", "من", "وقت الإرسال"]] + att.map { a in
            [a.s("name"), fmt(a["score"] as? Double ?? 0), fmt(a["total"] as? Double ?? 0), f.string(from: Date(timeIntervalSince1970: a["submitted"] as? Double ?? 0))]
        }
        let url = FilesX.outDir().appendingPathComponent("نتائج-\(r.s("title")).xlsx")
        do { try Office.writeXlsx(url, [("النتائج", rows)]); files = [url] } catch { self.error = error.localizedDescription }
    }
}
