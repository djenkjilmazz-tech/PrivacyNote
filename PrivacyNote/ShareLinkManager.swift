import Foundation
import CoreImage
import UIKit

struct SharePayload {
    let title: String
    let encryptedContent: String
}

struct ShareLinkManager {
    static func createURL(title: String, encryptedContent: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "privacynote.app"
        components.path = "/r"
        let safePayload = encryptedContent
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        components.queryItems = [
            URLQueryItem(name: "t", value: title),
            URLQueryItem(name: "p", value: safePayload)
        ]
        return components.url
    }

    static func parse(url: URL) -> SharePayload? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              let title = items.first(where: { $0.name == "t" })?.value,
              let raw = items.first(where: { $0.name == "p" })?.value else { return nil }
        let base64 = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return SharePayload(title: title, encryptedContent: padded)
    }

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
