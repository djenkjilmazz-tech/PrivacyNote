import SwiftUI
import CloudKit
import CryptoKit

struct AppClipContentView: View {
    let title: String
    let token: String
    let hasPayload: Bool

    @State private var step: Step = .loading
    @State private var encryptedContent = ""
    @State private var decryptedContent: String? = nil
    @State private var errorMessage = ""
    @FocusState private var pinFocused: Bool

    private enum Step {
        case loading, notFound, enterPin, decrypting, content, burned, noPayload
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .noPayload:   noPayloadView
                case .loading:     loadingView
                case .notFound:    notFoundView
                case .enterPin:    pinView
                case .decrypting:  decryptingView
                case .content:     contentView
                case .burned:      burnedView
                }
            }
            .navigationTitle("PrivacyNote")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if hasPayload {
                await fetchNote()
            } else {
                step = .noPayload
            }
        }
    }

    // MARK: - Step Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Text("Not yükleniyor...")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var notFoundView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "flame.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text("Not Bulunamadı")
                .font(.title2.weight(.bold))
            Text(errorMessage.isEmpty
                 ? "Bu not zaten okundu, süresi doldu veya hiç oluşturulmadı."
                 : errorMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            installButton
            Spacer()
        }
    }

    private var pinView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            VStack(spacing: 6) {
                Text(title.isEmpty ? "Gizli Not" : "\"\(title)\"")
                    .font(.headline)
                    .lineLimit(1)
                Text("PIN'i gir")
                    .font(.title3.weight(.semibold))
                Text("Gönderen PIN'i sana ayrıca iletmiş olmalı")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            PINDotsField(length: 6, focused: $pinFocused) { entered in
                Task { await tryDecrypt(pin: entered) }
            }
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pinFocused = true }
        }
    }

    private var decryptingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.3)
            Text("Çözümleniyor...")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title.isEmpty ? "Gizli Not" : title)
                    .font(.largeTitle.weight(.bold))
                    .padding(.horizontal)

                Divider()

                Text(decryptedContent ?? "")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                Divider()

                burnButton
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private var burnedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce)
            Text("Not Yok Edildi")
                .font(.title2.weight(.bold))
            Text("Bu not artık hiç kimse tarafından görüntülenemez.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            installButton
            Spacer()
        }
    }

    private var noPayloadView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Bağlantı Gerekli")
                .font(.title2.weight(.bold))
            Text("Geçerli bir PrivacyNote bağlantısı açın.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            installButton
        }
    }

    private var burnButton: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .foregroundStyle(.orange)
                Text("Bu notu şimdi yok et")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await burnAndClose() }
            } label: {
                Label("Okudum, Yok Et", systemImage: "flame.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var installButton: some View {
        Link(destination: URL(string: "https://apps.apple.com")!) {
            Label("PrivacyNote'u İndir", systemImage: "arrow.down.app.fill")
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .padding(.top, 8)
    }

    // MARK: - Logic

    private func fetchNote() async {
        step = .loading
        do {
            let result = try await CloudKitManager.shared.fetchNote(token: token)
            encryptedContent = result.encryptedContent
            step = .enterPin
        } catch let err as CloudKitError {
            errorMessage = err.localizedDescription ?? ""
            step = .notFound
        } catch {
            errorMessage = error.localizedDescription
            step = .notFound
        }
    }

    private func tryDecrypt(pin: String) async {
        step = .decrypting
        do {
            let text = try decryptLocal(encryptedContent, pin: pin)
            decryptedContent = text
            step = .content
        } catch {
            // Wrong PIN — go back
            step = .enterPin
        }
    }

    private func burnAndClose() async {
        await CloudKitManager.shared.burnNote(token: token)
        withAnimation { step = .burned }
    }

    // Self-contained AES decrypt (same salt as main app)
    private func decryptLocal(_ base64: String, pin: String) throws -> String {
        guard let combined = Data(base64Encoded: base64) else { throw DecryptError.invalid }
        let key = deriveKey(pin: pin)
        let sealed = try AES.GCM.SealedBox(combined: combined)
        let data = try AES.GCM.open(sealed, using: key)
        guard let text = String(data: data, encoding: .utf8) else { throw DecryptError.invalid }
        return text
    }

    private func deriveKey(pin: String) -> SymmetricKey {
        let data = Data((pin + "PrivacyNote.2026.Salt").utf8)
        return SymmetricKey(data: SHA256.hash(data: data))
    }

    private enum DecryptError: Error { case invalid }
}

// MARK: - PIN Dots Input

private struct PINDotsField: View {
    let length: Int
    var focused: FocusState<Bool>.Binding
    let onComplete: (String) -> Void

    @State private var pin = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ForEach(0..<length, id: \.self) { i in
                    Circle()
                        .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1.5)
                        .background(Circle().fill(i < pin.count ? Color.orange : Color.clear))
                        .frame(width: 18, height: 18)
                        .animation(.spring(response: 0.15), value: pin.count)
                }
            }
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .focused(focused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: pin) { _, new in
                    let filtered = String(new.filter(\.isNumber).prefix(length))
                    if filtered != new { pin = filtered }
                    if filtered.count == length {
                        let entered = filtered
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onComplete(entered)
                            pin = ""
                        }
                    }
                }
            Button { focused.wrappedValue = true } label: {
                Label("PIN Klavyesini Aç", systemImage: "keyboard")
            }
            .buttonStyle(.bordered)
        }
    }
}
