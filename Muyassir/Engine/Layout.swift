import Foundation
import UIKit
import Vision

/// Document reconstruction from OCR words: headings, paragraphs and tables, plus the words the engine was unsure of
/// so the user reviews them before export. Coordinates are image pixels, y grows downwards.
enum DocLayout {
    struct Word: Equatable { var text: String; var left, top, right, bottom: CGFloat; var conf: Float = 100
        var cy: CGFloat { (top + bottom) / 2 }
    }
    struct Line { let words: [Word]
        var top: CGFloat { words.map(\.top).min() ?? 0 }; var bottom: CGFloat { words.map(\.bottom).max() ?? 0 }; var h: CGFloat { bottom - top }
        func text(_ rtl: Bool) -> String { (rtl ? words.sorted { $0.right > $1.right } : words.sorted { $0.left < $1.left }).map(\.text).joined(separator: " ") }
    }
    enum Block: Equatable { case heading(String), para(String), table([[String]]) }
    struct Result { var blocks: [Block]; var unsure: [String]
        func plain() -> String { blocks.map { b in switch b { case let .heading(t), let .para(t): return t; case let .table(r): return r.map { $0.joined(separator: " | ") }.joined(separator: "\n") } }.joined(separator: "\n\n") }
    }
    static let unsureBelow: Float = 60

    static func isRtl(_ ws: [Word]) -> Bool {
        let letters = ws.map(\.text).joined().unicodeScalars.filter { CharacterSet.letters.contains($0) }
        return letters.filter { (0x0600...0x06FF).contains($0.value) }.count * 2 >= letters.count
    }

    static func lines(_ words: [Word]) -> [Line] {
        var out: [[Word]] = []
        for w in words.filter({ !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }).sorted(by: { $0.cy < $1.cy }) {
            if let l = out.last, let t = l.map(\.top).min(), let b = l.map(\.bottom).max(), w.cy >= t && w.cy <= b { out[out.count - 1].append(w) } else { out.append([w]) }
        }
        return out.map { Line(words: $0) }
    }

    private static func cells(_ l: Line, _ gap: CGFloat) -> [[Word]] {
        var out: [[Word]] = []
        for w in l.words.sorted(by: { $0.left < $1.left }) { if let c = out.last, w.left - (c.last?.right ?? 0) <= gap { out[out.count - 1].append(w) } else { out.append([w]) } }
        return out
    }

    static func analyze(_ words: [Word]) -> Result {
        let ls = lines(words); guard !ls.isEmpty else { return Result(blocks: [], unsure: []) }
        let rtl = isRtl(words)
        let medH = max(1, ls.map(\.h).sorted()[ls.count / 2]); let gap = medH * 1.6
        let split = ls.map { cells($0, gap) }
        var blocks: [Block] = []; var para = ""
        func flush() { let p = para.trimmingCharacters(in: .whitespaces); if !p.isEmpty { blocks.append(.para(p)) }; para = "" }
        var i = 0
        while i < ls.count {
            let n = split[i].count; var j = i
            while j + 1 < ls.count && n >= 2 && split[j + 1].count == n && ls[j + 1].top - ls[j].bottom < medH * 2.5 { j += 1 }
            if n >= 2 && j > i {
                flush()
                blocks.append(.table((i...j).map { k in let cs = split[k].map { Line(words: $0).text(rtl) }; return rtl ? cs.reversed() : cs }))
                i = j + 1; continue
            }
            let l = ls[i], t = l.text(rtl), gapAbove = i > 0 ? l.top - ls[i - 1].bottom : 0
            if l.h > medH * 1.35 && t.count < 80 { flush(); blocks.append(.heading(t)) }
            else { if gapAbove > medH * 1.2 { flush() }; if !para.isEmpty { para += " " }; para += t }
            i += 1
        }
        flush()
        var seen = Set<String>()
        let unsure = words.filter { $0.conf < unsureBelow && $0.text.contains(where: { $0.isLetter || $0.isNumber }) }.map(\.text).filter { seen.insert($0).inserted }
        return Result(blocks: blocks, unsure: unsure)
    }

    static func toDocx(_ r: Result) -> [Office.Para] {
        r.blocks.map { b in switch b { case let .heading(t): return .text(t, heading: 2); case let .para(t): return .text(t); case let .table(rows): return .table(rows) } }
    }

    /// Rebuilds blocks from edited text (the review screen): "|" separated lines become table rows.
    static func fromText(_ text: String) -> Result {
        var blocks: [Block] = []
        let chunks = text.replacingOccurrences(of: "\r", with: "").components(separatedBy: try! NSRegularExpression(pattern: "\n\\s*\n"))
        for c in chunks.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !c.isEmpty {
            let ls = c.components(separatedBy: "\n")
            if ls.count >= 2 && ls.allSatisfy({ $0.contains("|") }) { blocks.append(.table(ls.map { $0.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) } })) }
            else if ls.count == 1 && c.count < 60 && !c.hasSuffix(".") && !c.hasSuffix("،") { blocks.append(.heading(c)) }
            else { blocks.append(.para(ls.joined(separator: " "))) }
        }
        return Result(blocks: blocks, unsure: [])
    }

    /// Words with positions and confidence from Vision (line confidence applied to its words).
    static func recognizeWords(_ img: UIImage) throws -> [Word] {
        guard let cg = img.cgImage else { return [] }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate; req.usesLanguageCorrection = true; req.automaticallyDetectsLanguage = false
        req.recognitionLanguages = ["ar-SA", "en-US"]
        try VNImageRequestHandler(cgImage: cg).perform([req])
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        var out: [Word] = []
        for o in req.results ?? [] {
            guard let c = o.topCandidates(1).first else { continue }
            let s = c.string; var idx = s.startIndex
            for part in s.split(separator: " ") {
                guard let r = s.range(of: part, range: idx..<s.endIndex) else { continue }
                idx = r.upperBound
                let b = (try? c.boundingBox(for: r))?.boundingBox ?? o.boundingBox
                out.append(Word(text: String(part), left: b.minX * W, top: (1 - b.maxY) * H, right: b.maxX * W, bottom: (1 - b.minY) * H, conf: c.confidence * 100))
            }
        }
        return out
    }
}

extension String {
    func components(separatedBy re: NSRegularExpression) -> [String] {
        let ns = self as NSString; var out: [String] = []; var last = 0
        for m in re.matches(in: self, range: NSRange(location: 0, length: ns.length)) { out.append(ns.substring(with: NSRange(location: last, length: m.range.location - last))); last = m.range.location + m.range.length }
        out.append(ns.substring(from: last)); return out
    }
}

/// Splits recognised exam text into questions and their choices.
enum ExamParser {
    enum Kind { case choice, trueFalse, open }
    struct Q: Equatable { var text: String; var choices: [String]; var kind: Kind }

    private static let digitMap: [Character: Character] = ["٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9"]
    private static func latin(_ s: String) -> String { String(s.map { digitMap[$0] ?? $0 }) }
    private static let qStart = try! NSRegularExpression(pattern: "^\\s*(?:س\\s*)?\\(?([0-9]{1,3})\\s*[).:\\-ـ/]\\s*(.+)$")
    private static let choice = try! NSRegularExpression(pattern: "^\\s*\\(?([أابجدهـabcdABCD])\\s*[).:\\-ـ]\\s*(.+)$")
    private static let inline = try! NSRegularExpression(pattern: "\\(?([أبجد])\\s*[).\\-]\\s*([^()]+?)(?=\\s*\\(?[أبجد]\\s*[).\\-]|$)")

    private static func groups(_ re: NSRegularExpression, _ s: String) -> [String]? {
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
    }
    private static func inlineChoices(_ s: String) -> [(NSRange, String)] {
        let ns = s as NSString
        return inline.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { ($0.range, ns.substring(with: $0.range(at: 2)).trimmingCharacters(in: .whitespaces)) }
    }

    static func parse(_ text: String) -> [Q] {
        var out: [Q] = []; var cur: String?; var cs: [String] = []
        func push() { if let q = cur { out.append(Q(text: q.trimmingCharacters(in: .whitespaces), choices: cs, kind: kind(q, cs))) }; cur = nil; cs = [] }
        for raw in text.components(separatedBy: "\n") {
            let l = latin(raw).trimmingCharacters(in: .whitespaces); if l.isEmpty { continue }
            let qm = groups(qStart, l), cm = groups(choice, l)
            if let qm, cm == nil || cur == nil {
                push(); var body = qm[2]
                let inl = inlineChoices(body)
                if inl.count >= 2 { body = (body as NSString).substring(to: inl[0].0.location).trimmingCharacters(in: .whitespaces); cs.append(contentsOf: inl.map(\.1)) }
                cur = body
            } else if let cm, cur != nil {
                let inl = inlineChoices(l); if inl.count >= 2 { cs.append(contentsOf: inl.map(\.1)) } else { cs.append(cm[2].trimmingCharacters(in: .whitespaces)) }
            } else if cur != nil { if cs.isEmpty { cur! += " " + l } else { cs[cs.count - 1] += " " + l } }
        }
        push(); return out
    }
    private static func kind(_ q: String, _ cs: [String]) -> Kind {
        if cs.count >= 2 { return .choice }
        if q.range(of: "صح|خطأ|\\(\\s*\\)", options: .regularExpression) != nil { return .trueFalse }
        return .open
    }
}
