import SwiftUI

struct NoteDetailView: View {
    @Bindable var note: Note
    @State private var proximityManager = ProximityManager()
    @State private var screenshotDetector = ScreenshotDetector()
    @State private var showingEditor = false
    @State private var showingShare = false

    var body: some View {
        ZStack {
            mainContent
            if screenshotDetector.didCapture {
                Color.black.ignoresSafeArea()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.1), value: screenshotDetector.didCapture)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { showingShare = true } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                Button { showingEditor = true } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NoteEditorView(note: note)
        }
        .sheet(isPresented: $showingShare) {
            NoteShareView(note: note)
        }
        .onAppear {
            if note.isProtected { proximityManager.startMonitoring() }
            screenshotDetector.startMonitoring()
        }
        .onDisappear {
            proximityManager.stopMonitoring()
            screenshotDetector.stopMonitoring()
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.title.isEmpty ? "Başlıksız" : note.title)
                        .font(.largeTitle.weight(.bold))
                    HStack(spacing: 8) {
                        Image(systemName: note.isProtected ? "lock.fill" : "lock.open")
                            .foregroundStyle(note.isProtected ? .orange : .secondary)
                            .font(.caption)
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Divider()

                ZStack(alignment: .center) {
                    Text(note.content.isEmpty ? "İçerik yok." : note.content)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .blur(radius: shouldBlur ? 10 : 0)
                        .animation(.easeInOut(duration: 0.25), value: shouldBlur)

                    if shouldBlur {
                        privacyOverlay
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var shouldBlur: Bool {
        note.isProtected && !proximityManager.isNear
    }

    private var privacyOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.85))
            Text("Okumak için telefonu yüzüne tut")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Yakınlık sensörü koruması aktif")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
