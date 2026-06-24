import SwiftUI
import CryptoKit

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var pin = ""
    @State private var step: Step = .write
    @State private var shareURL: URL? = nil
    @State private var uploadError: String? = nil
    @State private var copied = false

    private enum Step { case write, setPin, confirmPin, uploading, share, error }
    private let pinLength = 6

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .write:      writeView
                case .setPin:     pinView(heading: "PIN Belirle",
                                          message: "Alıcı notu açmak için bu PIN'i girecek") { p in
                                      pin = p; step = .confirmPin
                                  }
                case .confirmPin: pinView(heading: "PIN'i Onayla",
                                          message: "PIN'i tekrar gir") { p in
                                      if p == pin { Task { await upload() } }
                                      else { pin = ""; step = .setPin }
                                  }
                case .uploading:  uploadingView
                case .share:      shareView
                case .error:      errorView
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .opacity(step == .share ? 0 : 1)
                }
            }
        }
    }

    // MARK: - Step Views

    private var writeView: some View {
        Form {
            Section("Başlık") {
                TextField("Başlık...", text: $title)
            }
            Section("Gizli İçerik") {
                TextEditor(text: $content)
                    .frame(minHeight: 160)
            }
            Section {
                Button {
                    step = .setPin
                } label: {
                    HStack {
                        Spacer()
                        Label("PIN ile Şifrele", systemImage: "lock.shield.fill")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .tint(.orange)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("Not, gönderildiğinde yalnızca bir kez okunabilecek.")
            }
        }
    }

    private func pinView(heading: String, message: String, onComplete: @escaping (String) -> Void) -> some View {
        PINEntryView(heading: heading, message: message, onComplete: onComplete,
                     onCancel: { step = step == .confirmPin ? .setPin : .write })
    }

    private var uploadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            VStack(spacing: 8) {
                Text("Şifreleniyor ve yükleniyor...")
                    .font(.headline)
                Text("Güvenli sunucuya aktarılıyor")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var shareView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                VStack(spacing: 6) {
                    Text("Not Hazır!")
                        .font(.title2.weight(.bold))
                    Text("Alıcı yalnızca bir kez okuyabilir, sonra yok olur")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let url = shareURL {
                    if let qr = ShareLinkManager.generateQRCode(url: url) {
                        Image(uiImage: qr)
                            .resizable().interpolation(.none)
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding()
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 6)
                    }

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = url.absoluteString
                            withAnimation { copied = true }
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Kopyalandı" : "Linki Kopyala",
                                  systemImage: copied ? "checkmark" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        ShareLink(item: url) {
                            Label("Paylaş", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding(.horizontal)
                }

                pinReminderCard

                Button("Kapat") { dismiss() }
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding(.vertical)
        }
    }

    private var pinReminderCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("PIN: \(pin)")
                    .font(.headline.monospaced())
                Text("PIN'i alıcıya ayrıca ilet (link ile değil)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash.fill")
                .font(.system(size: 52))
                .foregroundStyle(.red)
            Text("Yükleme Başarısız")
                .font(.title2.weight(.bold))
            Text(uploadError ?? "Bilinmeyen hata")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Tekrar Dene") {
                step = .uploading
                Task { await upload() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
    }

    // MARK: - Logic

    private func upload() async {
        step = .uploading
        do {
            let noteTitle = title.isEmpty ? "Gizli Not" : title
            let encrypted = try CryptoManager.encrypt(content, pin: pin)
            let url: URL?
            if BackendConfig.isConfigured {
                // Server-side burn-after-read (requires Supabase setup)
                let token = try await BackendManager.shared.uploadNote(title: noteTitle, encryptedContent: encrypted)
                url = ShareLinkManager.createTokenURL(title: noteTitle, token: token)
            } else {
                // URL-based: works without any server setup
                try await Task.sleep(for: .milliseconds(600))
                url = ShareLinkManager.createURL(title: noteTitle, encryptedContent: encrypted)
            }
            await MainActor.run {
                shareURL = url
                step = .share
            }
        } catch {
            await MainActor.run {
                uploadError = error.localizedDescription
                step = .error
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case .write:       return "Gizli Not Oluştur"
        case .setPin:      return "PIN Belirle"
        case .confirmPin:  return "PIN Onayla"
        case .uploading:   return "Yükleniyor"
        case .share:       return "Paylaşıma Hazır"
        case .error:       return "Hata"
        }
    }
}
