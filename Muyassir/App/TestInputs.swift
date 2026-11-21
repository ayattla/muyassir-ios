#if DEBUG
import UIKit

/// Debug-only: builds real sample files for the automated UI tests (passed via the MYS_TEST_INPUTS environment variable).
/// Spec is a comma list such as "pdf3,pdf1", "png,png", "docx", "xlsx", "pptx", "zip", "locked".
enum TestInputs {
    static func make(_ spec: String) -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("in/test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return spec.split(separator: ",").enumerated().compactMap { i, k in try? one(String(k), dir.appendingPathComponent("\(i)")) }
    }
    static func pdf(_ pages: Int, _ url: URL) throws -> URL {
        let b = DocBuilder()
        for p in 1...max(pages, 1) { if p > 1 { b.add(.pageBreak) }; b.add(.title("صفحة \(p)")); b.add(.para("نص تجريبي عربي Test \(p)")) }
        return try b.save(to: url)
    }
    static func image() -> UIImage {
        ImageEngine.redraw(CGSize(width: 900, height: 700)) { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 900, height: 700))
            UIColor(red: 0.18, green: 0.29, blue: 1, alpha: 1).setFill(); c.fillEllipse(in: CGRect(x: 280, y: 180, width: 340, height: 340))
            ("Muyassir 2026" as NSString).draw(at: CGPoint(x: 60, y: 60), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 80), .foregroundColor: UIColor.black])
        }
    }
    /// A simple portrait: a dark figure on a light studio-like background.
    static func person() -> UIImage {
        ImageEngine.redraw(CGSize(width: 800, height: 1000)) { c in
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(white: 0.93, alpha: 1).cgColor, UIColor(white: 0.80, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 1000), options: [])
            UIColor(red: 0.85, green: 0.65, blue: 0.5, alpha: 1).setFill(); c.fillEllipse(in: CGRect(x: 290, y: 180, width: 220, height: 270))
            UIColor(red: 0.15, green: 0.2, blue: 0.45, alpha: 1).setFill()
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 160, y: 470, width: 480, height: 600), cornerRadius: 200).cgPath); c.fillPath()
        }
    }
    private static func one(_ k: String, _ base: URL) throws -> URL {
        switch k {
        case let s where s.hasPrefix("pdf"): return try pdf(Int(s.dropFirst(3)) ?? 1, base.appendingPathExtension("pdf"))
        case "qr": return try ImageEngine.save(ImageEngine.qr("https://ayattla.com/muyassir", size: 600), .png, quality: 1, to: base.appendingPathExtension("png"))
        case "person": return try ImageEngine.save(person(), .png, quality: 1, to: base.appendingPathExtension("png"))
        case "png": return try ImageEngine.save(image(), .png, quality: 1, to: base.appendingPathExtension("png"))
        case "docx": let u = base.appendingPathExtension("docx"); try Office.writeDocx(u, [.text("عنوان", heading: 1), .text("فقرة عربية")]); return u
        case "xlsx": let u = base.appendingPathExtension("xlsx"); try Office.writeXlsx(u, [("ورقة", [["الاسم", "المبلغ"], ["سارة", "10"]])]); return u
        case "pptx": let u = base.appendingPathExtension("pptx"); try Office.writePptx(u, [Office.Slide(title: "شريحة", body: "نقطة 1\nنقطة 2")]); return u
        case "zip": let u = base.appendingPathExtension("zip"); try Zip.write([("ملف.txt", Data("مرحبا".utf8))], to: u); return u
        case "locked": let p = try pdf(1, base.appendingPathExtension("src.pdf")); return try PdfEngine.protect(p, password: "1234", to: base.appendingPathExtension("pdf"))
        default: throw UserError("unknown test input \(k)")
        }
    }
}
#endif
