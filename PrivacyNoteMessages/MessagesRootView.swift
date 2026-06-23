import SwiftUI
import CryptoKit

struct MessagesRootView: View {
    let sendHandler: (String, String) -> Void

    @State private var title = ""
    @State private var content = ""
    @State private var pin = ""
    @State private var step: Step = .compose
    @State private var sentURL: URL? = nil

    private enum Step { case compose, setPin, confirmPin, done }
    private let pinLength = 6

    var body: some View {
        NavigationStack {
            switch step {
            case .compose: composeForm
            case .setPin:  pinEntryView(heading: "PIN Belirle", message: "Alıcı bu PIN ile notu açacak") { p in pin = p; step = .confirmPin }
            case .confirmPin: pinEntryView(heading: "PIN Onayla", message: "PIN'i tekrar girin") { p in
                if p == pin { generateAndSend() }
                else { pin = ""; step = .setPin }
            }
            case .done: doneView
            }
        }
    }

    // MARK: - Compose

    private var composeForm: some View {
        Form {
            Section("Başlık") {
                TextField("Not başlığı...", text: $title)
            }
            Section("İçerik") {
                TextEditor(text: $content)
                    .frame(minHeight: 120)
            }
        }
        .navigationTitle("Şifreli Not Gönder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("İleri") { step = .setPin }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || content.isEmpty)
            }
        }
    }

    // MARK: - PIN

    private func pinEntryView(heading: String, message: String, onComplete: @escaping (String) -> Void) -> some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            VStack(spacing: 6) {
                Text(heading).font(.title2.weight(.bold))
                Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            PINDotsView(pinLength: pinLength, onComplete: onComplete)
            Spacer()
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("Mesaj Hazır!")
                .font(.title2.weight(.bold))
            Group {
                Text("Konuşma ekranından gönderebilirsiniz.\n") +
                Text("Alıcıya PIN'i ayrıca iletmeyi unutma: ").foregroundColor(.secondary) +
                Text(pin).bold().foregroundColor(.orange)
            }
            .font(.callout)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            Spacer()
        }
    }

    // MARK: - Logic

    private func generateAndSend() {
        guard let encrypted = encrypt(content, pin: pin),
              let url = createURL(title: title, encryptedContent: encrypted) else { return }
        sentURL = url
        sendHandler(title, url.absoluteString)
        step = .done
    }

    private func encrypt(_ text: String, pin: String) -> String? {
        guard let data = text.data(using: .utf8) else { return nil }
        let key = deriveKey(pin: pin)
        guard let sealed = try? AES.GCM.seal(data, using: key),
              let combined = sealed.combined else { return nil }
        return combined.base64EncodedString()
    }

    private func deriveKey(pin: String) -> SymmetricKey {
        let data = Data((pin + "PrivacyNote.2026.Salt").utf8)
        let hash = SHA256.hash(data: data)
        return SymmetricKey(data: hash)
    }

    private func createURL(title: String, encryptedContent: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "privacynote.app"
        components.path = "/r"
        let safe = encryptedContent
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        components.queryItems = [
            URLQueryItem(name: "t", value: title),
            URLQueryItem(name: "p", value: safe)
        ]
        return components.url
    }
}

// Minimal PIN dots + hidden field for Messages target (no shared PINEntryView)
private struct PINDotsView: View {
    let pinLength: Int
    let onComplete: (String) -> Void

    @State private var pin = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
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
                .focused($focused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: pin) { _, new in
                    let filtered = String(new.filter(\.isNumber).prefix(pinLength))
                    if filtered != new { pin = filtered }
                    if filtered.count == pinLength {
                        let entered = filtered
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { onComplete(entered) }
                    }
                }
            Button { focused = true } label: {
                Label("PIN Klavyesini Aç", systemImage: "keyboard")
            }
            .buttonStyle(.bordered)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        }
    }
}
