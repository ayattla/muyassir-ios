import Foundation
import Compression

/// Small, dependency-free ZIP writer/reader (store + deflate) used by the ZIP tool and the Office writers/readers.
enum Zip {
    enum ZipError: Error { case corrupt, unsupported }

    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i); for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }; return c
    }
    static func crc32(_ d: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        d.withUnsafeBytes { (p: UnsafeRawBufferPointer) in for b in p { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) } }
        return c ^ 0xFFFFFFFF
    }

    private static func deflate(_ d: Data) -> Data? {
        if d.isEmpty { return Data() }
        let cap = d.count + 1024
        var out = Data(count: cap)
        let n = out.withUnsafeMutableBytes { (o: UnsafeMutableRawBufferPointer) -> Int in
            d.withUnsafeBytes { (i: UnsafeRawBufferPointer) in
                compression_encode_buffer(o.bindMemory(to: UInt8.self).baseAddress!, cap, i.bindMemory(to: UInt8.self).baseAddress!, d.count, nil, COMPRESSION_ZLIB)
            }
        }
        return n == 0 ? nil : out.prefix(n)
    }

    private static func inflate(_ d: Data, size: Int) -> Data? {
        if size == 0 { return Data() }
        var out = Data(count: size)
        let n = out.withUnsafeMutableBytes { (o: UnsafeMutableRawBufferPointer) -> Int in
            d.withUnsafeBytes { (i: UnsafeRawBufferPointer) in
                compression_decode_buffer(o.bindMemory(to: UInt8.self).baseAddress!, size, i.bindMemory(to: UInt8.self).baseAddress!, d.count, nil, COMPRESSION_ZLIB)
            }
        }
        return n == size ? out : nil
    }

    private static func le16(_ v: Int) -> Data { var x = UInt16(truncatingIfNeeded: v).littleEndian; return Data(bytes: &x, count: 2) }
    private static func le32(_ v: UInt32) -> Data { var x = v.littleEndian; return Data(bytes: &x, count: 4) }

    /// Writes entries in order. `compress` = deflate (falls back to store when it does not help).
    static func write(_ entries: [(String, Data)], to url: URL, compress: Bool = true) throws {
        var out = Data(), central = Data()
        var used = Set<String>()
        for (rawName, data) in entries {
            var name = rawName, k = 1
            while !used.insert(name).inserted { let ext = (rawName as NSString).pathExtension; let base = (rawName as NSString).deletingPathExtension; name = "\(base) (\(k)).\(ext)"; k += 1 }
            let nameData = Data(name.utf8)
            let crc = crc32(data)
            var method = 0, body = data
            if compress, let d = deflate(data), d.count < data.count { method = 8; body = d }
            let offset = UInt32(out.count)
            var local = Data([0x50, 0x4B, 0x03, 0x04]); local += le16(20); local += le16(0x0800); local += le16(method); local += le16(0); local += le16(0x21)
            local += le32(crc); local += le32(UInt32(body.count)); local += le32(UInt32(data.count)); local += le16(nameData.count); local += le16(0)
            out += local; out += nameData; out += body
            var c = Data([0x50, 0x4B, 0x01, 0x02]); c += le16(20); c += le16(20); c += le16(0x0800); c += le16(method); c += le16(0); c += le16(0x21)
            c += le32(crc); c += le32(UInt32(body.count)); c += le32(UInt32(data.count)); c += le16(nameData.count); c += le16(0); c += le16(0); c += le16(0); c += le16(0)
            c += le32(0); c += le32(offset); c += nameData
            central += c
        }
        let cdOffset = UInt32(out.count)
        out += central
        var end = Data([0x50, 0x4B, 0x05, 0x06]); end += le16(0); end += le16(0); end += le16(entries.count); end += le16(entries.count)
        end += le32(UInt32(central.count)); end += le32(cdOffset); end += le16(0)
        out += end
        try out.write(to: url)
    }

    /// Reads all file entries (name → data). Directories are skipped.
    static func read(_ url: URL) throws -> [(String, Data)] {
        let d = try Data(contentsOf: url, options: .mappedIfSafe)
        func u16(_ o: Int) -> Int { Int(d[d.startIndex + o]) | Int(d[d.startIndex + o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }
        guard d.count >= 22 else { throw ZipError.corrupt }
        var eocd = -1
        var i = d.count - 22
        while i >= max(0, d.count - 65557) { if u32(i) == 0x06054b50 { eocd = i; break }; i -= 1 }
        guard eocd >= 0 else { throw ZipError.corrupt }
        let count = u16(eocd + 10); var p = u32(eocd + 16)
        var res: [(String, Data)] = []
        for _ in 0..<count {
            guard u32(p) == 0x02014b50 else { throw ZipError.corrupt }
            let method = u16(p + 10), csize = u32(p + 20), usize = u32(p + 24), nlen = u16(p + 28), elen = u16(p + 30), clen = u16(p + 32), off = u32(p + 42)
            let name = String(decoding: d[(d.startIndex + p + 46)..<(d.startIndex + p + 46 + nlen)], as: UTF8.self)
            p += 46 + nlen + elen + clen
            if name.hasSuffix("/") { continue }
            let lstart = off + 30 + u16(off + 26) + u16(off + 28)
            let body = d[(d.startIndex + lstart)..<(d.startIndex + lstart + csize)]
            switch method {
            case 0: res.append((name, Data(body)))
            case 8: guard let x = inflate(Data(body), size: usize) else { throw ZipError.corrupt }; res.append((name, x))
            default: throw ZipError.unsupported
            }
        }
        return res
    }
}
