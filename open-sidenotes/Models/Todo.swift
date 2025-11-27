import Foundation

struct Todo: Identifiable, Equatable, Hashable {
    let id: UUID
    var listId: UUID
    var title: String
    var description: String
    var isCompleted: Bool
    var priority: Priority
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    enum Priority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }

    init(
        id: UUID = UUID(),
        listId: UUID,
        title: String,
        description: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.listId = listId
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.priority = priority
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
