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
- **Settings Panel**: Comprehensive customization options
  - Dock icon visibility control
  - Auto-hide behavior with configurable delay (0-3s)
  - Custom keyboard shortcuts (default: ⌘⌃Space)
  - Storage location selection
- **Session Persistence**: Automatically restores last opened note on launch

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
- Auto-hide on mouse exit with configurable delay (0-3s)
- Supports global keyboard shortcut for window toggle (default: ⌘⌃Space)
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

**Settings System**
- `SettingsView`: Comprehensive settings panel with custom UI components
  - `CustomToggleStyle`: Sage green toggle switches
  - `CustomSlider`: Styled slider for delay adjustment (0-3s range)
  - Settings categories: Appearance, Storage, Window Behavior, Keyboard Shortcuts
- `ShortcutSettings`: ObservableObject managing user preferences
  - `showDockIcon`: Toggle Dock icon visibility (requires restart)
  - `autoHideOnMouseExit`: Auto-hide window when mouse leaves
  - `hideDelay`: Configurable delay before auto-hide (0-3s)
  - `toggleWindowShortcut`: Custom global keyboard shortcut
  - Persisted via UserDefaults
- `ShortcutRecorderView`: Custom keyboard shortcut recorder
  - Interactive key capture with visual feedback
  - Supports all modifier keys (⌘⌃⌥⇧)
  - Clear button to remove shortcuts
  - Real-time preview of recorded shortcut

**Session Management**
- `LastOpenedNoteManager`: Persists and restores last active note
  - Saves note ID on selection change
  - Auto-restores on app launch
  - Uses UserDefaults for storage

### Data Flow

1. **App Launch** → Loads `ShortcutSettings` and `LastOpenedNoteManager` → Restores last note if exists
2. **Edge Trigger** → User moves mouse to right edge → `SideNotesWindowController` detects → Window slides in
3. **Keyboard Toggle** → User presses shortcut (⌘⌃Space) → `ShortcutManager` triggers window toggle
4. **Note Selection** → User selects note → Saves to `LastOpenedNoteManager` → Loads content from `NoteStore`
5. **Markdown Editing** → User types → Render triggers (space/newline/1s delay) → `MarkdownRenderer` applies styling
6. **Auto-save** → 1s after edit → `NoteStore.updateNote` persists to file
7. **Auto-hide** → Mouse exits window → Delay timer (0-3s) → Window slides out (if enabled)
8. **Settings Change** → User modifies preferences → `ShortcutSettings` persists to UserDefaults → Notifies observers

### Key Technical Patterns

- **Custom Markdown Rendering**: Regex-based parser applies styles without deleting source
- **SwiftUI + AppKit Bridge**: Uses `NSViewRepresentable` to wrap NSTextView and custom controls
- **Smart Debouncing**: Context-aware rendering triggers (immediate on space/newline, delayed otherwise)
- **Global Event Monitoring**: Tracks mouse position and keyboard events system-wide
- **File-based Persistence**: Markdown files in configurable storage directory
- **Stateful Window Management**: Tracks `isShown`, `lastAtRightEdge`, and auto-hide timers
- **Settings Persistence**: UserDefaults-based configuration with reactive updates
- **Custom UI Components**: Hand-crafted toggle switches, sliders, and shortcut recorder
- **Session Restoration**: Automatic recovery of last opened note on launch
- **Hot Keys System**: Global keyboard shortcut registration using Carbon framework

## Development Notes

- The app runs as a menu bar utility (Dock icon visibility is configurable)
- Window appears across all spaces and during full-screen apps
- Markdown editing preserves all syntax - fully reversible
- Mouse edge detection threshold is 2px from right screen edge
- Auto-hide delay is configurable from 0-3 seconds (default: 0.5s)
- Default keyboard shortcut: ⌘⌃Space (customizable)
- Settings require app restart for Dock icon changes to take effect
- Last opened note is automatically restored on app launch
- Custom storage directory selection with real-time reload
- **No external dependencies** - pure Swift/AppKit implementation
