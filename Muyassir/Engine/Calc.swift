import Foundation

/// Pure calculation rules shared by the Saudi, student and finance tools (mirrors the Android engine, covered by XCTest).
enum Calc {
    static let vatRate = 15.0

    struct Vat: Equatable { let net, vat, total: Double }
    static func vat(_ amount: Double, rate: Double = vatRate, inclusive: Bool) -> Vat {
        if inclusive { let net = amount / (1 + rate / 100); return Vat(net: net, vat: amount - net, total: amount) }
        let v = amount * rate / 100; return Vat(net: amount, vat: v, total: amount + v)
    }

    enum GosiSystem { case legacy, new }
    struct Gosi { let base, employee, employer, employeeRate, employerRate: Double }

    /// Base = basic + housing (cap 45,000; floor 1,500 for Saudis). Legacy: 9% pension + 0.75% SANED each, employer +2% hazards.
    /// New system (law M/273): pension share rises 0.5% every July (9.5% in 2026). Non-Saudi: employer 2% hazards only.
    static func gosi(basic: Double, housing: Double, saudi: Bool, system: GosiSystem = .legacy, newPension: Double = 9.5) -> Gosi {
        var base = min(basic + housing, 45000)
        if saudi { base = max(base, 1500) } else { return Gosi(base: base, employee: 0, employer: base * 0.02, employeeRate: 0, employerRate: 2) }
        let pension = system == .legacy ? 9.0 : newPension
        let e = pension + 0.75, r = pension + 2.75
        return Gosi(base: base, employee: base * e / 100, employer: base * r / 100, employeeRate: e, employerRate: r)
    }

    struct Salary { let gross, gosi, net: Double }
    static func salary(basic: Double, housing: Double, transport: Double, other: Double, saudi: Bool, system: GosiSystem, deductions: Double = 0) -> Salary {
        let gross = basic + housing + transport + other
        let g = gosi(basic: basic, housing: housing, saudi: saudi, system: system).employee
        return Salary(gross: gross, gosi: g, net: gross - g - deductions)
    }

    enum Leaving { case termination, resignation }
    struct Eos { let years, fullAward, payable, share: Double }
    /// Saudi Labor Law articles 84 and 85.
    static func endOfService(wage: Double, years: Int, months: Int, days: Int, how: Leaving) -> Eos {
        let total = Double(years) + Double(months) / 12 + Double(days) / 365
        let full = min(total, 5) * wage / 2 + max(total - 5, 0) * wage
        let share: Double
        if how == .termination { share = 1 } else if total < 2 { share = 0 } else if total < 5 { share = 1.0 / 3 } else if total < 10 { share = 2.0 / 3 } else { share = 1 }
        return Eos(years: total, fullAward: full, payable: full * share, share: share)
    }

    struct Leave { let entitlement: Int; let accrued, remaining, value: Double }
    static func leave(serviceYears: Double, monthsThisYear: Double, usedDays: Double, wage: Double) -> Leave {
        let ent = serviceYears >= 5 ? 30 : 21
        let acc = Double(ent) * min(max(monthsThisYear, 0), 12) / 12
        let rem = max(acc - usedDays, 0)
        return Leave(entitlement: ent, accrued: acc, remaining: rem, value: rem * wage / 30)
    }

    struct Loan { let monthly, totalPaid, profit, apr: Double }
    static func flatLoan(_ p: Double, annualFlat: Double, months: Int) -> Loan {
        let profit = p * annualFlat / 100 * Double(months) / 12, total = p + profit
        return Loan(monthly: total / Double(months), totalPaid: total, profit: profit, apr: aprFromPayment(p, payment: total / Double(months), months: months))
    }
    static func reducingLoan(_ p: Double, annualRate: Double, months: Int) -> Loan {
        let i = annualRate / 100 / 12, n = Double(months)
        let pay = i == 0 ? p / n : p * i / (1 - pow(1 + i, -n))
        return Loan(monthly: pay, totalPaid: pay * n, profit: pay * n - p, apr: annualRate)
    }
    static func aprFromPayment(_ p: Double, payment: Double, months: Int) -> Double {
        if payment * Double(months) <= p { return 0 }
        var lo = 0.0, hi = 1.0
        for _ in 0..<100 { let mid = (lo + hi) / 2; let v = p * mid / (1 - pow(1 + mid, -Double(months))); if v > payment { hi = mid } else { lo = mid } }
        return lo * 1200
    }

    struct Discount { let saving, final, effectivePct: Double }
    static func discount(_ price: Double, _ pcts: [Double]) -> Discount {
        let f = pcts.reduce(price) { $0 * (1 - $1 / 100) }
        return Discount(saving: price - f, final: f, effectivePct: price == 0 ? 0 : (price - f) / price * 100)
    }

    struct Course { let points, hours: Double }
    static func gpa(_ c: [Course], prevGpa: Double = 0, prevHours: Double = 0) -> (Double, Double) {
        let h = c.reduce(0) { $0 + $1.hours }
        let sem = h == 0 ? 0 : c.reduce(0) { $0 + $1.points * $1.hours } / h
        let th = h + prevHours
        return (sem, th == 0 ? 0 : (sem * h + prevGpa * prevHours) / th)
    }
    static let letters = ["A+", "A", "B+", "B", "C+", "C", "D+", "D", "F"]
    static func points(_ l: String, scale5: Bool) -> Double {
        let five: [String: Double] = ["A+": 5, "A": 4.75, "B+": 4.5, "B": 4, "C+": 3.5, "C": 3, "D+": 2.5, "D": 2, "F": 1]
        let four: [String: Double] = ["A+": 4, "A": 3.75, "B+": 3.5, "B": 3, "C+": 2.5, "C": 2, "D+": 1.5, "D": 1, "F": 0]
        return (scale5 ? five : four)[l] ?? 0
    }
    static func gradeWord(_ p: Double) -> String { p >= 90 ? "ممتاز" : p >= 80 ? "جيد جدًا" : p >= 70 ? "جيد" : p >= 60 ? "مقبول" : "راسب" }
}
