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
