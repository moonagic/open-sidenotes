import Foundation

enum QuickOpenSearchService {
    static func rankedNotes(
        from notes: [Note],
        query: String,
        recentNoteIDs: [UUID],
        limit: Int = 24
    ) -> [Note] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let recentRank = Dictionary(uniqueKeysWithValues: recentNoteIDs.enumerated().map { ($1, $0) })

        let scored = notes.compactMap { note -> (note: Note, score: Int, recentOrder: Int)? in
            let recentOrder = recentRank[note.id] ?? Int.max
            let recentBonus = recentOrder == Int.max ? 0 : max(0, 80 - recentOrder * 3)

            guard !trimmedQuery.isEmpty else {
                return (note, recentBonus, recentOrder)
            }

            let title = note.title.lowercased()
            let content = note.content.lowercased()
            let tokens = trimmedQuery.split(separator: " ").map(String.init)

            var score = recentBonus

            if title.contains(trimmedQuery) {
                score += 140
            }
            if content.contains(trimmedQuery) {
                score += 70
            }

            for token in tokens where !token.isEmpty {
                if title.contains(token) {
                    score += 35
                } else if isSubsequence(token, in: title) {
                    score += 18
                }

                if content.contains(token) {
                    score += 16
                } else if isSubsequence(token, in: content) {
                    score += 8
                }
            }

            if score <= recentBonus {
                return nil
            }

            return (note, score, recentOrder)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.recentOrder != rhs.recentOrder { return lhs.recentOrder < rhs.recentOrder }
                if lhs.note.updatedAt != rhs.note.updatedAt { return lhs.note.updatedAt > rhs.note.updatedAt }
                return lhs.note.createdAt > rhs.note.createdAt
            }
            .prefix(limit)
            .map(\.note)
    }

    private static func isSubsequence(_ needle: String, in haystack: String) -> Bool {
        if needle.isEmpty { return true }
        var needleIndex = needle.startIndex

        for char in haystack {
            if char == needle[needleIndex] {
                needle.formIndex(after: &needleIndex)
                if needleIndex == needle.endIndex {
                    return true
                }
            }
        }

        return false
    }
}
