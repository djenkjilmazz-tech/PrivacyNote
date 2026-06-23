import Foundation
import CoreImage
import UIKit

struct SharePayload {
    let title: String
    let encryptedContent: String
}

struct ShareLinkManager {
    // MARK: - CloudKit token URL (new flow)

    static func createTokenURL(title: String, token: String) -> URL? {
        var c = URLComponents()
        c.scheme = "https"
        c.host = "privacynote.app"
        c.path = "/r"
        c.queryItems = [
            URLQueryItem(name: "t", value: title),
            URLQueryItem(name: "id", value: token)
        ]
        return c.url
    }

    static func parseToken(url: URL) -> (title: String, token: String)? {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = c.queryItems,
              let title = items.first(where: { $0.name == "t" })?.value,
              let token = items.first(where: { $0.name == "id" })?.value,
              !token.isEmpty else { return nil }
        return (title, token)
    }

    // MARK: - Legacy inline-payload URL (kept for NoteShareView compatibility)

    static func createURL(title: String, encryptedContent: String) -> URL? {
        var c = URLComponents()
        c.scheme = "https"
        c.host = "privacynote.app"
        c.path = "/r"
        let safe = encryptedContent
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        c.queryItems = [
            URLQueryItem(name: "t", value: title),
            URLQueryItem(name: "p", value: safe)
        ]
        return c.url
    }

    static func parse(url: URL) -> SharePayload? {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = c.queryItems,
              let title = items.first(where: { $0.name == "t" })?.value,
              let raw = items.first(where: { $0.name == "p" })?.value else { return nil }
        let base64 = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return SharePayload(title: title, encryptedContent: padded)
    }

    // MARK: - QR Code

    static func generateQRCode(url: URL) -> UIImage? {
        guard let data = url.absoluteString.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        return UIImage(ciImage: scaled)
    }
}
