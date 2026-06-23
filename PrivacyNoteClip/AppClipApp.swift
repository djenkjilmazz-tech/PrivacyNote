import SwiftUI

@main
struct AppClipApp: App {
    @State private var noteTitle = ""
    @State private var encryptedPayload = ""   // AES base64 from URL
    @State private var cloudKitToken = ""       // CloudKit token from URL
    @State private var hasPayload = false

    var body: some Scene {
        WindowGroup {
            AppClipContentView(
                title: noteTitle,
                encryptedPayload: encryptedPayload,
                cloudKitToken: cloudKitToken,
                hasPayload: hasPayload
            )
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { parseURL(url) }
            }
            .onOpenURL { url in parseURL(url) }
        }
    }

    private func parseURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return }

        noteTitle = items.first(where: { $0.name == "t" })?.value ?? ""

        // CloudKit token URL: ?t=title&id=token
        if let token = items.first(where: { $0.name == "id" })?.value, !token.isEmpty {
            cloudKitToken = token
            hasPayload = true
            return
        }

        // Inline encrypted URL: ?t=title&p=base64payload
        if let raw = items.first(where: { $0.name == "p" })?.value, !raw.isEmpty {
            let base64 = raw
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
            encryptedPayload = padded
            hasPayload = true
        }
    }
}
