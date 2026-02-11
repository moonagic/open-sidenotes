import Foundation

enum ChatMessageRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatMessageRole
    let content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: ChatMessageRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
