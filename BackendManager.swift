import Foundation

// ── Supabase Kurulum (supabase.com'da ücretsiz proje oluşturup SQL editor'de çalıştır) ──
// CREATE TABLE notes (
//   id TEXT PRIMARY KEY,
//   title TEXT NOT NULL DEFAULT '',
//   encrypted_content TEXT NOT NULL,
//   wrong_attempts INT NOT NULL DEFAULT 0,
//   is_burned BOOLEAN NOT NULL DEFAULT false,
//   created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
//   expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '7 days'
// );
// ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "Allow all" ON notes FOR ALL USING (true) WITH CHECK (true);
//
// Ardından aşağıdaki iki satırı kendi proje bilgileriyle doldur:
// ─────────────────────────────────────────────────────────────────────────────────────

enum BackendConfig {
    static let projectURL = "https://YOUR_PROJECT_ID.supabase.co"
    static let anonKey    = "YOUR_SUPABASE_ANON_KEY"

    static var isConfigured: Bool {
        !projectURL.contains("YOUR_PROJECT_ID")
    }
}

// MARK: - Models

struct NoteRow: Codable {
    let id: String
    let title: String
    let encryptedContent: String
    let wrongAttempts: Int
    let isBurned: Bool
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case encryptedContent = "encrypted_content"
        case wrongAttempts    = "wrong_attempts"
        case isBurned         = "is_burned"
        case expiresAt        = "expires_at"
    }
}

enum BackendError: LocalizedError {
    case notConfigured, uploadFailed, networkError, notFound, alreadyBurned, tooManyAttempts

    var errorDescription: String? {
        switch self {
        case .notConfigured:   return "Supabase henüz yapılandırılmamış — BackendManager.swift dosyasını düzenle"
        case .uploadFailed:    return "Not yüklenemedi"
        case .networkError:    return "Ağ hatası — bağlantını kontrol et"
        case .notFound:        return "Not bulunamadı veya süresi doldu"
        case .alreadyBurned:   return "Bu not zaten okunmuş ve silinmiş"
        case .tooManyAttempts: return "Çok fazla yanlış PIN — not imha edildi"
        }
    }
}

// MARK: - Manager

struct BackendManager {
    static let shared = BackendManager()
    private init() {}

    private var base: String { "\(BackendConfig.projectURL)/rest/v1" }
    private var headers: [String: String] {
        ["apikey": BackendConfig.anonKey,
         "Authorization": "Bearer \(BackendConfig.anonKey)",
         "Content-Type": "application/json",
         "Accept": "application/json"]
    }

    // MARK: Upload

    func uploadNote(title: String, encryptedContent: String) async throws -> String {
        guard BackendConfig.isConfigured else { throw BackendError.notConfigured }
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let body: [String: Any] = [
            "id": token,
            "title": title.isEmpty ? "Gizli Not" : title,
            "encrypted_content": encryptedContent
        ]
        var req = URLRequest(url: URL(string: "\(base)/notes")!)
        req.httpMethod = "POST"
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BackendError.uploadFailed
        }
        return token
    }

    // MARK: Fetch

    func fetchNote(token: String) async throws -> NoteRow {
        guard BackendConfig.isConfigured else { throw BackendError.notConfigured }
        guard let url = URL(string: "\(base)/notes?id=eq.\(token)&select=*") else {
            throw BackendError.networkError
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw BackendError.networkError
        }
        let rows = try JSONDecoder().decode([NoteRow].self, from: data)
        guard let row = rows.first else { throw BackendError.notFound }
        if row.isBurned { throw BackendError.alreadyBurned }
        return row
    }

    // MARK: Burn

    func burnNote(token: String) async {
        guard BackendConfig.isConfigured,
              let url = URL(string: "\(base)/notes?id=eq.\(token)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: Wrong attempt — returns remaining attempts

    func recordWrongAttempt(token: String, currentServerCount: Int) async throws -> Int {
        let next = currentServerCount + 1
        if next >= 3 {
            await burnNote(token: token)
            throw BackendError.tooManyAttempts
        }
        if let url = URL(string: "\(base)/notes?id=eq.\(token)") {
            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["wrong_attempts": next])
            _ = try? await URLSession.shared.data(for: req)
        }
        return 3 - next
    }
}
