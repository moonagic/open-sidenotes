import Foundation

final class RecentNotesManager {
    static let shared = RecentNotesManager()

    private let key = "recentOpenedNoteIDs_v1"
    private let maxCount = 40

    private init() {}

    func recentNoteIDs() -> [UUID] {
        guard let raw = UserDefaults.standard.array(forKey: key) as? [String] else {
            return []
        }

        return raw.compactMap { UUID(uuidString: $0) }
    }

    func record(noteID: UUID) {
        var ids = recentNoteIDs()
        ids.removeAll { $0 == noteID }
        ids.insert(noteID, at: 0)

        if ids.count > maxCount {
            ids = Array(ids.prefix(maxCount))
        }

        UserDefaults.standard.set(ids.map(\.uuidString), forKey: key)
    }
}
