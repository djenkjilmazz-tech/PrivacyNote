import SwiftUI
import CryptoKit

struct AppClipContentView: View {
    let title: String
    let encryptedPayload: String
    let hasPayload: Bool

    @State private var pin = ""
    @State private var decryptedContent: String? = nil
    @State private var step: Step = .pin
    @FocusState private var pinFocused: Bool

    private enum Step { case pin, content, error }
    private let pinLength = 6

    var body: some View {
        NavigationStack {
            Group {
                if !hasPayload {
                    noPayloadView
                } else {
                    switch step {
                    case .pin: pinView
                    case .content: contentView
                    case .error: errorView
                    }
                }
            }
            .navigationTitle("PrivacyNote")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Views

    private var noPayloadView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Bağlantı Gerekli")
                .font(.title2.weight(.bold))
            Text("PrivacyNote bağlantısını açarak gizli notunuzu görüntüleyebilirsiniz.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var pinView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            VStack(spacing: 6) {
                Text("\"\(title.isEmpty ? "Not" : title)\"")
                    .font(.headline)
                    .lineLimit(1)
                Text("Bu notu okumak için PIN girin")
                    .font(.title3.weight(.semibold))
                Text("Gönderen size PIN'i ayrıca iletmiş olmalı")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 14) {
                ForEach(0..<pinLength, id: \.self) { i in
                    Circle()
                        .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1.5)
                        .background(Circle().fill(i < pin.count ? Color.orange : Color.clear))
                        .frame(width: 18, height: 18)
                        .animation(.spring(response: 0.15), value: pin.count)
                }
            }

            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .focused($pinFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: pin) { _, new in
                    let filtered = String(new.filter(\.isNumber).prefix(pinLength))
                    if filtered != new { pin = filtered }
                    if filtered.count == pinLength {
                        attemptDecrypt(with: filtered)
                    }
                }

            Button { pinFocused = true } label: {
                Label("PIN Klavyesini Aç", systemImage: "keyboard")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                pinFocused = true
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title.isEmpty ? "Not" : title)
                    .font(.largeTitle.weight(.bold))
                    .padding(.horizontal)

                Divider()

                Text(decryptedContent ?? "")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                Divider()

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("Bu not yalnızca bu oturumda görüntülendi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://apps.apple.com/app/id0")!) {
                        Label("PrivacyNote'u İndir", systemImage: "arrow.down.app.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(.red)
            Text("PIN Hatalı")
                .font(.title2.weight(.bold))
            Text("Girilen PIN doğru değil veya not bozulmuş.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Tekrar Dene") {
                pin = ""
                step = .pin
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Logic

    private func attemptDecrypt(with enteredPin: String) {
        guard let combined = Data(base64Encoded: encryptedPayload) else { step = .error; return }
        let key = deriveKey(pin: enteredPin)
        do {
            let sealed = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(sealed, using: key)
            guard let text = String(data: decrypted, encoding: .utf8) else { step = .error; return }
            decryptedContent = text
            step = .content
        } catch {
            step = .error
        }
    }

    private func deriveKey(pin: String) -> SymmetricKey {
        let data = Data((pin + "PrivacyNote.2026.Salt").utf8)
        let hash = SHA256.hash(data: data)
        return SymmetricKey(data: hash)
    }
}

#Preview {
    AppClipContentView(title: "Test Notu", encryptedPayload: "", hasPayload: false)
}
