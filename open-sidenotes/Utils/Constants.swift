import Foundation

enum Constants {
    static let appName = "OpenSidenotes"

    static let defaultWelcomeContent = """
# Welcome to Open Sidenotes

Your thoughts, beautifully organized with real-time Markdown rendering.

## Markdown Syntax Guide

### Text Formatting
**Bold text** — Wrap text in `**double asterisks**`
*Italic text* — Wrap text in `*single asterisks*`
***Bold and italic*** — Use `***three asterisks***`
`Inline code` — Wrap text in backticks

### Headings
# H1 Heading
## H2 Heading
### H3 Heading

### Lists
- Unordered list item 1
- Unordered list item 2
  - Nested item

1. Ordered list item 1
2. Ordered list item 2
3. Ordered list item 3

### Links & More
[Link text](https://example.com)
> Blockquotes with >
`Code with backticks`

---

## Recent Updates
- **Edge-triggered activation** — Move mouse to right edge to toggle
- **Auto-save** — Changes saved automatically after 1s
- **Customizable shortcuts** — Default: ⌘⌃Space
- **Session persistence** — Auto-restores last opened note
- **Settings panel** — Customize dock icon, auto-hide, storage location

---

**Tip**: All Markdown syntax remains editable. The `#` in headings and `**` in bold text are preserved but styled differently. Start writing — your notes auto-save as you type!
"""

    static let defaultNotesDirectoryName = "OpenSidenotes"

    static func defaultNotesDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(defaultNotesDirectoryName, isDirectory: true)
    }
}
