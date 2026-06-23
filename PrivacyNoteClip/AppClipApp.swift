import SwiftUI

@main
struct AppClipApp: App {
    @State private var noteTitle = ""
    @State private var noteToken = ""
    @State private var hasPayload = false

    var body: some Scene {
        WindowGroup {
            AppClipContentView(
                title: noteTitle,
                token: noteToken,
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
        noteToken = items.first(where: { $0.name == "id" })?.value ?? ""
        hasPayload = !noteToken.isEmpty
    }
}
