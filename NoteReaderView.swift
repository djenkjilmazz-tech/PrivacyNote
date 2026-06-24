import SwiftUI

struct IncomingNote: Identifiable {
    let id = UUID()
    let title: String
    let token: String
}

struct NoteReaderView: View {
    let title: String
    let token: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var step: Step = .fetching
    @State private var encryptedContent = ""
    @State private var serverWrongAttempts = 0
    @State private var decryptedContent = ""
    @State private var attemptsLeft = 3
    @State private var pinInput = ""
    @State private var errorMsg = ""
    @State private var screenshotObserver: NSObjectProtocol?
    @FocusState private var pinFocused: Bool

    private enum Step { case fetching, enterPin, wrongPin, content, burned, error }
    private let pinLength = 6

    var body: some View {
        NavigationStack {
            Group {
                switch step {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .opacity(step == .content || step == .burned ? 0 : 1)
                }
            }
        }
        .task { await loadNote() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && step == .content {
                Task { await burnAndClose() }
            }
        }
        .interactiveDismissDisabled(step == .content)
    }

    // MARK: - Views

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
            Button("Kapat") { dismiss() }.buttonStyle(.borderedProminent).tint(.orange).padding(.top, 8)
            Spacer()
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "icloud.slash.fill").font(.system(size: 52)).foregroundStyle(.red)
            Text("Hata").font(.title2.weight(.bold))
            Text(errorMsg).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Button("Kapat") { dismiss() }.buttonStyle(.bordered).padding(.top, 8)
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

    // MARK: - Logic

    private func loadNote() async {
        do {
            let row = try await BackendManager.shared.fetchNote(token: token)
            encryptedContent = row.encryptedContent
            serverWrongAttempts = row.wrongAttempts
            attemptsLeft = 3 - row.wrongAttempts
            await MainActor.run { step = .enterPin }
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run { pinFocused = true }
        } catch let err as BackendError {
            await MainActor.run {
                if err == .alreadyBurned || err == .notFound {
                    step = .burned
                } else {
                    errorMsg = err.localizedDescription
                    step = .error
                }
            }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription; step = .error }
        }
    }

    private func attemptDecrypt(pin: String) async {
        do {
            let text = try CryptoManager.decrypt(encryptedContent, pin: pin)
            await MainActor.run { decryptedContent = text; step = .content }
        } catch {
            do {
                let remaining = try await BackendManager.shared.recordWrongAttempt(
                    token: token, currentServerCount: serverWrongAttempts)
                serverWrongAttempts += 1
                await MainActor.run { pinInput = ""; attemptsLeft = remaining; step = .wrongPin }
            } catch BackendError.tooManyAttempts {
                await MainActor.run { step = .burned }
            } catch {
                await MainActor.run { pinInput = ""; attemptsLeft -= 1
                    step = attemptsLeft > 0 ? .wrongPin : .burned }
            }
        }
    }

    private func burnAndClose() async {
        stopScreenshotWatcher()
        await BackendManager.shared.burnNote(token: token)
        await MainActor.run { withAnimation(.easeInOut(duration: 0.25)) { step = .burned } }
    }
}
