import Foundation

struct TodoList: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var name: String
    let icon: String
    let color: String
    var createdAt: Date
    var updatedAt: Date
    let isInbox: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "tray.fill",
        color: String = "7C9885",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isInbox: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isInbox = isInbox
    }

}
