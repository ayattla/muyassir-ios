import Foundation
import SwiftUI

typealias Rec = [String: Any]

/// On-device persistence: small JSON files in Application Support. Nothing leaves the device.
final class Store: ObservableObject {
    static let shared = Store()
    @Published var favorites: [String] = []
    @Published var usage: [String: Int] = [:]
    @Published var recents: [Recent] = []

    struct Recent: Identifiable { let tool: String; let time: Date; let detail: String; var id: String { tool + "\(time.timeIntervalSince1970)" } }

    private let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("data", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private init() {
        favorites = read("favorites") as? [String] ?? []
        usage = read("usage") as? [String: Int] ?? [:]
        recents = (read("recents") as? [Rec] ?? []).map { Recent(tool: $0["t"] as? String ?? "", time: Date(timeIntervalSince1970: $0["at"] as? Double ?? 0), detail: $0["d"] as? String ?? "") }
    }

    func toggleFavorite(_ id: String) {
        if let i = favorites.firstIndex(of: id) { favorites.remove(at: i) } else { favorites.insert(id, at: 0) }
        write("favorites", favorites)
    }

    func used(_ id: String, _ detail: String = "") {
        usage[id, default: 0] += 1; write("usage", usage)
        recents.removeAll { $0.tool == id && $0.detail == detail }
        recents.insert(Recent(tool: id, time: Date(), detail: detail), at: 0)
        if recents.count > 30 { recents.removeLast(recents.count - 30) }
        write("recents", recents.map { ["t": $0.tool, "at": $0.time.timeIntervalSince1970, "d": $0.detail] as Rec })
    }

    func clearRecents() { recents = []; write("recents", [Rec]()) }

    func list(_ n: String) -> [Rec] { read("list_\(n)") as? [Rec] ?? [] }
    func saveList(_ n: String, _ v: [Rec]) { write("list_\(n)", v) }
    func obj(_ n: String) -> Rec { read("obj_\(n)") as? Rec ?? [:] }
    func saveObj(_ n: String, _ v: Rec) { write("obj_\(n)", v) }

    private func read(_ n: String) -> Any? {
        guard let d = try? Data(contentsOf: dir.appendingPathComponent("\(n).json")) else { return nil }
        return try? JSONSerialization.jsonObject(with: d)
    }
    private func write(_ n: String, _ v: Any) {
        guard JSONSerialization.isValidJSONObject(v), let d = try? JSONSerialization.data(withJSONObject: v) else { return }
        try? d.write(to: dir.appendingPathComponent("\(n).json"), options: .atomic)
    }
}

/// Output files: Documents/out/<stamp>/ (visible in the Files app). Inputs are copied to tmp only while processing.
enum FilesX {
    static func outDir() -> URL {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("out/\(f.string(from: Date()))", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    /// Every result file still on the device, newest first.
    static func outputs() -> [URL] {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("out")
        let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey])
        var list: [URL] = []
        while let u = e?.nextObject() as? URL { if (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { list.append(u) } }
        return list.sorted { date($0) > date($1) }
    }
    static func date(_ u: URL) -> Date { (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
    static func clearAll() {
        let fm = FileManager.default
        try? fm.removeItem(at: fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("out"))
        try? fm.removeItem(at: fm.temporaryDirectory.appendingPathComponent("in"))
    }
    static func cleanOld() {
        let fm = FileManager.default
        let root = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("out")
        let limit = Date().addingTimeInterval(-24 * 3600)
        for u in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            if let d = try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, d < limit { try? fm.removeItem(at: u) }
        }
        try? fm.removeItem(at: fm.temporaryDirectory.appendingPathComponent("in"))
    }
    /// Copies a security-scoped picked file into tmp.
    static func toTemp(_ url: URL) throws -> URL {
        let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("in/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }
    static func base(_ u: URL) -> String { u.deletingPathExtension().lastPathComponent }
    static func human(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }
    static func size(_ u: URL) -> Int64 { Int64((try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0) }
}
