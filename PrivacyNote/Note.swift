import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var isProtected: Bool

    init(title: String = "", content: String = "", isProtected: Bool = true) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.isProtected = isProtected
    }
}
