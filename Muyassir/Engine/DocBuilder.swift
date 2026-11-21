import UIKit

/// Builds A4 PDFs from blocks with correct Arabic shaping and right-to-left layout (Core Text does the shaping).
final class DocBuilder {
    enum Block {
        case title(String, sub: String = "")
        case heading(String)
        case para(String, size: CGFloat = 11, bold: Bool = false, center: Bool = false, color: UIColor = DocBuilder.ink)
        case keyValues([(String, String)])
        case table(header: [String], rows: [[String]], weights: [CGFloat]? = nil)
        case image(UIImage, maxHeight: CGFloat = 300, center: Bool = true)
        case space(CGFloat)
        case rule
        case pageBreak
        case lines(Int, gap: CGFloat = 26)
    }

    static let ink = UIColor(red: 0.063, green: 0.098, blue: 0.208, alpha: 1)
    static let lapis = UIColor(red: 0.184, green: 0.294, blue: 1, alpha: 1)
    static let muted = UIColor(red: 0.357, green: 0.392, blue: 0.502, alpha: 1)
    static let line = UIColor(red: 0.85, green: 0.87, blue: 0.92, alpha: 1)

    let pw: CGFloat, ph: CGFloat
    let margin: CGFloat = 42
    var cw: CGFloat { pw - 2 * margin }
    var border: UIColor? = nil
    /// Text before the page number (free document tools: «أُنشئ بمُيسّر»); nil = page number only.
    var footer: String? = nil
    var pageNumbers = true
    /// Template: accent colour and layout (0 classic, 1 coloured header band, 2 side stripe, 3 formal centred).
    var accent: UIColor = DocBuilder.lapis
    var layoutStyle = 0
    var logo: UIImage? = nil
    /// Left-to-right document (English CV): text starts on the left and the accent bar sits on the left.
    var ltr = false
    private var blocks: [Block] = []

    init(landscape: Bool = false) { pw = landscape ? 842 : 595; ph = landscape ? 595 : 842 }

    func add(_ b: Block) { blocks.append(b) }
    func add(_ bs: [Block]) { blocks += bs }

    static func font(_ size: CGFloat, bold: Bool) -> UIFont {
        UIFont(name: bold ? "IBMPlexSansArabic-Bold" : "IBMPlexSansArabic-Regular", size: size) ?? .systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    private func attr(_ s: String, _ size: CGFloat, _ bold: Bool, _ color: UIColor, _ align: NSTextAlignment) -> NSAttributedString {
        let ps = NSMutableParagraphStyle()
        ps.baseWritingDirection = ltr ? .leftToRight : .rightToLeft
        ps.alignment = align
        ps.lineHeightMultiple = 1.15
        return NSAttributedString(string: s, attributes: [.font: Self.font(size, bold: bold), .foregroundColor: color, .paragraphStyle: ps])
    }

    func save(to url: URL) throws -> URL {
        let r = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pw, height: ph))
        try r.writePDF(to: url) { ctx in
            var y: CGFloat = 0, page = 0, titled = false, startY: CGFloat = 0
            func logoRow() {
                guard let l = logo else { return }
                let h: CGFloat = 54, w = l.size.width * h / l.size.height, k = min(1, 160 / w)
                l.draw(in: CGRect(x: margin, y: margin - 10, width: w * k, height: h * k)); y = margin + h * k + 6
            }
            func newPage() {
                if page > 0 { drawFooter(page) }
                ctx.beginPage(); page += 1; y = margin
                if layoutStyle == 2 { accent.setFill(); UIRectFill(CGRect(x: pw - 14, y: 0, width: 14, height: ph)) }
                if page == 1 && layoutStyle != 1 { logoRow() }
                if let c = border {
                    c.setStroke()
                    let p1 = UIBezierPath(rect: CGRect(x: 18, y: 18, width: pw - 36, height: ph - 36)); p1.lineWidth = 6; p1.stroke()
                    let p2 = UIBezierPath(rect: CGRect(x: 28, y: 28, width: pw - 56, height: ph - 56)); p2.lineWidth = 1.5; p2.stroke()
                    y = max(y, margin + 20)
                }
                startY = y
            }
            func drawFooter(_ n: Int) {
                let label = footer.map { "\($0)  •  \(n)" } ?? (pageNumbers ? "\(n)" : nil)
                if let label { attr(label, 8, false, Self.muted, .center).draw(in: CGRect(x: 0, y: ph - 26, width: pw, height: 14)) }
            }
            func ensure(_ h: CGFloat) { if y + h > ph - margin - 10 { newPage() } }
            /// Draws text, splitting long paragraphs over pages line by line.
            func text(_ a: NSAttributedString, x: CGFloat? = nil, width: CGFloat? = nil) {
                let w = width ?? cw, left = x ?? margin
                let setter = CTFramesetterCreateWithAttributedString(a)
                var start = 0
                while start < a.length {
                    ensure(20)
                    let avail = ph - margin - 10 - y
                    let path = CGPath(rect: CGRect(x: 0, y: 0, width: w, height: avail), transform: nil)
                    let frame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), path, nil)
                    let vis = CTFrameGetVisibleStringRange(frame)
                    if vis.length == 0 { newPage(); continue }
                    let sub = a.attributedSubstring(from: NSRange(location: start, length: vis.length))
                    let size = sub.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
                    sub.draw(with: CGRect(x: left, y: y, width: w, height: ceil(size.height) + 2), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    y += ceil(size.height); start += vis.length
                    if start < a.length { newPage() }
                }
            }
            func height(_ a: NSAttributedString, _ w: CGFloat) -> CGFloat { ceil(a.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height) }

            newPage()
            for b in blocks {
                var isTitle = false; if case .title = b { isTitle = true }
                // band layout needs a title first; otherwise fall back to the logo row
                if layoutStyle == 1 && page == 1 && !titled && y <= startY + 1 && !isTitle { logoRow(); titled = true }
                switch b {
                case let .title(t, sub) where layoutStyle == 1 && !titled && page == 1 && y <= startY + 1:
                    // coloured header band across the top of the first page
                    let inset: CGFloat = logo != nil ? 170 : 0
                    let ta = attr(t, 22, true, .white, .natural), sa = sub.isEmpty ? nil : attr(sub, 10.5, false, UIColor.white.withAlphaComponent(0.9), .natural)
                    let th = height(ta, cw - inset), sh = sa.map { height($0, cw - inset) } ?? 0
                    let band = 28 + th + sh + 22
                    accent.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: pw, height: band))
                    if let l = logo { let h: CGFloat = 54, w = l.size.width * h / l.size.height, k = min(1, 160 / w); l.draw(in: CGRect(x: margin, y: (band - h) / 2, width: w * k, height: h * k)) }
                    ta.draw(with: CGRect(x: margin + inset, y: 28, width: cw - inset, height: th + 4), options: .usesLineFragmentOrigin, context: nil)
                    sa?.draw(with: CGRect(x: margin + inset, y: 28 + th + 4, width: cw - inset, height: sh + 4), options: .usesLineFragmentOrigin, context: nil)
                    y = band + 22; titled = true
                case let .title(t, sub) where layoutStyle == 3:
                    text(attr(t, 22, true, Self.ink, .center)); y += 4
                    if !sub.isEmpty { text(attr(sub, 10.5, false, Self.muted, .center)) }
                    ensure(12); accent.setFill()
                    UIRectFill(CGRect(x: margin + cw * 0.2, y: y + 6, width: cw * 0.6, height: 1.2)); UIRectFill(CGRect(x: margin + cw * 0.2, y: y + 10, width: cw * 0.6, height: 1.2)); y += 24
                case let .title(t, sub):
                    text(attr(t, 22, true, Self.ink, .natural)); y += 4
                    if !sub.isEmpty { text(attr(sub, 10.5, false, Self.muted, .natural)) }
                    ensure(10); accent.setFill(); UIRectFill(CGRect(x: ltr ? margin : pw - margin - 56, y: y + 6, width: 56, height: 4)); y += 22; titled = true
                case let .heading(t): y += 6; text(attr(t, 14, true, accent, layoutStyle == 3 ? .center : .natural)); y += 6
                case let .para(t, size, bold, center, color): text(attr(t.isEmpty ? " " : t, size, bold, color, center ? .center : .natural)); y += 6
                case let .keyValues(rows):
                    for (k, v) in rows {
                        let ka = attr(k, 10.5, true, Self.muted, .natural), va = attr(v, 10.5, false, Self.ink, .natural)
                        let h = max(height(ka, cw * 0.32), height(va, cw * 0.66)) + 8
                        ensure(h)
                        ka.draw(with: CGRect(x: pw - margin - cw * 0.32, y: y, width: cw * 0.32, height: h), options: .usesLineFragmentOrigin, context: nil)
                        va.draw(with: CGRect(x: margin, y: y, width: cw * 0.66, height: h), options: .usesLineFragmentOrigin, context: nil)
                        y += h; Self.line.setFill(); UIRectFill(CGRect(x: margin, y: y - 4, width: cw, height: 0.5))
                    }
                case let .table(header, rows, weights):
                    let n = max(header.count, rows.map(\.count).max() ?? 0); if n == 0 { break }
                    let ws = weights ?? Array(repeating: 1, count: n); let sum = ws.reduce(0, +); let w = ws.map { $0 / sum * cw }
                    func row(_ cells: [String], head: Bool) {
                        let as_ = (0..<n).map { attr($0 < cells.count ? cells[$0] : "", 9.5, head, head ? .white : Self.ink, .natural) }
                        let h = (0..<n).map { height(as_[$0], w[$0] - 10) }.max()! + 10
                        ensure(h)
                        if head { accent.setFill(); UIRectFill(CGRect(x: margin, y: y, width: cw, height: h)) }
                        var x = pw - margin
                        for i in 0..<n { x -= w[i]; as_[i].draw(with: CGRect(x: x + 5, y: y + 5, width: w[i] - 10, height: h), options: .usesLineFragmentOrigin, context: nil) }
                        y += h; Self.line.setFill(); UIRectFill(CGRect(x: margin, y: y, width: cw, height: 0.5))
                    }
                    if !header.isEmpty { row(header, head: true) }
                    rows.forEach { row($0, head: false) }; y += 10
                case let .image(img, maxH, center):
                    let s = min(cw / img.size.width, maxH / img.size.height, 1.5)
                    let w = img.size.width * s, h = img.size.height * s
                    ensure(h + 6); img.draw(in: CGRect(x: center ? (pw - w) / 2 : pw - margin - w, y: y, width: w, height: h)); y += h + 8
                case let .space(h): y += h
                case .rule: ensure(10); Self.line.setFill(); UIRectFill(CGRect(x: margin, y: y + 4, width: cw, height: 1)); y += 12
                case .pageBreak: newPage()
                case let .lines(c, gap): for _ in 0..<c { ensure(gap); y += gap; Self.line.setFill(); UIRectFill(CGRect(x: margin, y: y, width: cw, height: 0.7)) }
                }
            }
            drawFooter(page)
        }
        return url
    }
}
