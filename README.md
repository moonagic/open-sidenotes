<div align="center">

# Open Sidenotes

**A minimal, elegant side panel for quick note-taking on macOS**

[![macOS](https://img.shields.io/badge/macOS-11.0+-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/mlhiter/open-sidenotes?style=flat-square)](https://github.com/mlhiter/open-sidenotes/releases)

</div>

---

## Features

- **Edge Activation** — Move your mouse to the right edge of the screen to reveal the notes panel
- **Live Markdown** — Typora-style editing with real-time rendering while preserving source syntax
- **Auto Save** — Your notes are automatically saved as you type
- **Lightweight** — Native SwiftUI app with minimal resource usage
- **Always Available** — Works across all spaces and during full-screen apps
- **Local Storage** — Notes stored as Markdown files in `~/Documents/OpenSidenotes/`

## Installation

### Download

Download the latest release from [GitHub Releases](https://github.com/mlhiter/open-sidenotes/releases):

| Chip | Download |
|------|----------|
| Apple Silicon (M1/M2/M3) | [open-sidenotes-arm64.dmg](https://github.com/mlhiter/open-sidenotes/releases/latest/download/open-sidenotes-arm64.dmg) |
| Intel | [open-sidenotes-x86_64.dmg](https://github.com/mlhiter/open-sidenotes/releases/latest/download/open-sidenotes-x86_64.dmg) |

### Build from Source

```bash
git clone https://github.com/mlhiter/open-sidenotes.git
cd open-sidenotes
xcodebuild -project open-sidenotes.xcodeproj -scheme open-sidenotes build
```

## Usage

1. Launch the app — it runs in the background without a dock icon
2. Move your mouse to the **right edge** of the screen
3. The notes panel slides in automatically
4. Start writing in Markdown
5. Move to the edge again to hide the panel

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘ F` | Find & Replace |
| `⌘ N` | New Note |

### Markdown Support

```markdown
# Heading 1
## Heading 2

**bold** and *italic*

`inline code`

- List item
- Another item

1. Numbered
2. List
```

## Tech Stack

- **SwiftUI** + **AppKit** for native macOS experience
- **NSTextView** for rich text editing
- File-based storage with YAML front matter
- Zero external dependencies

## Contributing

Contributions are welcome! Feel free to:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

## License

[MIT](LICENSE) © mlhiter

---

<div align="center">

**[Report Bug](https://github.com/mlhiter/open-sidenotes/issues)** · **[Request Feature](https://github.com/mlhiter/open-sidenotes/issues)**

</div>
