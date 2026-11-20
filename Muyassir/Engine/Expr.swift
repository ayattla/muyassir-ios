import Foundation

/// Recursive-descent evaluator for the scientific calculator.
struct Expr {
    enum Failure: Error { case bad(String) }
    private let s: [Character]
    private var pos = 0
    private let degrees: Bool

    init(_ src: String, degrees: Bool = true) {
        s = Array(src.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "π", with: "pi").replacingOccurrences(of: "√", with: "sqrt").replacingOccurrences(of: " ", with: ""))
        self.degrees = degrees
    }

    static func eval(_ src: String, degrees: Bool = true) throws -> Double {
        var e = Expr(src, degrees: degrees)
        let v = try e.expr()
        if e.pos < e.s.count { throw Failure.bad("رمز غير متوقع") }
        return v
    }

    private var peek: Character { pos < s.count ? s[pos] : "\0" }
    private mutating func eat(_ c: Character) -> Bool { if peek == c { pos += 1; return true }; return false }

    private mutating func expr() throws -> Double {
        var v = try term()
        while true { if eat("+") { v += try term() } else if eat("-") { v -= try term() } else { return v } }
    }
    private mutating func term() throws -> Double {
        var v = try unary()
        while true { if eat("*") { v *= try unary() } else if eat("/") { v /= try unary() } else { return v } }
    }
    private mutating func unary() throws -> Double {
        if eat("-") { return -(try unary()) }
        if eat("+") { return try unary() }
        return try power()
    }
    private mutating func power() throws -> Double {
        let b = try postfix(try primary())
        return eat("^") ? pow(b, try unary()) : b
    }
    private mutating func postfix(_ v0: Double) throws -> Double {
        var v = v0
        while true {
            if eat("!") { guard v >= 0, v == v.rounded(), v <= 170 else { throw Failure.bad("المضروب") }; v = (1...max(Int(v), 1)).reduce(1.0) { $0 * Double($1) } }
            else if eat("%") { v /= 100 } else { return v }
        }
    }
    private mutating func primary() throws -> Double {
        if eat("(") { let v = try expr(); guard eat(")") else { throw Failure.bad("قوس ناقص") }; return v }
        let start = pos
        if peek.isNumber || peek == "." {
            while peek.isNumber || peek == "." { pos += 1 }
            if peek == "e" || peek == "E" {
                let save = pos; pos += 1
                if peek == "-" || peek == "+" { pos += 1 }
                if peek.isNumber { while peek.isNumber { pos += 1 } } else { pos = save }
            }
            guard let d = Double(String(s[start..<pos])) else { throw Failure.bad("رقم") }
            return d
        }
        while peek.isLetter { pos += 1 }
        let name = String(s[start..<pos]).lowercased()
        if name.isEmpty { throw Failure.bad("تعبير غير مكتمل") }
        if name == "pi" { return .pi }
        if name == "e" { return M_E }
        let a = try primary(), r = degrees ? a * .pi / 180 : a
        func back(_ x: Double) -> Double { degrees ? x * 180 / .pi : x }
        switch name {
        case "sin": return sin(r)
        case "cos": return cos(r)
        case "tan": return tan(r)
        case "asin": return back(asin(a))
        case "acos": return back(acos(a))
        case "atan": return back(atan(a))
        case "sqrt": return sqrt(a)
        case "log": return log10(a)
        case "ln": return log(a)
        case "abs": return abs(a)
        case "exp": return exp(a)
        default: throw Failure.bad("دالة غير معروفة")
        }
    }
}
