import SwiftUI
import CryptoKit

// ── Supabase credentials — must match BackendManager.swift ──
private let clipProjectURL = "https://YOUR_PROJECT_ID.supabase.co"
private let clipAnonKey    = "YOUR_SUPABASE_ANON_KEY"
// ─────────────────────────────────────────────────────────────

struct AppClipContentView: View {
    let title: String
    let token: String
    let hasToken: Bool

    @State private var step: Step = .fetching
    @State private var encryptedContent = ""
    @State private var serverWrongAttempts = 0
    @State private var decryptedContent = ""
    @State private var attemptsLeft = 3
    @State private var pinInput = ""
    @State private var errorMsg = ""
    @State private var screenshotObserver: NSObjectProtocol?
    @FocusState private var pinFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    private enum Step { case noToken, fetching, enterPin, wrongPin, content, burned, error }
    private let pinLength = 6

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .noToken:   noTokenView
                case .fetching:  fetchingView
                case .enterPin:  pinView
                case .wrongPin:  wrongPinView
                case .content:   contentView
                case .burned:    burnedView
                case .error:     errorView
                }
            }
            .navigationTitle("PrivacyNote")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if !hasToken { step = .noToken; return }
            await loadNote()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && step == .content { Task { await burnAndClose() } }
        }
    }

    // MARK: - Views

    private var noTokenView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "link.badge.plus").font(.system(size: 64)).foregroundStyle(.orange)
            Text("Bağlantı Gerekli").font(.title2.weight(.bold))
            Text("Geçerli bir PrivacyNote bağlantısı açın.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var fetchingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.4)
            Text("Not yükleniyor...").font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var pinView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "lock.shield.fill").font(.system(size: 56)).foregroundStyle(.orange)
            VStack(spacing: 6) {
                Text(title.isEmpty ? "Gizli Not" : "\"\(title)\"").font(.headline).lineLimit(1)
                Text("PIN'i gir").font(.title3.weight(.semibold))
                Text("Gönderen PIN'i ayrıca iletmiş olmalı")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            pinDotsField
            Spacer()
        }
    }

    private var wrongPinView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "xmark.shield.fill").font(.system(size: 56)).foregroundStyle(.red)
            Text("PIN Hatalı").font(.title2.weight(.bold))
            Text("\(attemptsLeft) deneme hakkın kaldı").foregroundStyle(.secondary)
            Button("Tekrar Dene") { pinInput = ""; step = .enterPin }.buttonStyle(.bordered)
            Spacer()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill").foregroundStyle(.green).font(.caption)
                    Text("Kilitli Okuyucu — ekran görüntüsü alınırsa oturum silinir")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                Text(title.isEmpty ? "Gizli Not" : title)
                    .font(.largeTitle.weight(.bold)).padding(.horizontal)
                Divider()
                Text(decryptedContent)
                    .font(.body).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear { startScreenshotWatcher() }
        .onDisappear { stopScreenshotWatcher() }
    }

    private var burnedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "flame.fill").font(.system(size: 72)).foregroundStyle(.orange)
                .symbolEffect(.pulse)
            Text("Oturum Sonlandı").font(.title2.weight(.bold))
            Text("Bu not artık görüntülenemiyor.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            Link(destination: URL(string: "https://apps.apple.com")!) {
                Label("PrivacyNote'u İndir", systemImage: "arrow.down.app.fill")
            }
            .buttonStyle(.bordered).tint(.orange).padding(.top, 8)
            Spacer()
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "icloud.slash.fill").font(.system(size: 52)).foregroundStyle(.red)
            Text("Hata").font(.title2.weight(.bold))
            Text(errorMsg).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
        }
    }

    // MARK: - PIN Input

    private var pinDotsField: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ForEach(0..<pinLength, id: \.self) { i in
                    Circle()
                        .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1.5)
                        .background(Circle().fill(i < pinInput.count ? Color.orange : Color.clear))
                        .frame(width: 18, height: 18)
                        .animation(.spring(response: 0.15), value: pinInput.count)
                }
            }
            TextField("", text: $pinInput)
                .keyboardType(.numberPad).focused($pinFocused)
                .frame(width: 0, height: 0).opacity(0)
                .onChange(of: pinInput) { _, new in
                    let filtered = String(new.filter(\.isNumber).prefix(pinLength))
                    if filtered != new { pinInput = filtered }
                    if filtered.count == pinLength { Task { await attemptDecrypt(pin: filtered) } }
                }
            Button { pinFocused = true } label: {
                Label("PIN Klavyesini Aç", systemImage: "keyboard")
            }.buttonStyle(.bordered)
        }
    }

    // MARK: - Screenshot Watcher

    private func startScreenshotWatcher() {
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil, queue: .main
        ) { _ in Task { await burnAndClose() } }
    }

    private func stopScreenshotWatcher() {
        if let obs = screenshotObserver {
            NotificationCenter.default.removeObserver(obs)
            screenshotObserver = nil
        }
    }

    // MARK: - Inline Networking (mirrors BackendManager.swift)

    private var baseURL: String { "\(clipProjectURL)/rest/v1" }
    private var reqHeaders: [String: String] {
        ["apikey": clipAnonKey, "Authorization": "Bearer \(clipAnonKey)",
         "Content-Type": "application/json", "Accept": "application/json"]
    }

    private struct ClipRow: Decodable {
        let encryptedContent: String
        let wrongAttempts: Int
        let isBurned: Bool
        enum CodingKeys: String, CodingKey {
            case encryptedContent = "encrypted_content"
            case wrongAttempts    = "wrong_attempts"
            case isBurned         = "is_burned"
        }
    }

    private func loadNote() async {
        guard !clipProjectURL.contains("YOUR_PROJECT_ID") else {
            await MainActor.run { errorMsg = "Supabase henüz yapılandırılmamış"; step = .error }
            return
        }
        guard let url = URL(string: "\(baseURL)/notes?id=eq.\(token)&select=*") else {
            await MainActor.run { errorMsg = "Geçersiz bağlantı"; step = .error }
            return
        }
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            reqHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                await MainActor.run { errorMsg = "Sunucuya erişilemedi"; step = .error }
                return
            }
            let rows = try JSONDecoder().decode([ClipRow].self, from: data)
            guard let row = rows.first else { await MainActor.run { step = .burned }; return }
            if row.isBurned { await MainActor.run { step = .burned }; return }
            encryptedContent = row.encryptedContent
            serverWrongAttempts = row.wrongAttempts
            attemptsLeft = 3 - row.wrongAttempts
            await MainActor.run { step = .enterPin }
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run { pinFocused = true }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription; step = .error }
        }
    }

    private func attemptDecrypt(pin: String) async {
        do {
            let text = try decryptAES(encryptedContent, pin: pin)
            await MainActor.run { decryptedContent = text; step = .content }
        } catch {
            let next = serverWrongAttempts + 1
            if next >= 3 { await burnAndClose(); return }
            if let url = URL(string: "\(baseURL)/notes?id=eq.\(token)") {
                var req = URLRequest(url: url)
                req.httpMethod = "PATCH"
                reqHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
                req.httpBody = try? JSONSerialization.data(withJSONObject: ["wrong_attempts": next])
                _ = try? await URLSession.shared.data(for: req)
            }
            serverWrongAttempts = next
            await MainActor.run { pinInput = ""; attemptsLeft = 3 - next; step = .wrongPin }
        }
    }

    private func burnAndClose() async {
        stopScreenshotWatcher()
        if let url = URL(string: "\(baseURL)/notes?id=eq.\(token)") {
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            reqHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
            _ = try? await URLSession.shared.data(for: req)
        }
        await MainActor.run { withAnimation(.easeInOut(duration: 0.25)) { step = .burned } }
    }

    // MARK: - Inline Crypto (same salt as CryptoManager.swift)

    private func decryptAES(_ base64: String, pin: String) throws -> String {
        guard let combined = Data(base64Encoded: base64) else { throw CryptoErr.invalid }
        let sealed = try AES.GCM.SealedBox(combined: combined)
        let data = try AES.GCM.open(sealed, using: deriveKey(pin: pin))
        guard let text = String(data: data, encoding: .utf8) else { throw CryptoErr.invalid }
        return text
    }

    private func deriveKey(pin: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data((pin + "PrivacyNote.2026.Salt").utf8)))
    }

    private enum CryptoErr: Error { case invalid }
}
