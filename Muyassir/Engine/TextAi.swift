import Foundation

/// On-device text intelligence that works for Arabic on every device with no model download:
/// extractive summaries (the most informative sentences, in reading order) and fill-in-the-blank review questions.
enum TextAi {
    static let stop: Set<String> = [
        "في", "من", "على", "الى", "إلى", "عن", "مع", "هذا", "هذه", "ذلك", "تلك", "التي", "الذي", "الذين", "ان", "أن", "إن", "كان", "كانت", "يكون",
        "او", "أو", "ثم", "قد", "لقد", "كما", "لكن", "حتى", "عند", "كل", "بعض", "غير", "بين", "هو", "هي", "هم", "نحن", "انت", "أنت", "لا", "لم", "لن",
        "ما", "ماذا", "متى", "اين", "أين", "كيف", "وهو", "وهي", "و", "ف", "ب", "ل", "به", "بها", "له", "لها", "فيه", "فيها", "منه", "منها", "عليه", "عليها",
        "the", "a", "an", "and", "or", "of", "to", "in", "on", "for", "is", "are", "was", "were", "be", "it", "this", "that", "with", "as", "by", "at", "from",
    ].reduce(into: Set<String>()) { $0.insert(norm($1)) }

    static func trimWord(_ w: String) -> String { w.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }

    static func norm(_ w: String) -> String {
        var s = w.lowercased()
        s = s.replacingOccurrences(of: "[\\u064B-\\u0652\\u0640]", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "[أإآ]", with: "ا", options: .regularExpression)
        s = s.replacingOccurrences(of: "ى", with: "ي").replacingOccurrences(of: "ة", with: "ه")
        return trimWord(s)
    }

    static func tokens(_ s: String) -> [String] { s.split(whereSeparator: { $0.isWhitespace }).map(String.init) }

    static func sentences(_ text: String) -> [String] {
        let t = text.replacingOccurrences(of: "\r", with: "")
        let marked = t.replacingOccurrences(of: "([.!?؟])\\s+", with: "$1\u{1}", options: .regularExpression).replacingOccurrences(of: "\n+", with: "\u{1}", options: .regularExpression)
        return marked.split(separator: "\u{1}").map { $0.trimmingCharacters(in: .whitespaces) }.filter { tokens($0).count >= 4 }
    }

    private static func words(_ s: String) -> [String] { tokens(s).map(norm).filter { $0.count >= 2 && !stop.contains($0) } }
    private static func freq(_ all: [String]) -> [String: Int] { var f: [String: Int] = [:]; for s in all { for w in words(s) { f[w, default: 0] += 1 } }; return f }

    /// The most representative sentences (about a quarter of the text, 3–8), in reading order.
    static func summarize(_ text: String, max: Int = 0) -> [String] {
        let ss = sentences(text); if ss.count <= 3 { return ss }
        let f = freq(ss), n = max > 0 ? max : min(8, Swift.max(3, ss.count / 4))
        let scored = ss.enumerated().map { i, s -> (Int, String, Double) in
            let w = words(s); let score = Double(w.reduce(0) { $0 + (f[$1] ?? 0) }) / pow(Double(Swift.max(1, w.count)), 0.6)
            return (i, s, score + (i == 0 ? 0.5 : 0))
        }
        return scored.sorted { $0.2 > $1.2 }.prefix(n).sorted { $0.0 < $1.0 }.map(\.1)
    }

    static func keywords(_ text: String, n: Int = 12) -> [String] {
        let ss = sentences(text), f = freq(ss.isEmpty ? [text] : ss)
        return f.filter { $0.key.count >= 4 && $0.key.contains(where: \.isLetter) }.sorted { ($0.value * $0.key.count, $1.key) > ($1.value * $1.key.count, $0.key) }.prefix(n).map(\.key)
    }

    struct Question: Identifiable { let id = UUID(); let text: String; let answer: String; let options: [String] }

    /// Fill-in-the-blank questions with four choices, from sentences that contain a key term.
    static func quiz(_ text: String, count: Int = 10, seed: UInt64 = 7) -> [Question] {
        let ss = sentences(text), keys = keywords(text, n: 30); if keys.count < 2 { return [] }
        var rng = Seeded(seed); var out: [Question] = []; var used = Set<String>()
        let allTokens = ss.flatMap(tokens).map(trimWord)
        for s in ss {
            if out.count >= count { break }
            var tk = tokens(s)
            guard let idx = tk.firstIndex(where: { keys.contains(norm($0)) && !used.contains(norm($0)) }) else { continue }
            let word = trimWord(tk[idx]), key = norm(word); used.insert(key)
            tk[idx] = tk[idx].replacingOccurrences(of: word, with: "……")
            let others = keys.filter { $0 != key }.shuffled(using: &rng).prefix(3)
            let opts = (others.map { o in allTokens.first { norm($0) == o } ?? o } + [word]).shuffled(using: &rng)
            out.append(Question(text: tk.joined(separator: " "), answer: word, options: opts))
        }
        return out
    }

    struct Seeded: RandomNumberGenerator { var s: UInt64; init(_ v: UInt64) { s = v &+ 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 { s &+= 0x9E3779B97F4A7C15; var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) } }
}
