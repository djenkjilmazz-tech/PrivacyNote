import SwiftUI
import CryptoKit

struct AppClipContentView: View {
    let title: String
    let encryptedPayload: String
    let cloudKitToken: String
    let hasPayload: Bool

    @State private var step: Step = .enterPin
    @State private var decryptedContent: String? = nil
    @State private var screenshotObserver: NSObjectProtocol? = nil
    @FocusState private var pinFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    private enum Step { case noPayload, enterPin, wrongPin, content, burned }
    private let pinLength = 6
    @State private var pinInput = ""

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .noPayload:  noPayloadView
                case .enterPin:   pinView
                case .wrongPin:   wrongPinView
                case .content:    contentView
                case .burned:     burnedView
                }
            }
            .navigationTitle("PrivacyNote")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if !hasPayload { step = .noPayload }
        }
        // Arka plana geçince oturumu sil
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && step == .content {
                burn()
            }
        }
    }

    // MARK: - No Payload

    private var noPayloadView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "link.badge.plus")
                .font(.system(size: 64)).foregroundStyle(.orange)
            Text("Bağlantı Gerekli")
                .font(.title2.weight(.bold))
            Text("Geçerli bir PrivacyNote bağlantısı açın.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - PIN

    private var pinView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56)).foregroundStyle(.orange)
            VStack(spacing: 6) {
                Text(title.isEmpty ? "Gizli Not" : "\"\(title)\"")
                    .font(.headline).lineLimit(1)
                Text("PIN'i gir")
                    .font(.title3.weight(.semibold))
                Text("Gönderen PIN'i ayrıca iletmiş olmalı")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            pinDotsField
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pinFocused = true }
        }
    }

    private var wrongPinView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "xmark.shield.fill")
                .font(.system(size: 56)).foregroundStyle(.red)
            Text("PIN Hatalı")
                .font(.title2.weight(.bold))
            Text("Girilen PIN doğru değil.")
                .foregroundStyle(.secondary)
            Button("Tekrar Dene") { step = .enterPin }
                .buttonStyle(.bordered)
            Spacer()
        }
    }

    // MARK: - Locked Reader (içerik — blur yok, sadece göster)

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Kilitli okuyucu etiketi
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .foregroundStyle(.green).font(.caption)
                    Text("Kilitli Okuyucu — ekran görüntüsü alınırsa oturum silinir")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Text(title.isEmpty ? "Gizli Not" : title)
                    .font(.largeTitle.weight(.bold))
                    .padding(.horizontal)

                Divider()

                Text(decryptedContent ?? "")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear { startScreenshotWatcher() }
        .onDisappear { stopScreenshotWatcher() }
    }

    // MARK: - Burned

    private var burnedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 72)).foregroundStyle(.orange)
                .symbolEffect(.bounce)
            Text("Oturum Sonlandı")
                .font(.title2.weight(.bold))
            Text("Bu not artık bu cihazda görüntülenemiyor.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            Link(destination: URL(string: "https://apps.apple.com")!) {
                Label("PrivacyNote'u İndir", systemImage: "arrow.down.app.fill")
            }
            .buttonStyle(.bordered).tint(.orange).padding(.top, 8)
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
                    if filtered.count == pinLength { attemptDecrypt(pin: filtered) }
                }
            Button { pinFocused = true } label: {
                Label("PIN Klavyesini Aç", systemImage: "keyboard")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Screenshot Watcher

    private func startScreenshotWatcher() {
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { _ in
            burn() // Screenshot → oturumu hemen sil
        }
    }

    private func stopScreenshotWatcher() {
        if let obs = screenshotObserver {
            NotificationCenter.default.removeObserver(obs)
            screenshotObserver = nil
        }
    }

    // MARK: - Burn

    private func burn() {
        stopScreenshotWatcher()
        withAnimation(.easeInOut(duration: 0.25)) { step = .burned }
    }

    // MARK: - Decrypt

    private func attemptDecrypt(pin: String) {
        do {
            let text = try decryptAES(encryptedPayload, pin: pin)
            decryptedContent = text
            step = .content
        } catch {
            pinInput = ""
            step = .wrongPin
        }
    }

    private func decryptAES(_ base64: String, pin: String) throws -> String {
        guard let combined = Data(base64Encoded: base64) else { throw Err.invalid }
        let sealed = try AES.GCM.SealedBox(combined: combined)
        let data = try AES.GCM.open(sealed, using: deriveKey(pin: pin))
        guard let text = String(data: data, encoding: .utf8) else { throw Err.invalid }
        return text
    }

    private func deriveKey(pin: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data((pin + "PrivacyNote.2026.Salt").utf8)))
    }

    private enum Err: Error { case invalid }
}
