import Foundation

/// Minimal Office Open XML writers/readers (DOCX, XLSX, PPTX) — same output as the Android engine.
enum Office {
    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .filter { $0 == "\t" || $0 == "\n" || $0 == "\r" || ($0.unicodeScalars.first?.value ?? 0) >= 0x20 }
    }
    static func unesc(_ s: String) -> String {
        var r = s.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&apos;", with: "'")
        while let m = r.range(of: "&#[0-9]+;", options: .regularExpression) {
            let n = Int(r[m].dropFirst(2).dropLast()) ?? 32; r.replaceSubrange(m, with: String(UnicodeScalar(n).map(Character.init) ?? " "))
        }
        return r.replacingOccurrences(of: "&amp;", with: "&")
    }
    static func hasArabic(_ s: String) -> Bool { s.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0xFB50...0xFEFF).contains($0.value) } }

    static func matches(_ pattern: String, _ s: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
        }
    }

    private static let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
    private static let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

    // MARK: DOCX
    enum Para { case text(String, heading: Int = 0, bold: Bool = false), table([[String]]), pageBreak }

    static func writeDocx(_ url: URL, _ paras: [Para]) throws {
        var body = ""
        for p in paras {
            switch p {
            case let .text(t, heading, bold):
                let rtl = hasArabic(t), size = [24, 36, 30, 26][min(heading, 3)], b = bold || heading > 0
                body += "<w:p><w:pPr>\(rtl ? "<w:bidi/><w:jc w:val=\"right\"/>" : "")<w:spacing w:after=\"120\"/></w:pPr>"
                for (i, line) in t.components(separatedBy: "\n").enumerated() {
                    if i > 0 { body += "<w:r><w:br/></w:r>" }
                    body += "<w:r><w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/>\(b ? "<w:b/><w:bCs/>" : "")\(rtl ? "<w:rtl/>" : "")<w:sz w:val=\"\(size)\"/><w:szCs w:val=\"\(size)\"/></w:rPr><w:t xml:space=\"preserve\">\(esc(line))</w:t></w:r>"
                }
                body += "</w:p>"
            case let .table(rows):
                let rtl = rows.joined().contains(where: hasArabic)
                body += "<w:tbl><w:tblPr>\(rtl ? "<w:bidiVisual/>" : "")<w:tblW w:w=\"5000\" w:type=\"pct\"/><w:tblBorders>"
                for side in ["top", "left", "bottom", "right", "insideH", "insideV"] { body += "<w:\(side) w:val=\"single\" w:sz=\"4\" w:color=\"BFC6D9\"/>" }
                body += "</w:tblBorders></w:tblPr>"
                for r in rows {
                    body += "<w:tr>"
                    for c in r { let a = hasArabic(c); body += "<w:tc><w:p><w:pPr>\(a ? "<w:bidi/>" : "")</w:pPr><w:r><w:rPr>\(a ? "<w:rtl/>" : "")</w:rPr><w:t xml:space=\"preserve\">\(esc(c))</w:t></w:r></w:p></w:tc>" }
                    body += "</w:tr>"
                }
                body += "</w:tbl><w:p/>"
            case .pageBreak: body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
            }
        }
        try Zip.write([
            ("[Content_Types].xml", Data((xml + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>").utf8)),
            ("_rels/.rels", Data((xml + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"\(rel)/officeDocument\" Target=\"word/document.xml\"/></Relationships>").utf8)),
            ("word/document.xml", Data((xml + "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\(body)<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1134\" w:right=\"1134\" w:bottom=\"1134\" w:left=\"1134\" w:header=\"708\" w:footer=\"708\" w:gutter=\"0\"/></w:sectPr></w:body></w:document>").utf8)),
        ], to: url)
    }

    private static func runs(_ x: String) -> String {
        matches("<w:t(?: [^>]*)?>(.*?)</w:t>|<w:tab/>|<w:br[^>]*/>", x).map { m in
            m[0].hasPrefix("<w:tab") ? "\t" : m[0].hasPrefix("<w:br") ? "\n" : unesc(m[1])
        }.joined()
    }

    static func readDocx(_ url: URL) throws -> [String] {
        guard let doc = try Zip.read(url).first(where: { $0.0 == "word/document.xml" }) else { return [] }
        let x = String(decoding: doc.1, as: UTF8.self)
        return matches("<w:tbl>.*?</w:tbl>|<w:p[ >].*?</w:p>|<w:p/>", x).flatMap { m -> [String] in
            if m[0].hasPrefix("<w:tbl") {
                return matches("<w:tr[ >].*?</w:tr>", m[0]).map { tr in matches("<w:tc[ >].*?</w:tc>", tr[0]).map { runs($0[0]) }.joined(separator: "\t") }
            }
            return [runs(m[0])]
        }
    }

    // MARK: XLSX
    static func colName(_ i: Int) -> String { var n = i + 1, s = ""; while n > 0 { let r = (n - 1) % 26; s = String(UnicodeScalar(65 + r)!) + s; n = (n - 1) / 26 }; return s }

    static func writeXlsx(_ url: URL, _ sheets: [(String, [[String]])], rtl: Bool = true) throws {
        var entries: [(String, Data)] = [], wb = "", wbRels = "", ct = ""
        for (si, sheet) in sheets.enumerated() {
            let n = si + 1; var sd = ""
            for (r, row) in sheet.1.enumerated() {
                sd += "<row r=\"\(r + 1)\">"
                for (c, v) in row.enumerated() {
                    let ref = colName(c) + "\(r + 1)", t = v.trimmingCharacters(in: .whitespaces)
                    if t.range(of: "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?$", options: .regularExpression) != nil && t.count < 16 { sd += "<c r=\"\(ref)\"><v>\(t)</v></c>" }
                    else if !v.isEmpty { sd += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(esc(v))</t></is></c>" }
                }
                sd += "</row>"
            }
            entries.append(("xl/worksheets/sheet\(n).xml", Data((xml + "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetViews><sheetView workbookViewId=\"0\"\(rtl ? " rightToLeft=\"1\"" : "")/></sheetViews><sheetData>\(sd)</sheetData></worksheet>").utf8)))
            let safe = String(sheet.0.prefix(31)).replacingOccurrences(of: "[\\\\/?*\\[\\]:]", with: " ", options: .regularExpression)
            wb += "<sheet name=\"\(esc(safe))\" sheetId=\"\(n)\" r:id=\"rId\(n)\"/>"
            wbRels += "<Relationship Id=\"rId\(n)\" Type=\"\(rel)/worksheet\" Target=\"worksheets/sheet\(n).xml\"/>"
            ct += "<Override PartName=\"/xl/worksheets/sheet\(n).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        entries.insert(("[Content_Types].xml", Data((xml + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>\(ct)</Types>").utf8)), at: 0)
        entries.append(("_rels/.rels", Data((xml + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"\(rel)/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>").utf8)))
        entries.append(("xl/workbook.xml", Data((xml + "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"\(rel)\"><sheets>\(wb)</sheets></workbook>").utf8)))
        entries.append(("xl/_rels/workbook.xml.rels", Data((xml + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(wbRels)</Relationships>").utf8)))
        try Zip.write(entries, to: url)
    }

    static func readXlsx(_ url: URL) throws -> [(String, [[String]])] {
        let files = Dictionary(try Zip.read(url).map { ($0.0, String(decoding: $0.1, as: UTF8.self)) }, uniquingKeysWith: { a, _ in a })
        let shared = matches("<si>(.*?)</si>", files["xl/sharedStrings.xml"] ?? "").map { si in matches("<t(?: [^>]*)?>(.*?)</t>", si[1]).map { unesc($0[1]) }.joined() }
        let rels = files["xl/_rels/workbook.xml.rels"] ?? ""
        return matches("<sheet [^>]*name=\"([^\"]*)\"[^>]*r:id=\"([^\"]*)\"", files["xl/workbook.xml"] ?? "").compactMap { s in
            guard let t = matches("<Relationship [^>]*Id=\"\(s[2])\"[^>]*>", rels).first?[0], let target = matches("Target=\"([^\"]*)\"", t).first?[1] else { return nil }
            let path = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target.replacingOccurrences(of: "./", with: "")
            guard let x = files[path] else { return nil }
            let rows = matches("<row[^>]*>(.*?)</row>", x).map { row -> [String] in
                var cells: [String] = []
                for c in matches("<c ([^>]*?)(?:/>|>(.*?)</c>)", row[1]) {
                    let attrs = c[1], inner = c[2]
                    if let ref = matches("r=\"([A-Z]+)[0-9]+\"", attrs).first?[1] {
                        let idx = ref.unicodeScalars.reduce(0) { $0 * 26 + Int($1.value) - 64 } - 1
                        while cells.count < idx { cells.append("") }
                    }
                    let type = matches("t=\"([^\"]*)\"", attrs).first?[1]
                    let v = matches("<v>(.*?)</v>", inner).first?[1]
                    switch type {
                    case "s": cells.append(Int(v ?? "").flatMap { $0 < shared.count ? shared[$0] : nil } ?? "")
                    case "inlineStr": cells.append(matches("<t(?: [^>]*)?>(.*?)</t>", inner).map { unesc($0[1]) }.joined())
                    case "b": cells.append(v == "1" ? "TRUE" : "FALSE")
                    default:
                        if let v, let d = Double(v) { cells.append(d == d.rounded() && abs(d) < 1e15 ? String(Int64(d)) : String(d)) } else { cells.append(unesc(v ?? "")) }
                    }
                }
                return cells
            }
            return (unesc(s[1]), rows)
        }
    }

    // MARK: PPTX
    struct Slide { var title: String; var body: String = ""; var png: Data? = nil; var w = 0; var h = 0 }

    static func writePptx(_ url: URL, _ slides: [Slide]) throws {
        let cx = 12192000, cy = 6858000
        let ns = "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"\(rel)\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\""
        var e: [(String, Data)] = [], ct = "", presRels = "<Relationship Id=\"rIdM\" Type=\"\(rel)/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/><Relationship Id=\"rIdT\" Type=\"\(rel)/theme\" Target=\"theme/theme1.xml\"/>", ids = ""
        func box(_ id: Int, _ y: Int, _ h: Int, _ text: String, _ size: Int, _ bold: Bool) -> String {
            let rtl = hasArabic(text)
            let paras = text.components(separatedBy: "\n").map { "<a:p><a:pPr algn=\"\(rtl ? "r" : "l")\" rtl=\"\(rtl ? 1 : 0)\"/><a:r><a:rPr lang=\"\(rtl ? "ar-SA" : "en-US")\" sz=\"\(size)\" b=\"\(bold ? 1 : 0)\"/><a:t>\(esc($0))</a:t></a:r></a:p>" }.joined()
            return "<p:sp><p:nvSpPr><p:cNvPr id=\"\(id)\" name=\"Text \(id)\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"457200\" y=\"\(y)\"/><a:ext cx=\"\(cx - 914400)\" cy=\"\(h)\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr><p:txBody><a:bodyPr wrap=\"square\"/><a:lstStyle/>\(paras)</p:txBody></p:sp>"
        }
        for (i, s) in slides.enumerated() {
            let n = i + 1
            var rels = "<Relationship Id=\"rId1\" Type=\"\(rel)/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>", shapes = ""
            if let png = s.png {
                e.append(("ppt/media/image\(n).png", png))
                rels += "<Relationship Id=\"rId2\" Type=\"\(rel)/image\" Target=\"../media/image\(n).png\"/>"
                let sc = min(Double(cx) / Double(s.w), Double(cy) / Double(s.h)); let w = Int(Double(s.w) * sc), h = Int(Double(s.h) * sc)
                shapes = "<p:pic><p:nvPicPr><p:cNvPr id=\"2\" name=\"Page \(n)\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed=\"rId2\"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x=\"\((cx - w) / 2)\" y=\"\((cy - h) / 2)\"/><a:ext cx=\"\(w)\" cy=\"\(h)\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr></p:pic>"
            } else {
                shapes = box(2, 457200, 1143000, s.title, 3600, true) + (s.body.isEmpty ? "" : box(3, 1714500, cy - 2171700, s.body, 2000, false))
            }
            e.append(("ppt/slides/slide\(n).xml", Data((xml + "<p:sld \(ns)><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>\(shapes)</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>").utf8)))
            e.append(("ppt/slides/_rels/slide\(n).xml.rels", Data((xml + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(rels)</Relationships>").utf8)))
            ct += "<Override PartName=\"/ppt/slides/slide\(n).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>"
            presRels += "<Relationship Id=\"rId\(n)\" Type=\"\(rel)/slide\" Target=\"slides/slide\(n).xml\"/>"
            ids += "<p:sldId id=\"\(255 + n)\" r:id=\"rId\(n)\"/>"
        }
        let tree = "<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>"
        let relsHead = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        e += [
            ("ppt/slideMasters/slideMaster1.xml", Data((xml + "<p:sldMaster \(ns)>\(tree)<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\" accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\" hlink=\"hlink\" folHlink=\"folHlink\"/><p:sldLayoutIdLst><p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/></p:sldLayoutIdLst></p:sldMaster>").utf8)),
            ("ppt/slideMasters/_rels/slideMaster1.xml.rels", Data((xml + relsHead + "<Relationship Id=\"rId1\" Type=\"\(rel)/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/><Relationship Id=\"rId2\" Type=\"\(rel)/theme\" Target=\"../theme/theme1.xml\"/></Relationships>").utf8)),
            ("ppt/slideLayouts/slideLayout1.xml", Data((xml + "<p:sldLayout \(ns) type=\"blank\">\(tree)<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>").utf8)),
            ("ppt/slideLayouts/_rels/slideLayout1.xml.rels", Data((xml + relsHead + "<Relationship Id=\"rId1\" Type=\"\(rel)/slideMaster\" Target=\"../slideMasters/slideMaster1.xml\"/></Relationships>").utf8)),
            ("ppt/theme/theme1.xml", Data((xml + theme).utf8)),
            ("ppt/presentation.xml", Data((xml + "<p:presentation \(ns)><p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"rIdM\"/></p:sldMasterIdLst><p:sldIdLst>\(ids)</p:sldIdLst><p:sldSz cx=\"\(cx)\" cy=\"\(cy)\"/><p:notesSz cx=\"6858000\" cy=\"9144000\"/></p:presentation>").utf8)),
            ("ppt/_rels/presentation.xml.rels", Data((xml + relsHead + presRels + "</Relationships>").utf8)),
            ("_rels/.rels", Data((xml + relsHead + "<Relationship Id=\"rId1\" Type=\"\(rel)/officeDocument\" Target=\"ppt/presentation.xml\"/></Relationships>").utf8)),
            ("[Content_Types].xml", Data((xml + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Default Extension=\"png\" ContentType=\"image/png\"/><Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/><Override PartName=\"/ppt/slideMasters/slideMaster1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml\"/><Override PartName=\"/ppt/slideLayouts/slideLayout1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml\"/><Override PartName=\"/ppt/theme/theme1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/>\(ct)</Types>").utf8)),
        ]
        try Zip.write(e, to: url)
    }

    static func readPptx(_ url: URL) throws -> [String] {
        let files = try Zip.read(url).filter { $0.0.range(of: "^ppt/slides/slide[0-9]+\\.xml$", options: .regularExpression) != nil }
        return files.sorted { Int($0.0.filter(\.isNumber)) ?? 0 < Int($1.0.filter(\.isNumber)) ?? 0 }.map { f in
            matches("<a:p(?: [^>]*)?>(.*?)</a:p>", String(decoding: f.1, as: UTF8.self)).map { p in matches("<a:t>(.*?)</a:t>", p[1]).map { unesc($0[1]) }.joined() }
                .filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }

    private static let theme = "<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" name=\"Muyassir\"><a:themeElements><a:clrScheme name=\"Muyassir\"><a:dk1><a:srgbClr val=\"101935\"/></a:dk1><a:lt1><a:srgbClr val=\"FFFFFF\"/></a:lt1><a:dk2><a:srgbClr val=\"1F2A4D\"/></a:dk2><a:lt2><a:srgbClr val=\"F3F5FA\"/></a:lt2><a:accent1><a:srgbClr val=\"2F4BFF\"/></a:accent1><a:accent2><a:srgbClr val=\"12C29A\"/></a:accent2><a:accent3><a:srgbClr val=\"FFC23D\"/></a:accent3><a:accent4><a:srgbClr val=\"7A5CFF\"/></a:accent4><a:accent5><a:srgbClr val=\"FF6B8A\"/></a:accent5><a:accent6><a:srgbClr val=\"23B5E8\"/></a:accent6><a:hlink><a:srgbClr val=\"2F4BFF\"/></a:hlink><a:folHlink><a:srgbClr val=\"7A5CFF\"/></a:folHlink></a:clrScheme><a:fontScheme name=\"Muyassir\"><a:majorFont><a:latin typeface=\"Arial\"/><a:ea typeface=\"\"/><a:cs typeface=\"Arial\"/></a:majorFont><a:minorFont><a:latin typeface=\"Arial\"/><a:ea typeface=\"\"/><a:cs typeface=\"Arial\"/></a:minorFont></a:fontScheme><a:fmtScheme name=\"Muyassir\"><a:fillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w=\"9525\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln><a:ln w=\"12700\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln><a:ln w=\"19050\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>"
}
