import PDFKit
import UIKit

enum PdfEngine {
    enum Failure: LocalizedError { case open, password, empty
        var errorDescription: String? { switch self { case .open: "تعذّر فتح ملف PDF"; case .password: "الملف محمي بكلمة مرور أو كلمة المرور غير صحيحة"; case .empty: "لا يمكن حذف جميع الصفحات" } }
    }

    /// Page text with Arabic presentation forms folded back to normal letters (NFKC).
    static func text(_ page: PDFPage) -> String { (page.string ?? "").precomposedStringWithCompatibilityMapping }

    static func open(_ url: URL, password: String? = nil) throws -> PDFDocument {
        guard let d = PDFDocument(url: url) else { throw Failure.open }
        if d.isLocked { guard let p = password, d.unlock(withPassword: p) else { throw Failure.password } }
        return d
    }

    static func parseRanges(_ spec: String, count: Int) -> [Int] {
        let arabic: [Character: Character] = ["٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9", "،": ",", "–": "-"]
        let norm = String(spec.map { arabic[$0] ?? $0 })
        var out: [Int] = []
        for part in norm.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !part.isEmpty {
            if part.contains("-") {
                let ab = part.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
                let s = Int(ab[0]) ?? 1, e = Int(ab.count > 1 ? ab[1] : "") ?? count
                let seq: [Int] = s <= e ? Array(s...e) : Array(stride(from: s, through: e, by: -1))
                out += seq.filter { (1...max(count, 1)).contains($0) }.map { $0 - 1 }
            } else if let p = Int(part), (1...max(count, 1)).contains(p) { out.append(p - 1) }
        }
        return out
    }

    /// New document from selected pages (copies keep text and vectors).
    static func select(_ d: PDFDocument, _ pages: [Int]) -> PDFDocument {
        let out = PDFDocument()
        for (i, p) in pages.enumerated() { if let pg = d.page(at: p)?.copy() as? PDFPage { out.insert(pg, at: i) } }
        return out
    }

    static func merge(_ urls: [URL]) throws -> PDFDocument {
        let out = PDFDocument()
        for u in urls { let d = try open(u); for i in 0..<d.pageCount { if let p = d.page(at: i)?.copy() as? PDFPage { out.insert(p, at: out.pageCount) } } }
        return out
    }

    static func write(_ d: PDFDocument, _ url: URL, options: [PDFDocumentWriteOption: Any] = [:]) throws -> URL {
        guard d.write(to: url, withOptions: options) else { throw Failure.open }
        return url
    }

    static func protect(_ url: URL, password: String, to out: URL) throws -> URL {
        let d = try open(url)
        return try write(d, out, options: [.userPasswordOption: password, .ownerPasswordOption: password + "#owner"])
    }

    static func unlock(_ url: URL, password: String, to out: URL) throws -> URL {
        let d = try open(url, password: password)
        return try write(select(d, Array(0..<d.pageCount)), out)
    }

    static func render(_ page: PDFPage, dpi: CGFloat) -> UIImage {
        let box = page.bounds(for: .mediaBox), s = dpi / 72
        let size = CGSize(width: min(box.width * s, 4000), height: min(box.height * s, 5600))
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height); ctx.cgContext.scaleBy(x: size.width / box.width, y: -size.height / box.height)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    /// Images → PDF (A4 with margins, or page = image size).
    static func fromImages(_ images: [UIImage], a4: Bool, to url: URL) throws -> URL {
        let r = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        try r.writePDF(to: url) { ctx in
            for img in images {
                let land = img.size.width > img.size.height
                let pr = a4 ? CGRect(x: 0, y: 0, width: land ? 842 : 595, height: land ? 595 : 842) : CGRect(origin: .zero, size: CGSize(width: img.size.width * 72 / 150, height: img.size.height * 72 / 150))
                ctx.beginPage(withBounds: pr, pageInfo: [:])
                let m: CGFloat = a4 ? 24 : 0
                let s = min((pr.width - 2 * m) / img.size.width, (pr.height - 2 * m) / img.size.height)
                let w = img.size.width * s, h = img.size.height * s
                img.draw(in: CGRect(x: (pr.width - w) / 2, y: (pr.height - h) / 2, width: w, height: h))
            }
        }
        return url
    }

    /// Rasterising compression: every page becomes a JPEG at the chosen dpi and quality.
    static func compress(_ url: URL, dpi: CGFloat, quality: CGFloat, to out: URL, progress: (Int, Int) -> Void) throws -> URL {
        let d = try open(url)
        let r = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        try r.writePDF(to: out) { ctx in
            for i in 0..<d.pageCount {
                progress(i, d.pageCount)
                autoreleasepool {
                    guard let p = d.page(at: i) else { return }
                    let box = p.bounds(for: .mediaBox)
                    let img = render(p, dpi: dpi)
                    guard let jpg = img.jpegData(compressionQuality: quality), let j = UIImage(data: jpg) else { return }
                    ctx.beginPage(withBounds: CGRect(origin: .zero, size: box.size), pageInfo: [:])
                    j.draw(in: CGRect(origin: .zero, size: box.size))
                }
            }
        }
        return out
    }

    /// Re-draws every page (vectors kept) and stamps an image on one page at a relative position.
    static func stamp(_ url: URL, page: Int, image: UIImage, rx: CGFloat, ry: CGFloat, rw: CGFloat, to out: URL) throws -> URL {
        let d = try open(url)
        let r = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        try r.writePDF(to: out) { ctx in
            for i in 0..<d.pageCount {
                guard let p = d.page(at: i) else { continue }
                let box = p.bounds(for: .mediaBox)
                ctx.beginPage(withBounds: CGRect(origin: .zero, size: box.size), pageInfo: [:])
                let cg = ctx.cgContext
                cg.saveGState(); cg.translateBy(x: 0, y: box.height); cg.scaleBy(x: 1, y: -1); p.draw(with: .mediaBox, to: cg); cg.restoreGState()
                if i == page {
                    let w = box.width * rw, h = w * image.size.height / max(image.size.width, 1)
                    image.draw(in: CGRect(x: box.width * rx, y: box.height * ry, width: w, height: h))
                }
            }
        }
        return out
    }
}
