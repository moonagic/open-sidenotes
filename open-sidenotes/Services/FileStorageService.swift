import Foundation

class FileStorageService {
    static let shared = FileStorageService()

    private let fileManager = FileManager.default
    private let storageDirectoryKey = "customStorageDirectory"
    private let lock = NSLock()
    private let iso8601Formatter = ISO8601DateFormatter()
    private let shouldPersistStorageDirectory: Bool
    private var storageDirectoryURL: URL

    private var noteFileIndex: [UUID: URL] = [:]
    private var fileOwnerIndex: [URL: UUID] = [:]
    private var indexHydrated = false
    private var indexedStoragePath: String?

    var storageDirectory: URL {
        get {
            storageDirectoryURL
        }
        set {
            let normalizedDirectory = newValue.standardizedFileURL
            lock.lock()
            defer { lock.unlock() }
            storageDirectoryURL = normalizedDirectory
            resetIndexIfNeededLocked(for: normalizedDirectory.path)
            try? createStorageDirectoryIfNeeded(at: normalizedDirectory)

            if shouldPersistStorageDirectory {
                UserDefaults.standard.set(normalizedDirectory.path, forKey: storageDirectoryKey)
            }
        }
    }

    private init(
        shouldPersistStorageDirectory: Bool = true,
        initialDirectory: URL? = nil
    ) {
        self.shouldPersistStorageDirectory = shouldPersistStorageDirectory

        if let initialDirectory {
            storageDirectoryURL = initialDirectory.standardizedFileURL
        } else if let customPath = UserDefaults.standard.string(forKey: storageDirectoryKey) {
            storageDirectoryURL = URL(fileURLWithPath: customPath).standardizedFileURL
        } else {
            storageDirectoryURL = Constants.defaultNotesDirectory().standardizedFileURL
        }

        lock.lock()
        defer { lock.unlock() }
        try? createStorageDirectoryIfNeeded(at: storageDirectoryURL)
        indexedStoragePath = storageDirectoryURL.path
    }

    convenience init(volatileStorageDirectory directory: URL) {
        self.init(
            shouldPersistStorageDirectory: false,
            initialDirectory: directory
        )
    }

    func loadAllNotes() async throws -> [Note] {
        try withStorageLock {
            resetIndexIfNeededLocked()
            try createStorageDirectoryIfNeededLocked()

            let fileURLs = try markdownFileURLsLocked()

            noteFileIndex.removeAll()
            fileOwnerIndex.removeAll()

            var notes: [Note] = []
            notes.reserveCapacity(fileURLs.count)

            for fileURL in fileURLs {
                let note = try loadNoteSync(from: fileURL)
                notes.append(note)
                setIndexLocked(noteID: note.id, fileURL: fileURL)
            }

            indexHydrated = true

            return notes.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func saveNote(_ note: Note) async throws {
        try withStorageLock {
            try saveNoteLocked(note)
        }
    }

    func saveNoteImmediately(_ note: Note) throws {
        try withStorageLock {
            try saveNoteLocked(note)
        }
    }

    func deleteNote(_ note: Note) async throws {
        try withStorageLock {
            resetIndexIfNeededLocked()
            try createStorageDirectoryIfNeededLocked()
            try hydrateIndexIfNeededLocked()

            let existingURL: URL?
            if let indexedURL = noteFileIndex[note.id] {
                existingURL = indexedURL
            } else {
                existingURL = try findFileByIDLocked(note.id)
            }

            if let existingURL {
                try fileManager.removeItem(at: existingURL)
                noteFileIndex.removeValue(forKey: note.id)
                fileOwnerIndex.removeValue(forKey: existingURL)
            }
        }
    }

    private func preferredBaseFileURL(for note: Note) -> URL {
        let safeName = sanitizeFileName(note.title)
        let baseName = safeName.isEmpty ? "Untitled" : safeName
        return storageDirectory.standardizedFileURL.appendingPathComponent("\(baseName).md")
    }

    private func sanitizeFileName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.components(separatedBy: illegal).joined()
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func destinationFileURLLocked(for note: Note) throws -> URL {
        let baseURL = preferredBaseFileURL(for: note).standardizedFileURL

        if canUseFileURLLocked(baseURL, noteID: note.id) {
            return baseURL
        }

        let baseName = baseURL.deletingPathExtension().lastPathComponent
        var counter = 1

        while true {
            let candidateURL = storageDirectory
                .standardizedFileURL
                .appendingPathComponent("\(baseName) \(counter).md")
            if canUseFileURLLocked(candidateURL, noteID: note.id) {
                return candidateURL.standardizedFileURL
            }
            counter += 1
        }
    }

    private func saveNoteLocked(_ note: Note) throws {
        resetIndexIfNeededLocked()
        try createStorageDirectoryIfNeededLocked()
        try hydrateIndexIfNeededLocked()

        let previousURL: URL?
        if let indexedURL = noteFileIndex[note.id] {
            previousURL = indexedURL
        } else {
            previousURL = try findFileByIDLocked(note.id)
        }

        if let previousURL,
           fileManager.fileExists(atPath: previousURL.path),
           let existingNote = try? loadNoteSync(from: previousURL),
           !hasMeaningfulPersistenceChange(existing: existingNote, incoming: note) {
            setIndexLocked(noteID: note.id, fileURL: previousURL)
            return
        }

        let fileURL = try destinationFileURLLocked(for: note)
        let content = formatNoteContent(note)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        if let previousURL, previousURL != fileURL, fileManager.fileExists(atPath: previousURL.path) {
            do {
                try fileManager.removeItem(at: previousURL)
            } catch CocoaError.fileNoSuchFile {
                // Ignore: old file already gone.
            }
            fileOwnerIndex.removeValue(forKey: previousURL)
        }

        setIndexLocked(noteID: note.id, fileURL: fileURL)
    }

    private func hasMeaningfulPersistenceChange(existing: Note, incoming: Note) -> Bool {
        let existingTitle = normalizeTitleForPersistence(existing.title)
        let incomingTitle = normalizeTitleForPersistence(incoming.title)
        let existingContent = normalizeContentForPersistence(existing.content)
        let incomingContent = normalizeContentForPersistence(incoming.content)

        return existingTitle != incomingTitle || existingContent != incomingContent
    }

    private func normalizeTitleForPersistence(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeContentForPersistence(_ content: String) -> String {
        content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private func canUseFileURLLocked(_ fileURL: URL, noteID: UUID) -> Bool {
        let normalizedURL = fileURL.standardizedFileURL

        if !fileManager.fileExists(atPath: normalizedURL.path) {
            return true
        }

        if let ownerID = ownerIDLocked(for: normalizedURL), ownerID == noteID {
            return true
        }

        return false
    }

    private func ownerIDLocked(for fileURL: URL) -> UUID? {
        let normalizedURL = fileURL.standardizedFileURL

        if let owner = fileOwnerIndex[normalizedURL] {
            return owner
        }

        guard fileManager.fileExists(atPath: normalizedURL.path) else {
            return nil
        }

        guard let note = try? loadNoteSync(from: normalizedURL) else {
            return nil
        }

        setIndexLocked(noteID: note.id, fileURL: normalizedURL)
        return note.id
    }

    private func findFileByIDLocked(_ id: UUID) throws -> URL? {
        if let indexedURL = noteFileIndex[id] {
            return indexedURL
        }

        let files = try markdownFileURLsLocked()
        for file in files {
            if let note = try? loadNoteSync(from: file), note.id == id {
                setIndexLocked(noteID: id, fileURL: file)
                return file
            }
        }

        return nil
    }

    private func hydrateIndexIfNeededLocked() throws {
        guard !indexHydrated else {
            return
        }

        let fileURLs = try markdownFileURLsLocked()
        for fileURL in fileURLs {
            if fileOwnerIndex[fileURL] != nil {
                continue
            }
            if let note = try? loadNoteSync(from: fileURL) {
                setIndexLocked(noteID: note.id, fileURL: fileURL)
            }
        }

        indexHydrated = true
    }

    private func markdownFileURLsLocked() throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "md" }
        .map { $0.standardizedFileURL }
    }

    private func setIndexLocked(noteID: UUID, fileURL: URL) {
        let normalizedURL = fileURL.standardizedFileURL

        if let oldURL = noteFileIndex[noteID], oldURL != normalizedURL {
            fileOwnerIndex.removeValue(forKey: oldURL)
        }

        noteFileIndex[noteID] = normalizedURL
        fileOwnerIndex[normalizedURL] = noteID
    }

    private func resetIndexIfNeededLocked(for path: String? = nil) {
        let currentPath = path ?? storageDirectory.path

        if indexedStoragePath != currentPath {
            noteFileIndex.removeAll()
            fileOwnerIndex.removeAll()
            indexHydrated = false
            indexedStoragePath = currentPath
        }
    }

    private func loadNoteSync(from fileURL: URL) throws -> Note {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return parseNoteContent(content, fileURL: fileURL)
    }

    private func formatNoteContent(_ note: Note) -> String {
        let encodedTitle = encodeFrontMatterString(note.title)
        return [
            "---",
            "title: \(encodedTitle)",
            "id: \(note.id.uuidString)",
            "createdAt: \(iso8601Formatter.string(from: note.createdAt))",
            "updatedAt: \(iso8601Formatter.string(from: note.updatedAt))",
            "---",
            "",
            note.content
        ].joined(separator: "\n")
    }

    private func parseNoteContent(_ content: String, fileURL: URL) -> Note {
        guard let split = splitFrontMatter(from: content) else {
            return Note(
                id: UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent) ?? UUID(),
                title: "Untitled",
                content: content,
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        let frontMatter = split.frontMatter
        let markdownContent = split.content

        var title = "Untitled"
        var id = UUID()
        var createdAt = Date()
        var updatedAt = Date()

        let lines = frontMatter.components(separatedBy: .newlines)
        for line in lines {
            guard let (key, rawValue) = parseFrontMatterLine(line) else { continue }
            let value = decodeFrontMatterString(rawValue)

            switch key {
            case "title":
                title = value
            case "id":
                id = UUID(uuidString: value) ?? UUID()
            case "createdAt":
                createdAt = iso8601Formatter.date(from: value) ?? Date()
            case "updatedAt":
                updatedAt = iso8601Formatter.date(from: value) ?? Date()
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

    private func splitFrontMatter(from rawContent: String) -> (frontMatter: String, content: String)? {
        let normalized = rawContent.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        guard lines.first == "---" else {
            return nil
        }

        guard let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
            return nil
        }

        let frontMatterLines = Array(lines[1..<closingIndex])
        let contentStart = lines.index(after: closingIndex)
        var contentLines = contentStart < lines.count ? Array(lines[contentStart...]) : []

        // Drop the separator blank line written between front matter and body.
        if contentLines.first == "" {
            contentLines.removeFirst()
        }

        return (
            frontMatterLines.joined(separator: "\n"),
            contentLines.joined(separator: "\n")
        )
    }

    private func parseFrontMatterLine(_ line: String) -> (String, String)? {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return nil
        }

        let key = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
        let valueStart = line.index(after: colonIndex)
        let value = line[valueStart...].trimmingCharacters(in: .whitespaces)

        guard !key.isEmpty else {
            return nil
        }

        return (key, value)
    }

    private func encodeFrontMatterString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return encoded
    }

    private func decodeFrontMatterString(_ rawValue: String) -> String {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(String.self, from: data) else {
            return rawValue
        }
        return decoded
    }

    private func createStorageDirectoryIfNeededLocked() throws {
        try createStorageDirectoryIfNeeded(at: storageDirectory)
    }

    private func createStorageDirectoryIfNeeded(at directory: URL) throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private func withStorageLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
