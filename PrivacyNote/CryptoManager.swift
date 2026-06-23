import CryptoKit
import Foundation

enum CryptoError: LocalizedError {
    case encryptionFailed, decryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Şifreleme başarısız"
        case .decryptionFailed: return "PIN hatalı veya veri bozuk"
        }
    }
}

struct CryptoManager {
    private static let salt = "PrivacyNote.2026.Salt"

    static func encrypt(_ text: String, pin: String) throws -> String {
        guard let data = text.data(using: .utf8) else { throw CryptoError.encryptionFailed }
        let key = deriveKey(pin: pin)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw CryptoError.encryptionFailed }
        return combined.base64EncodedString()
    }

    static func decrypt(_ base64: String, pin: String) throws -> String {
        guard let combined = Data(base64Encoded: base64) else { throw CryptoError.decryptionFailed }
        let key = deriveKey(pin: pin)
        do {
            let sealed = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(sealed, using: key)
            guard let text = String(data: decrypted, encoding: .utf8) else { throw CryptoError.decryptionFailed }
            return text
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    static func deriveKey(pin: String) -> SymmetricKey {
        let data = Data((pin + salt).utf8)
        let hash = SHA256.hash(data: data)
        return SymmetricKey(data: hash)
    }
}
