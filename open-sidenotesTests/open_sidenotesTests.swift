import Testing
import SwiftUI
import AppKit
@testable import open_sidenotes

struct open_sidenotesTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

class CodeBlockEditorTests {

    @Test func coordinatorCopiesCodeToClipboard() throws {
        let testCode = "let x = 42"
        let binding = Binding<String>(
            get: { testCode },
            set: { _ in }
        )

        let editor = CodeBlockEditor(
            code: binding,
            language: .swift,
            onCodeChange: { _ in }
        )

        let coordinator = editor.makeCoordinator()

        NSPasteboard.general.clearContents()
        coordinator.copyCode()

        let clipboardContent = NSPasteboard.general.string(forType: .string)
        #expect(clipboardContent == testCode, "Clipboard should contain the code after copyCode() is called")
    }

    @Test func coordinatorChangesCopyButtonIcon() throws {
        let testCode = "func test() {}"
        let binding = Binding<String>(
            get: { testCode },
            set: { _ in }
        )

        let editor = CodeBlockEditor(
            code: binding,
            language: .swift,
            onCodeChange: { _ in }
        )

        let coordinator = editor.makeCoordinator()

        let copyButton = NSButton()
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
        coordinator.copyButton = copyButton

        coordinator.showCopyFeedback()

        #expect(copyButton.image?.accessibilityDescription == "Copied", "Icon should change to checkmark after showCopyFeedback()")
    }
}

struct QuickOpenSearchServiceTests {
    @Test func searchMatchesBodyContent() throws {
        let notes = [
            Note(title: "Untitled", content: "alpha beta keyword here"),
            Note(title: "Other", content: "nothing")
        ]

        let result = QuickOpenSearchService.rankedNotes(
            from: notes,
            query: "keyword",
            recentNoteIDs: []
        )

        #expect(result.first?.title == "Untitled")
    }

    @Test func searchPrefersRecentWhenScoresAreSimilar() throws {
        let noteA = Note(id: UUID(), title: "Meeting Plan", content: "same body")
        let noteB = Note(id: UUID(), title: "Meeting Plan", content: "same body")

        let result = QuickOpenSearchService.rankedNotes(
            from: [noteA, noteB],
            query: "meeting",
            recentNoteIDs: [noteB.id, noteA.id]
        )

        #expect(result.first?.id == noteB.id)
    }
}

struct SlashCommandTests {
    @Test func dateCommandResolvesCurrentDate() throws {
        let formatter = ISO8601DateFormatter()
        let fixedDate = formatter.date(from: "2026-02-12T12:00:00Z")!
        let dateCommand = SlashCommand.allCommands.first { $0.trigger == "date" }!

        let output = dateCommand.resolvedTemplate(referenceDate: fixedDate)
        #expect(output == "2026-02-12")
    }

    @Test func dailyTemplateResolvesDatePlaceholder() throws {
        let formatter = ISO8601DateFormatter()
        let fixedDate = formatter.date(from: "2026-02-12T12:00:00Z")!
        let dailyCommand = SlashCommand.allCommands.first { $0.trigger == "daily" }!

        let output = dailyCommand.resolvedTemplate(referenceDate: fixedDate)
        #expect(output.contains("Date: 2026-02-12"))
        #expect(output.contains(SlashCommand.cursorMarker))
    }
}

actor StorageTestLock {
    static let shared = StorageTestLock()

    func run<T>(_ operation: () async throws -> T) async throws -> T {
        try await operation()
    }
}

struct FileStorageServiceTests {
    @Test func roundTripsTitleContainingColon() async throws {
        try await StorageTestLock.shared.run {
            try await withIsolatedStorage { service, _ in
                let note = Note(
                    title: "计划: 第一周",
                    content: "first line\nsecond line"
                )

                try await service.saveNote(note)
                let loaded = try await service.loadAllNotes()
                let reloaded = try #require(loaded.first(where: { $0.id == note.id }))

                #expect(reloaded.title == note.title)
                #expect(reloaded.content == note.content)
            }
        }
    }

    @Test func keepsUniqueFilesForSameTitleAndRapidRename() async throws {
        try await StorageTestLock.shared.run {
            try await withIsolatedStorage { service, directory in
                var first = Note(title: "Same Title", content: "alpha")
                let second = Note(title: "Same Title", content: "beta")

                try await service.saveNote(first)
                try await service.saveNote(second)

                first.title = "Renamed Once"
                first.content = "alpha 1"
                first.updatedAt = Date()
                try await service.saveNote(first)

                first.title = "Same Title"
                first.content = "alpha 2"
                first.updatedAt = Date()
                try await service.saveNote(first)

                first.title = "Final Title"
                first.content = "alpha 3"
                first.updatedAt = Date()
                try await service.saveNote(first)

                let files = try markdownFiles(in: directory)
                #expect(files.count == 2)

                let loaded = try await service.loadAllNotes()
                #expect(loaded.contains(where: { $0.id == first.id && $0.title == "Final Title" }))
                #expect(loaded.contains(where: { $0.id == second.id && $0.title == "Same Title" }))
            }
        }
    }

    @Test func deleteAfterRenameRemovesCurrentFile() async throws {
        try await StorageTestLock.shared.run {
            try await withIsolatedStorage { service, directory in
                var note = Note(title: "Draft", content: "keep")
                try await service.saveNote(note)

                note.title = "Draft Updated"
                note.updatedAt = Date()
                try await service.saveNote(note)

                try await service.deleteNote(note)

                let files = try markdownFiles(in: directory)
                #expect(files.isEmpty)
            }
        }
    }

    @Test func loadsLegacyUnquotedTitleWithColon() async throws {
        try await StorageTestLock.shared.run {
            try await withIsolatedStorage { service, directory in
                let id = UUID()
                let createdAt = ISO8601DateFormatter().string(from: Date())
                let legacy = """
                ---
                title: Legacy: Note Title
                id: \(id.uuidString)
                createdAt: \(createdAt)
                updatedAt: \(createdAt)
                ---

                legacy body
                """

                let fileURL = directory.appendingPathComponent("legacy.md")
                try legacy.write(to: fileURL, atomically: true, encoding: .utf8)

                let loaded = try await service.loadAllNotes()
                let note = try #require(loaded.first(where: { $0.id == id }))
                #expect(note.title == "Legacy: Note Title")
                #expect(note.content == "legacy body")
            }
        }
    }

    private func withIsolatedStorage(
        _ operation: (FileStorageService, URL) async throws -> Void
    ) async throws {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("open-sidenotes-tests-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let service = FileStorageService(volatileStorageDirectory: temporaryDirectory)

        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
        }

        _ = try await service.loadAllNotes()
        try await operation(service, temporaryDirectory)
    }

    private func markdownFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "md" }
    }
}
