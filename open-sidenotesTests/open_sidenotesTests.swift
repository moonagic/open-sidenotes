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
