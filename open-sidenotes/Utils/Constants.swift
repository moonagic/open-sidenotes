import Foundation

enum Constants {
    static let appName = "OpenSidenotes"

    static let defaultWelcomeContent = """
# Welcome to Open Sidenotes

Your thoughts, beautifully organized.

## Markdown Basics
**Bold text** — Wrap text in double asterisks
*Italic text* — Wrap text in single asterisks
[Links](https://example.com) — Use brackets and parentheses

## Lists & More
- Unordered lists with dashes
- Numbered lists with 1. 2. 3.
- `Code snippets` with backticks

---

Start writing. Your notes auto-save as you type.
"""

    static let defaultNotesDirectoryName = "OpenSidenotes"

    static func defaultNotesDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(defaultNotesDirectoryName, isDirectory: true)
    }
}
