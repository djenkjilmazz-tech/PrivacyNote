import SwiftUI

struct ContentView: View {
    @State private var showingCompose = false
    @State private var incomingNote: IncomingNote? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer()
                    heroSection
                    Spacer()
                    composeButton
                    howItWorksSection
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingCompose) {
            ComposeView()
        }
        .sheet(item: $incomingNote) { note in
            NoteReaderView(title: note.title, token: note.token, encryptedPayload: note.encryptedPayload)
        }
        .onOpenURL { url in
            incomingNote = parseNote(from: url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                incomingNote = parseNote(from: url)
            }
        }
    }

    private func parseNote(from url: URL) -> IncomingNote? {
        if let t = ShareLinkManager.parseToken(url: url) {
            return IncomingNote(title: t.title, token: t.token, encryptedPayload: nil)
        }
        if let p = ShareLinkManager.parse(url: url) {
            return IncomingNote(title: p.title, token: nil, encryptedPayload: p.encryptedContent)
        }
        return nil
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "flame.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)

            Text("PrivacyNote")
                .font(.largeTitle.weight(.bold))

            Text("Gizli mesajlar — bir kez okunur, sonra yok olur")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var composeButton: some View {
        Button {
            showingCompose = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.doc.fill")
                Text("Yeni Gizli Not Oluştur")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nasıl Çalışır?")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { i in
                    HStack(spacing: 14) {
                        Image(systemName: steps[i].icon)
                            .foregroundStyle(.orange)
                            .frame(width: 22)
                        Text(steps[i].text)
                            .font(.callout)
                        Spacer()
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 14)

                    if i < steps.count - 1 {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 24)
    }

    private let steps: [(icon: String, text: String)] = [
        ("pencil.and.list.clipboard", "Gizli notunu yaz"),
        ("lock.fill",                 "6 haneli PIN ile şifrele"),
        ("link",                       "Paylaşılabilir link oluşur"),
        ("iphone.and.arrow.forward",   "Alıcı linki açar, PIN'i girer"),
        ("flame.fill",                 "Okunduğunda oturum yok olur")
    ]
}

#Preview {
    ContentView()
}
