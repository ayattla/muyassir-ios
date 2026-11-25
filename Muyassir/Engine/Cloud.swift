import Foundation

/// The Muyassir server (ayattla.com/muyassir): online quizzes students open by link or QR without an account.
/// Only what the teacher publishes is sent (title, questions, answers, time). No files and no personal data;
/// the device gets an anonymous token on first publish.
enum Cloud {
    static let base = "https://ayattla.com/muyassir"
    struct Failure: LocalizedError { let message: String; var errorDescription: String? { message } }

    /// The app's quiz types → the server's: 0 choice, 1 true/false, 3 blank, 4 matching (as "sort"). Essays are left out.
    static func toActivity(title: String, qs: [Rec], minutes: Int, days: Int = 7) -> (activity: Rec, skipped: Int) {
        var out: [Rec] = []; var skipped = 0
        for q in qs {
            let text = q.s("q").trimmingCharacters(in: .whitespacesAndNewlines)
            let mark = min(max(Double(q.s("mark")) ?? 1, 0), 100)
            switch q["type"] as? Int ?? 0 {
            case 0:
                let opts = ((q["opts"] as? [String]) ?? []).map { $0.trimmingCharacters(in: .whitespaces) }
                let i = q["ans"] as? Int ?? 0
                let ans = i < opts.count ? opts[i] : ""
                let list = opts.filter { !$0.isEmpty }
                if text.isEmpty || list.count < 2 || ans.isEmpty { skipped += 1; continue }
                out.append(["text": text, "type": "choice", "options": list, "answer": ans, "mark": mark])
            case 1:
                if text.isEmpty { skipped += 1; continue }
                out.append(["text": text, "type": "truefalse", "answer": (q["ans"] as? Int ?? 0) == 0 ? "صح" : "خطأ", "mark": mark])
            case 3:
                let ans = q.s("answer").trimmingCharacters(in: .whitespaces)
                if text.isEmpty || ans.isEmpty { skipped += 1; continue }
                let shown = text.replacingOccurrences(of: "_{2,}|…+|\\.{4,}", with: "......", options: .regularExpression)
                out.append(["text": shown, "type": "blank", "answer": ans, "mark": mark])
            case 4:
                let ps: [(String, String)] = q.s("pairs").split(separator: "\n").compactMap { l in
                    let p = l.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                    return p.count == 2 && !p[0].isEmpty && !p[1].isEmpty ? (p[0], p[1]) : nil
                }.prefix(8).map { $0 }
                if ps.count < 2 { skipped += 1; continue }
                let head = (text.isEmpty ? "صل كل عنصر بما يناسبه" : text) + "\n" + ps.enumerated().map { "\($0.offset + 1)) \($0.element.0)" }.joined(separator: "\n")
                out.append(["text": String(head.prefix(600)), "type": "sort", "options": ps.map { $0.1 }.sorted(), "answer": ps.map { $0.1 }, "mark": mark])
            case 5:
                let its = Array(Edu.items(q.s("items")).prefix(8))
                if its.count < 2 { skipped += 1; continue }
                out.append(["text": text.isEmpty ? "رتب العناصر ترتيبا صحيحا" : text, "type": "order", "options": its.sorted(), "answer": its, "mark": mark])
            case 6:
                let ps = Array(Edu.pairs(q.s("pairs")).filter { !$0.1.isEmpty }.prefix(20))
                var cats: [String] = []; for c in ps.map(\.1) where !cats.contains(c) { cats.append(c) }
                if ps.count < 2 || cats.count < 2 || cats.count > 8 { skipped += 1; continue }
                out.append(["text": text.isEmpty ? "صنف العناصر" : text, "type": "classify", "items": ps.map(\.0), "options": cats, "answer": ps.map(\.1), "mark": mark])
            default: skipped += 1
            }
        }
        let a: Rec = ["title": String((title.isEmpty ? "اختبار" : title).prefix(120)), "questions": out,
                      "minutes": min(max(minutes, 0), 300), "closes_in_days": min(max(days, 1), 60), "show_answers": true]
        return (a, skipped)
    }

    private static func call(_ method: String, _ path: String, _ body: Rec? = nil, auth: Bool = true) async throws -> Rec {
        var r = URLRequest(url: URL(string: base + path)!, timeoutInterval: 20)
        r.httpMethod = method; r.setValue("application/json", forHTTPHeaderField: "Accept")
        if auth { r.setValue("Bearer " + (try await token()), forHTTPHeaderField: "Authorization") }
        if let body { r.httpBody = try JSONSerialization.data(withJSONObject: body); r.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type") }
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: r) } catch {
            // One quiet retry: mobile networks often drop the first connection.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            do { (data, resp) = try await URLSession.shared.data(for: r) } catch { throw Failure(message: "لا يوجد اتصال بالإنترنت أو الخادم لا يستجيب") }
        }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? Rec ?? [:]
        guard (200..<300).contains(code) else {
            if code == 429 { throw Failure(message: "طلبات كثيرة خلال وقت قصير، حاول بعد قليل") }
            if let d = json["detail"] as? String, !d.isEmpty { throw Failure(message: d) }
            if code == 404 { throw Failure(message: "الاختبار غير موجود على الخادم (ربما حذف)") }
            throw Failure(message: "تعذر الاتصال بالخادم (\(code))")
        }
        return json
    }

    private static func token() async throws -> String {
        let t = Store.shared.obj("cloud").s("token"); if !t.isEmpty { return t }
        let r = try await call("POST", "/api/v1/devices", ["platform": "ios"], auth: false)
        guard let n = r["token"] as? String else { throw Failure(message: "تعذر التسجيل في الخادم") }
        var o = Store.shared.obj("cloud"); o["token"] = n; Store.shared.saveObj("cloud", o); return n
    }

    static var consented: Bool { Store.shared.obj("cloud")["consent"] as? Bool ?? false }
    static func consent() { var o = Store.shared.obj("cloud"); o["consent"] = true; Store.shared.saveObj("cloud", o) }

    /// Publishes and remembers the quiz in "published".
    static func publish(_ a: Rec) async throws -> Rec {
        let r = try await call("POST", "/api/v1/activities", a)
        let item: Rec = ["code": r.s("code"), "url": r.s("url"), "title": a.s("title"), "count": (a["questions"] as? [Rec])?.count ?? 0, "at": Date().timeIntervalSince1970]
        Store.shared.saveList("published", [item] + Store.shared.list("published")); return item
    }
    static func results(_ code: String) async throws -> Rec { try await call("GET", "/api/v1/activities/\(code)/results") }
    static func close(_ code: String) async throws { _ = try await call("POST", "/api/v1/activities/\(code)/close") }
    static func delete(_ code: String) async throws {
        do { _ = try await call("DELETE", "/api/v1/activities/\(code)") } catch let e as Failure where e.message.contains("غير موجود") {}
        Store.shared.saveList("published", Store.shared.list("published").filter { $0.s("code") != code })
    }
    /// School licence: binds an activation code to this device and turns Plus on until the licence ends.
    @MainActor static func redeem(_ code: String) async throws {
        let r = try await call("POST", "/api/v1/redeem", ["code": code.trimmingCharacters(in: .whitespaces)]); apply(r)
    }
    /// Re-checks the licence once a day (revoked or expired licences switch Plus off). Offline keeps the last answer.
    @MainActor static func refreshLicence() async {
        let l = Store.shared.obj("license")
        guard !l.s("school").isEmpty, Date().timeIntervalSince1970 - (l["checked"] as? Double ?? 0) > 86400 else { return }
        if let r = try? await call("GET", "/api/v1/entitlement") { apply(r) }
    }
    @MainActor private static func apply(_ r: Rec) {
        if r.s("plan") == "school" {
            let until = r["expires"] as? Double ?? 0
            Store.shared.saveObj("license", ["school": r.s("school"), "until": until, "code": r.s("code"), "checked": Date().timeIntervalSince1970])
            Plus.shared.school = r.s("school"); Plus.shared.schoolUntil = Date(timeIntervalSince1970: until)
        } else {
            Store.shared.saveObj("license", [:]); Plus.shared.school = ""; Plus.shared.schoolUntil = .distantPast
        }
    }

    /// Deletes the device and everything it published from the server, then forgets the token.
    static func forgetMe() async throws {
        if !Store.shared.obj("cloud").s("token").isEmpty { _ = try await call("DELETE", "/api/v1/devices/me") }
        Store.shared.saveObj("cloud", [:]); Store.shared.saveList("published", [])
        await MainActor.run { Store.shared.saveObj("license", [:]); Plus.shared.school = ""; Plus.shared.schoolUntil = .distantPast }
    }
}
