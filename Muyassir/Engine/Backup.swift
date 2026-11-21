import Foundation
import CryptoKit
import CommonCrypto

/// Encrypted backup of the app's saved data (Application Support/data). The user chooses where the file goes.
/// Format: "MYSB1" + salt(16) + AES-GCM combined (nonce 12 + ciphertext + tag 16). Key: PBKDF2-SHA256, 120k rounds.
enum Backup {
    static let magic = Data("MYSB1".utf8)
    static let rounds: UInt32 = 120_000
    enum Failure: LocalizedError { case notBackup, wrongPassword
        var errorDescription: String? { switch self { case .notBackup: "هذا الملف ليس نسخة احتياطية من مُيسّر"; case .wrongPassword: "كلمة المرور غير صحيحة" } } }

    static var dataDir: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("data", isDirectory: true) }

    static func key(_ password: String, _ salt: Data) -> SymmetricKey {
        var out = [UInt8](repeating: 0, count: 32); let pw = Array(password.utf8)
        salt.withUnsafeBytes { s in
            _ = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pw.map { CChar(bitPattern: $0) }, pw.count, s.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds, &out, 32)
        }
        return SymmetricKey(data: out)
    }

    static func encrypt(_ plain: Data, password: String) throws -> Data {
        var salt = Data(count: 16); _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let box = try AES.GCM.seal(plain, using: key(password, salt))
        return magic + salt + box.combined!
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        guard data.count > 5 + 16 + 28, data.prefix(5) == magic else { throw Failure.notBackup }
        let salt = data.subdata(in: 5..<21), rest = data.subdata(in: 21..<data.count)
        do { return try AES.GCM.open(try AES.GCM.SealedBox(combined: rest), using: key(password, salt)) } catch { throw Failure.wrongPassword }
    }

    /// Simple archive of the data folder: [nameLen u32][name][size u64][bytes]…
    static func pack(_ dir: URL) -> Data {
        var d = Data()
        let files = (FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey])?.compactMap { $0 as? URL } ?? []).filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
        for f in files {
            guard let bytes = try? Data(contentsOf: f) else { continue }
            let name = Data(String(f.standardizedFileURL.path.dropFirst(dir.standardizedFileURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")).utf8)
            var n = UInt32(name.count).littleEndian, s = UInt64(bytes.count).littleEndian
            d.append(Data(bytes: &n, count: 4)); d.append(name); d.append(Data(bytes: &s, count: 8)); d.append(bytes)
        }
        return d
    }

    static func unpack(_ d: Data, into dir: URL) throws {
        var i = d.startIndex
        func take(_ n: Int) throws -> Data { guard n >= 0, d.distance(from: i, to: d.endIndex) >= n else { throw Failure.notBackup }; defer { i = d.index(i, offsetBy: n) }; return d.subdata(in: i..<d.index(i, offsetBy: n)) }
        let root = dir.standardizedFileURL.path
        while i < d.endIndex {
            let n = Int(try take(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian)
            guard let name = String(data: try take(n), encoding: .utf8) else { throw Failure.notBackup }
            let s = Int(try take(8).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }.littleEndian)
            let f = dir.appendingPathComponent(name).standardizedFileURL
            guard f.path.hasPrefix(root + "/") else { throw Failure.notBackup }
            try FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
            try take(s).write(to: f, options: .atomic)
        }
    }

    static func export(password: String, to url: URL) throws { try encrypt(pack(dataDir), password: password).write(to: url, options: .atomic) }

    /// Replaces saved data with the backup's. The caller asks the user to reopen the app afterwards.
    static func restore(password: String, from data: Data) throws {
        let plain = try decrypt(data, password: password)
        let tmp = dataDir.deletingLastPathComponent().appendingPathComponent("data-restore", isDirectory: true)
        try? FileManager.default.removeItem(at: tmp); try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try unpack(plain, into: tmp)
        try? FileManager.default.removeItem(at: dataDir); try FileManager.default.moveItem(at: tmp, to: dataDir)
    }
}
