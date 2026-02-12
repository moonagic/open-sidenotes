import Foundation

enum QuickOpenSearchService {
    struct IndexedNote {
        let note: Note
        let title: String
        let content: String
    }

    private static let indexedContentCharacterLimit = 2400
    private static let maxQueryTokens = 6

    static func buildIndex(from notes: [Note]) -> [IndexedNote] {
        notes.map { note in
            let limitedContent = String(note.content.prefix(indexedContentCharacterLimit))
            let normalizedContent = limitedContent
                .replacingOccurrences(of: "\n", with: " ")
                .lowercased()

            return IndexedNote(
                note: note,
                title: note.title.lowercased(),
                content: normalizedContent
            )
        }
    }

    static func rankedNotes(
        from notes: [Note],
        query: String,
        recentNoteIDs: [UUID],
        limit: Int = 24
    ) -> [Note] {
        rankedNotes(
            from: buildIndex(from: notes),
            query: query,
            recentNoteIDs: recentNoteIDs,
            limit: limit
        )
    }

    static func rankedNotes(
        from indexedNotes: [IndexedNote],
        query: String,
        recentNoteIDs: [UUID],
        limit: Int = 24
    ) -> [Note] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tokens = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .prefix(maxQueryTokens)
            .map(String.init)
        let recentRank = Dictionary(uniqueKeysWithValues: recentNoteIDs.enumerated().map { ($1, $0) })

        let scored = indexedNotes.compactMap { indexedNote -> (note: Note, score: Int, recentOrder: Int)? in
            let recentOrder = recentRank[indexedNote.note.id] ?? Int.max
            let recentBonus = recentOrder == Int.max ? 0 : max(0, 80 - recentOrder * 3)

            guard !trimmedQuery.isEmpty else {
                return (indexedNote.note, recentBonus, recentOrder)
            }

            let title = indexedNote.title
            let content = indexedNote.content

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
                }
            }

            if score <= recentBonus {
                return nil
            }

            return (indexedNote.note, score, recentOrder)
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
