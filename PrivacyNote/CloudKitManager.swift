import CloudKit
import Foundation

enum CloudKitError: LocalizedError {
    case noteNotFound
    case noteAlreadyRead
    case uploadFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .noteNotFound:     return "Bu not zaten okundu veya süresi doldu"
        case .noteAlreadyRead:  return "Bu not daha önce okundu ve yok edildi"
        case .uploadFailed:     return "Not yüklenemedi, bağlantıyı kontrol et"
        case .notAuthenticated: return "İCloud hesabınıza giriş yapın"
        }
    }
}

actor CloudKitManager {
    static let shared = CloudKitManager()

    private let db: CKDatabase

    private init() {
        let container = CKContainer(identifier: "iCloud.Cenk-Yilmaz.PrivacyNote")
        db = container.publicCloudDatabase
    }

    // MARK: - Upload (Sender)

    /// Encrypts note and uploads to CloudKit. Returns shareable token.
    func uploadNote(title: String, encryptedContent: String) async throws -> String {
        let token = UUID().uuidString
        let recordID = CKRecord.ID(recordName: "note-\(token)")
        let record = CKRecord(recordType: "SecretNote", recordID: recordID)
        record["title"] = title
        record["encryptedContent"] = encryptedContent
        record["expiresAt"] = Date().addingTimeInterval(7 * 24 * 3600) // 7 gün

        do {
            try await db.save(record)
        } catch {
            throw CloudKitError.uploadFailed
        }
        return token
    }

    // MARK: - Fetch (Recipient)

    /// Fetches note if it hasn't been read yet.
    func fetchNote(token: String) async throws -> (title: String, encryptedContent: String) {
        // 1. Check read receipt
        let receiptID = CKRecord.ID(recordName: "receipt-\(token)")
        if (try? await db.record(for: receiptID)) != nil {
            throw CloudKitError.noteAlreadyRead
        }

        // 2. Fetch note
        let recordID = CKRecord.ID(recordName: "note-\(token)")
        do {
            let record = try await db.record(for: recordID)

            if let expiresAt = record["expiresAt"] as? Date, Date() > expiresAt {
                throw CloudKitError.noteNotFound
            }

            guard let title = record["title"] as? String,
                  let enc = record["encryptedContent"] as? String else {
                throw CloudKitError.noteNotFound
            }
            return (title, enc)
        } catch let err as CKError where err.code == .unknownItem {
            throw CloudKitError.noteNotFound
        }
    }

    // MARK: - Burn (After Read)

    /// Creates read receipt and attempts to delete original note.
    func burnNote(token: String) async {
        // Create read receipt (anyone can create records in public DB)
        let receiptID = CKRecord.ID(recordName: "receipt-\(token)")
        let receipt = CKRecord(recordType: "ReadReceipt", recordID: receiptID)
        receipt["noteToken"] = token
        receipt["readAt"] = Date()
        try? await db.save(receipt)

        // Attempt to delete original (may fail if different user — that's OK,
        // the receipt prevents re-reading)
        let recordID = CKRecord.ID(recordName: "note-\(token)")
        try? await db.deleteRecord(withID: recordID)
    }
}
