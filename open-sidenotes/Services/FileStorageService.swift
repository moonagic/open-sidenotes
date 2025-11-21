import Foundation

class FileStorageService {
    static let shared = FileStorageService()

    private let fileManager = FileManager.default
    private let storageDirectoryKey = "customStorageDirectory"

    var storageDirectory: URL {
        get {
            if let customPath = UserDefaults.standard.string(forKey: storageDirectoryKey) {
                return URL(fileURLWithPath: customPath)
            }
            return Constants.defaultNotesDirectory()
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: storageDirectoryKey)
            createStorageDirectoryIfNeeded()
        }
    }

    private init() {
        createStorageDirectoryIfNeeded()
    }

    func loadAllNotes() async throws -> [Note] {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "md" }

        return try await withThrowingTaskGroup(of: Note?.self) { group in
            for fileURL in fileURLs {
                group.addTask {
                    try? await self.loadNote(from: fileURL)
                }
            }

            var notes: [Note] = []
            for try await note in group {
                if let note = note {
                    notes.append(note)
                }
            }
            return notes.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func saveNote(_ note: Note) async throws {
        // Remove old file if title changed
        try? await removeOldFile(for: note)

        let fileURL = fileURL(for: note)
        let content = formatNoteContent(note)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func deleteNote(_ note: Note) async throws {
        // Find and delete file by ID
        if let existingURL = findFile(byId: note.id) {
            try fileManager.removeItem(at: existingURL)
        }
    }

    func fileURL(for note: Note) -> URL {
        let safeName = sanitizeFileName(note.title)
        let baseName = safeName.isEmpty ? "Untitled" : safeName
        return uniqueFileURL(baseName: baseName, noteId: note.id)
    }

    private func sanitizeFileName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.components(separatedBy: illegal).joined()
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func uniqueFileURL(baseName: String, noteId: UUID) -> URL {
        let baseURL = storageDirectory.appendingPathComponent("\(baseName).md")

        // If file doesn't exist or belongs to same note, use base name
        if !fileManager.fileExists(atPath: baseURL.path) {
            return baseURL
        }

        if let existingNote = try? loadNoteSync(from: baseURL), existingNote.id == noteId {
            return baseURL
        }

        // Find unique name with suffix
        var counter = 1
        while true {
            let url = storageDirectory.appendingPathComponent("\(baseName) \(counter).md")
            if !fileManager.fileExists(atPath: url.path) {
                return url
            }
            if let existingNote = try? loadNoteSync(from: url), existingNote.id == noteId {
                return url
            }
            counter += 1
        }
    }

    private func findFile(byId id: UUID) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter({ $0.pathExtension == "md" }) else { return nil }

        for file in files {
            if let note = try? loadNoteSync(from: file), note.id == id {
                return file
            }
        }
        return nil
    }

    private func removeOldFile(for note: Note) async throws {
        guard let oldURL = findFile(byId: note.id) else { return }
        let newURL = fileURL(for: note)

        if oldURL != newURL {
            try fileManager.removeItem(at: oldURL)
        }
    }

    private func loadNoteSync(from fileURL: URL) throws -> Note {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return parseNoteContent(content, fileURL: fileURL)
    }

    private func loadNote(from fileURL: URL) async throws -> Note {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return parseNoteContent(content, fileURL: fileURL)
    }

    private func formatNoteContent(_ note: Note) -> String {
        """
        ---
        title: \(note.title)
        id: \(note.id.uuidString)
        createdAt: \(ISO8601DateFormatter().string(from: note.createdAt))
        updatedAt: \(ISO8601DateFormatter().string(from: note.updatedAt))
        ---

        \(note.content)
        """
    }

    private func parseNoteContent(_ content: String, fileURL: URL) -> Note {
        let components = content.components(separatedBy: "---")

        guard components.count >= 3 else {
            return Note(
                id: UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent) ?? UUID(),
                title: "Untitled",
                content: content,
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        let frontMatter = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let markdownContent = components[2...].joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)

        var title = "Untitled"
        var id = UUID()
        var createdAt = Date()
        var updatedAt = Date()

        let lines = frontMatter.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ": ")
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            switch key {
            case "title":
                title = value
            case "id":
                id = UUID(uuidString: value) ?? UUID()
            case "createdAt":
                createdAt = ISO8601DateFormatter().date(from: value) ?? Date()
            case "updatedAt":
                updatedAt = ISO8601DateFormatter().date(from: value) ?? Date()
            default:
                break
            }
        }

        return Note(
            id: id,
            title: title,
            content: markdownContent,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func createStorageDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
