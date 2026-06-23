import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        embedMessagesUI()
    }

    private func embedMessagesUI() {
        let rootView = MessagesRootView { [weak self] title, preview in
            self?.insertMessage(title: title, preview: preview)
        }
        let host = UIHostingController(rootView: rootView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    private func insertMessage(title: String, preview: String) {
        guard let conversation = activeConversation else { return }

        let message = MSMessage()
        let layout = MSMessageTemplateLayout()
        layout.caption = "🔐 \(title)"
        layout.subcaption = "Görmek için uygulamayı aç"
        layout.trailingSubcaption = "PrivacyNote"
        message.layout = layout

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "preview", value: String(preview.prefix(120)))
        ]
        message.url = components.url

        conversation.insert(message) { error in
            if let error { print("Mesaj eklenemedi: \(error)") }
        }
    }
}
