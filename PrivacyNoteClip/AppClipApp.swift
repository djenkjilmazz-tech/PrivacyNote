import SwiftUI

@main
struct AppClipApp: App {
    @State private var noteTitle = ""
    @State private var encryptedPayload = ""
    @State private var hasPayload = false

    var body: some Scene {
        WindowGroup {
            AppClipContentView(
                title: noteTitle,
                encryptedPayload: encryptedPayload,
                hasPayload: hasPayload
            )
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                parseURL(url)
            }
            .onOpenURL { url in
                parseURL(url)
            }
        }
    }

    private func parseURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return }
        noteTitle = items.first(where: { $0.name == "t" })?.value ?? ""
        let raw = items.first(where: { $0.name == "p" })?.value ?? ""
        let base64 = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
        encryptedPayload = padded
        hasPayload = !raw.isEmpty
    }
}
