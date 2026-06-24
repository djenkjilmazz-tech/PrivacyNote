import SwiftUI

@main
struct AppClipApp: App {
    @State private var noteTitle = ""
    @State private var noteToken = ""
    @State private var hasToken  = false

    var body: some Scene {
        WindowGroup {
            AppClipContentView(title: noteTitle, token: noteToken, hasToken: hasToken)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL,
                          let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let items = c.queryItems,
                          let token = items.first(where: { $0.name == "id" })?.value,
                          !token.isEmpty else { return }
                    noteTitle = items.first(where: { $0.name == "t" })?.value ?? ""
                    noteToken = token
                    hasToken  = true
                }
        }
    }
}
