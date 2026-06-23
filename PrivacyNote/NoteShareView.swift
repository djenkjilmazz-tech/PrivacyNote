import SwiftUI

struct NoteShareView: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var step: Step = .setPin
    @State private var shareURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var copied = false

    private enum Step { case setPin, confirmPin, share }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .setPin:
                    PINEntryView(
                        heading: "PIN Belirle",
                        message: "Alıcı notu okumak için bu PIN'i girecek",
                        onComplete: { p in pin = p; step = .confirmPin },
                        onCancel: { dismiss() }
                    )
                case .confirmPin:
                    PINEntryView(
                        heading: "PIN'i Onayla",
                        message: "PIN'i tekrar girin",
                        onComplete: { p in
                            if p == pin { generateLink() }
                            else { pin = ""; step = .setPin; errorMessage = "PIN'ler eşleşmedi" }
                        },
                        onCancel: { step = .setPin }
                    )
                case .share:
                    shareView
                }
            }
            .navigationTitle("Notu Paylaş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .alert("Hata", isPresented: .constant(errorMessage != nil)) {
                Button("Tamam") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var shareView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let url = shareURL {
                    if let qr = ShareLinkManager.generateQRCode(url: url) {
                        Image(uiImage: qr)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding()
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.08), radius: 8)
                    }

                    VStack(spacing: 4) {
                        Text("Bağlantıyı Paylaş")
                            .font(.headline)
                        Text("Alıcı App Clip veya tarayıcıda açabilir")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
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
                    }
                    .padding(.horizontal)

                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PIN: \(pin)")
                                .font(.callout.weight(.semibold))
                            Text("PIN'i alıcıya ayrıca iletmeyi unutma")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func generateLink() {
        do {
            let encrypted = try CryptoManager.encrypt(note.content, pin: pin)
            shareURL = ShareLinkManager.createURL(title: note.title, encryptedContent: encrypted)
            step = .share
        } catch {
            errorMessage = error.localizedDescription
            step = .setPin
        }
    }
}
