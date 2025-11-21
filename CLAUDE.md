# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Open Sidenotes is a macOS menu bar application that provides a floating side panel for quick note-taking with **Markdown real-time rendering**. The app uses a mouse-triggered edge activation mechanism to show/hide a notes panel that slides in from the right edge of the screen.

### Key Features

- **Typora-style Markdown Editor**: Real-time rendering that preserves source code
  - Input `# Title` → Renders as large bold heading with visible but dimmed `#`
  - Input `**bold**` → Text becomes bold with `**` markers shown in gray
  - Input `` `code` `` → Monospace font with pink color
  - All Markdown syntax remains editable (not deleted after rendering)
- **Edge-triggered Activation**: Move mouse to right edge to toggle panel
- **Auto-save**: Changes saved automatically after 1 second
- **Drawer UI**: Slide-in note list overlay

## Tech Stack

- **Platform**: macOS (SwiftUI + AppKit)
- **UI Framework**: SwiftUI with AppKit integration
- **Minimum Deployment**: macOS 11.0+
- **Language**: Swift
- **Build System**: Xcode project

## Build & Run Commands

```bash
# Build the project
xcodebuild -project open-sidenotes.xcodeproj -scheme open-sidenotes build

# Run tests
xcodebuild test -project open-sidenotes.xcodeproj -scheme open-sidenotes

# Run UI tests
xcodebuild test -project open-sidenotes.xcodeproj -scheme open-sidenotes -only-testing:open-sidenotesUITests

# Clean build folder
xcodebuild clean -project open-sidenotes.xcodeproj -scheme open-sidenotes
```

Or use Xcode: Open `open-sidenotes.xcodeproj` and press Cmd+R to run.

## Architecture

### Core Components

**Application Entry (`open_sidenotesApp.swift`)**
- Uses `@NSApplicationDelegateAdaptor` to integrate AppDelegate with SwiftUI lifecycle
- Creates a Settings scene with EmptyView (app runs as menu bar utility)
- AppDelegate initializes `SideNotesWindowController` on launch

**Window Management (`SideNotesWindowController.swift`)**
- Creates a borderless, floating window positioned at the right edge of the screen
- Implements edge-triggered activation: moving mouse to right screen edge (within 2px) toggles window visibility
- Uses global mouse event monitoring (`NSEvent.addGlobalMonitorForEvents`)
- Animates window slide-in/out with 0.2s duration using `NSAnimationContext`
- Window properties:
  - Width: 400px
  - Height: Full screen visible frame
  - Level: `.floating` (stays on top)
  - Collection behavior: `.canJoinAllSpaces`, `.fullScreenAuxiliary`

**Data Model (`Note.swift`)**
- `Note`: Stores notes with Markdown plain text
  - Properties: `id` (UUID), `title`, `content` (String), `createdAt`, `updatedAt`
  - Conforms to: Identifiable, Equatable, Hashable
- `NoteStore`: ObservableObject managing note CRUD operations with file persistence
  - Published property: `notes` array
  - Methods: `addNote`, `updateNote`, `deleteNote`, `getNote(by:)`
  - Storage: Markdown files in `~/Documents/OpenSidenotes/`

**Markdown Rendering (`MarkdownRenderer.swift`)**
- Custom Markdown parser that preserves source code while applying styles
- Regex-based pattern matching for syntax elements:
  - Headings: `# Title` (1-6 levels, 28-13pt)
  - Bold: `**text**` or `__text__`
  - Italic: `*text*` or `_text_`
  - Inline code: `` `code` ``
  - Lists: `- item`, `* item`, `1. item`
- Visual styling:
  - Markdown markers (e.g., `**`, `#`) rendered in smaller, semi-transparent gray
  - Content styled with appropriate fonts and colors
  - No deletion of syntax - fully reversible editing

**Main UI (`ContentView.swift`)**
- Drawer-based layout:
  - Base layer: Full-width editor (`NoteEditorView`)
  - Overlay: Slide-in note list drawer (`NoteListDrawer`)
- `MarkdownEditor`: NSViewRepresentable wrapper around NSTextView
  - Rich text mode enabled
  - Smart rendering triggers:
    - Immediate: After space or newline (completes a syntax unit)
    - Delayed: 1 second after other input (debounced)
    - On blur: When losing focus
  - Preserves cursor position during re-rendering

### Data Flow

1. User moves mouse to right edge → `SideNotesWindowController` detects → Window slides in
2. User selects note → Updates `selectedNote` state → Loads Markdown content from `NoteStore`
3. User types Markdown → `MarkdownEditor` updates plain text binding
4. Render trigger fires (space/newline/1s delay) → `MarkdownRenderer` applies styling to source
5. Auto-save triggers (1s after edit) → `NoteStore.updateNote` persists to JSON
6. Mouse moves to edge again → Window slides out

### Key Technical Patterns

- **Custom Markdown Rendering**: Regex-based parser applies styles without deleting source
- **SwiftUI + AppKit Bridge**: Uses `NSViewRepresentable` to wrap NSTextView
- **Smart Debouncing**: Context-aware rendering triggers (immediate on space/newline, delayed otherwise)
- **Global Event Monitoring**: Tracks mouse position system-wide to detect edge triggers
- **File-based Persistence**: Markdown files with YAML front matter in Documents directory
- **Stateful Window Management**: Tracks `isShown` and `lastAtRightEdge` to implement toggle behavior

## Development Notes

- The app runs without a dock icon or standard menu bar (menu bar utility pattern)
- Window appears across all spaces and during full-screen apps
- Markdown editing preserves all syntax - fully reversible
- Mouse edge detection threshold is 2px from right screen edge
- Window background has 98% opacity for semi-transparency
- **No external dependencies** - pure Swift/AppKit implementation (Down library removed)
