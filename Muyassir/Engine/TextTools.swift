import Foundation

enum TextTools {
    struct Counts { let words, chars, charsNoSpaces, lines, sentences, paragraphs: Int; let readMinutes: Double }
    static func count(_ s: String) -> Counts {
        var words = 0
        s.enumerateSubstrings(in: s.startIndex..., options: .byWords) { _, _, _, _ in words += 1 }
        var sentences = 0
        s.enumerateSubstrings(in: s.startIndex..., options: .bySentences) { sub, _, _, _ in if !(sub ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { sentences += 1 } }
        let paras = s.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        return Counts(words: words, chars: s.count, charsNoSpaces: s.filter { !$0.isWhitespace }.count,
                      lines: s.isEmpty ? 0 : s.components(separatedBy: "\n").count, sentences: sentences, paragraphs: paras, readMinutes: Double(words) / 200)
    }

    static func dedupe(_ s: String, ignoreCase: Bool, trim: Bool, keepBlank: Bool) -> (String, Int) {
        var seen = Set<String>(), out: [String] = [], removed = 0
        for line in s.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { if keepBlank { out.append(line) }; continue }
            let v = trim ? line.trimmingCharacters(in: .whitespaces) : line
            let key = ignoreCase ? v.lowercased() : v
            if seen.insert(key).inserted { out.append(v) } else { removed += 1 }
        }
        return (out.joined(separator: "\n"), removed)
    }

    enum Op { case same, added, removed }
    struct Piece: Hashable { let op: Op; let text: String; let id = UUID() }

    static func diff(_ a: String, _ b: String, byWord: Bool) -> [Piece] {
        let x = byWord ? a.split(whereSeparator: \.isWhitespace).map(String.init) : a.components(separatedBy: "\n")
        let y = byWord ? b.split(whereSeparator: \.isWhitespace).map(String.init) : b.components(separatedBy: "\n")
        let n = x.count, m = y.count
        if n * m > 4_000_000 { return [Piece(op: .removed, text: a), Piece(op: .added, text: b)] }
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 { for i in stride(from: n - 1, through: 0, by: -1) { for j in stride(from: m - 1, through: 0, by: -1) { dp[i][j] = x[i] == y[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1]) } } }
        var out: [Piece] = [], i = 0, j = 0
        while i < n && j < m {
            if x[i] == y[j] { out.append(Piece(op: .same, text: x[i])); i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { out.append(Piece(op: .removed, text: x[i])); i += 1 }
            else { out.append(Piece(op: .added, text: y[j])); j += 1 }
        }
        while i < n { out.append(Piece(op: .removed, text: x[i])); i += 1 }
        while j < m { out.append(Piece(op: .added, text: y[j])); j += 1 }
        return out
    }

    static func similarity(_ p: [Piece]) -> Double {
        let same = p.filter { $0.op == .same }.count, n = p.filter { $0.op != .added }.count, m = p.filter { $0.op != .removed }.count
        return n + m == 0 ? 100 : 200 * Double(same) / Double(n + m)
    }
}
