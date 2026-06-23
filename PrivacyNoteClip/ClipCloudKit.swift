import CloudKit
import Foundation

enum CloudKitError: LocalizedError {
    case noteNotFound, noteAlreadyRead, uploadFailed

    var errorDescription: String? {
        switch self {
        case .noteNotFound:    return "Bu not zaten okundu veya süresi doldu"
        case .noteAlreadyRead: return "Bu not daha önce okundu ve yok edildi"
        case .uploadFailed:    return "Bağlantı hatası"
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

    func fetchNote(token: String) async throws -> (title: String, encryptedContent: String) {
        let receiptID = CKRecord.ID(recordName: "receipt-\(token)")
        if (try? await db.record(for: receiptID)) != nil {
            throw CloudKitError.noteAlreadyRead
        }
        let recordID = CKRecord.ID(recordName: "note-\(token)")
        do {
            let record = try await db.record(for: recordID)
            if let exp = record["expiresAt"] as? Date, Date() > exp {
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

    func burnNote(token: String) async {
        let receiptID = CKRecord.ID(recordName: "receipt-\(token)")
        let receipt = CKRecord(recordType: "ReadReceipt", recordID: receiptID)
        receipt["noteToken"] = token
        receipt["readAt"] = Date()
        try? await db.save(receipt)
        let recordID = CKRecord.ID(recordName: "note-\(token)")
        try? await db.deleteRecord(withID: recordID)
    }
}
