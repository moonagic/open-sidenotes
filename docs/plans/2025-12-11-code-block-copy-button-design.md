# Code Block Copy Button Design

**Date:** 2025-12-11
**Status:** Design Complete

## Overview

Add a copy button to the code block editor that allows users to copy code content to the clipboard with one click. The button will appear in the top-right corner of each code block, to the left of the existing language label.

## Requirements

### Functional Requirements
- Copy entire code block content to system clipboard on button click
- Provide visual feedback confirming successful copy action
- Work seamlessly with all supported programming languages

### User Experience Requirements
- Button always visible (no hover-only behavior)
- Immediate visual feedback on click
- Non-intrusive design that doesn't interfere with code editing

## Design Details

### UI Layout

**Button Position:**
- Located in top-right corner of code block
- Positioned to the left of the language label (e.g., "SWIFT")
- Vertical alignment: centered with language label
- Horizontal spacing: 8pt gap between button and label

**Button Appearance:**
- Size: 20x20pt
- Background: transparent
- Border: none
- Icon: SF Symbol `doc.on.doc` (copy icon)
- Icon color: `NSColor(red: 0.486, green: 0.596, blue: 0.522, alpha: 1.0)` (matching language label)

### Interaction Design

**Click Behavior:**
1. Copy code content to system clipboard via `NSPasteboard`
2. Change icon to `checkmark` (SF Symbol)
3. After 1.5 seconds, revert icon back to `doc.on.doc`

**Feedback Animation (optional enhancement):**
- Subtle scale animation (0.95 → 1.0) on click for enhanced tactile feedback

### Technical Implementation

**Component:** `CodeBlockEditor.swift`

**Architecture Changes:**
1. Add `NSButton` instance to the container view in `makeNSView`
2. Configure button with SF Symbols icon
3. Set up target-action pattern for click handling
4. Add layout constraints for button positioning

**State Management:**
- Store button reference in `Coordinator` as `weak var copyButton: NSButton?`
- Manage feedback timer with `DispatchWorkItem` to handle icon restoration
- Cancel pending timers if user clicks multiple times rapidly

**Layout Constraints:**
```swift
copyButton.centerYAnchor = languageLabel.centerYAnchor
copyButton.trailingAnchor = languageLabel.leadingAnchor - 8pt
copyButton.widthAnchor = 20pt
copyButton.heightAnchor = 20pt
```

Existing `languageLabel.trailingAnchor` remains at `-12pt` from container edge.

### Code Flow

```
User clicks copy button
  ↓
Target-action invokes copyCode() in Coordinator
  ↓
Clear NSPasteboard and write code string
  ↓
Call showCopyFeedback()
  ↓
Cancel pending feedback timer (if any)
  ↓
Update button icon to checkmark
  ↓
Schedule DispatchWorkItem (1.5s delay)
  ↓
After 1.5s: restore icon to doc.on.doc
```

## Technology Choices

**Icon System:** SF Symbols
- Native to macOS
- Consistent with system design language
- High performance rendering
- No external assets required

**Clipboard API:** NSPasteboard
- Standard macOS clipboard interface
- Supports plain text copy
- Universal compatibility

## Edge Cases

- **Rapid clicking:** Cancel previous feedback timer to prevent icon flicker
- **Empty code block:** Copy operation succeeds with empty string
- **Long code:** Copy entire content regardless of length or scroll position

## Success Criteria

- [ ] Copy button appears on all code blocks
- [ ] Click copies exact code content to clipboard
- [ ] Icon changes to checkmark for 1.5s after click
- [ ] Button styling matches existing UI theme
- [ ] No performance impact on code editing or syntax highlighting
