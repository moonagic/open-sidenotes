# Markdown Todo List Interactive Toggle Design

**Date:** 2025-12-11
**Status:** Approved
**Author:** Design Session

## Overview

Enhance the Markdown editor to support interactive todo list toggling. Users can click checkboxes or use keyboard shortcuts to toggle task completion status without manual text editing.

## Goals

- Enable click-to-toggle on todo list checkboxes in Markdown editor
- Support keyboard shortcut (Cmd+Enter) for toggling
- Maintain Typora-style simplicity with minimal visual feedback
- Preserve existing text editing capabilities

## Current State

- `MarkdownRenderer` already renders todo list syntax (`- [ ]` and `- [x]`) with visual styling
- Checkboxes are dimmed gray, completed tasks show strikethrough
- No interactive functionality - users must manually edit text to change status

## Design

### User Interactions

#### 1. Mouse Click Toggle
- User hovers over checkbox area (`[ ]` or `[x]`)
- Cursor changes to pointing hand (`NSCursor.pointingHand`)
- Click toggles status: `[ ]` ↔ `[x]`
- Visual style updates automatically via re-render

#### 2. Keyboard Shortcut Toggle
- User places cursor anywhere in todo list line
- Presses `Cmd+Enter`
- Status toggles immediately
- Cursor position preserved

#### 3. Normal Editing Unchanged
- Text selection still works normally
- Manual editing of checkbox syntax remains functional
- Auto-save triggers as usual

### Technical Architecture

#### Component Changes

**MarkdownEditor.Coordinator** (primary changes):
- Add `NSTrackingArea` for mouse movement detection
- Implement `mouseMoved(with:)` to detect checkbox hover
- Override `mouseDown(with:)` to handle click events
- Extend `doCommandBy` to handle `Cmd+Enter` shortcut
- Add helper methods:
  - `findTaskCheckboxRange(at:)` - locate checkbox in current line
  - `toggleTaskStatus(at:)` - perform text replacement
  - `isPositionInCheckbox(_:range:)` - hit detection

**MarkdownRenderer** (no changes):
- Existing rendering logic remains unchanged
- Already handles `[ ]` and `[x]` styling correctly

### Implementation Details

#### Mouse Tracking
```
1. Add NSTrackingArea in makeNSView/updateNSView
2. On mouseMoved:
   - Get character index at mouse position
   - Check if current line matches: ^\s*([-*+])\s+\[([ xX])\]\s+(.+)$
   - If match and position in checkbox range → set pointing hand cursor
   - Otherwise → restore iBeam cursor
```

#### Click Detection
```
1. On mouseDown:
   - Get click position character index
   - Find checkbox range in current line using regex
   - If click within checkbox bounds (±2 chars tolerance):
     - Call toggleTaskStatus()
     - Return (prevent text selection)
   - Otherwise → allow default behavior
```

#### Status Toggle Logic
```
1. Parse current line to find checkbox character
2. Determine replacement:
   - If ' ' → replace with 'x'
   - If 'x' or 'X' → replace with ' '
3. Calculate exact NSRange of checkbox character
4. Replace using textStorage.replaceCharacters(in:with:)
5. Trigger textDidChange (auto-save + re-render)
6. Restore cursor position
```

#### Keyboard Shortcut
```
1. In doCommandBy, detect Cmd+Enter:
   - Check for insertNewline selector with Cmd modifier
2. Get current line at cursor position
3. If line is todo list → toggleTaskStatus()
4. Return true (consume event)
5. Otherwise → return false (default behavior)
```

### Interaction Priority Rules

1. **Text selection in progress** → No toggle (allow selection)
2. **Marked text active** (e.g., Chinese input) → No shortcut trigger
3. **Click outside checkbox** → Normal text editing
4. **Click inside checkbox** → Toggle only

### Edge Cases

| Case | Behavior |
|------|----------|
| Nested todos | Each line toggles independently |
| Mixed formatting in content | Only line-start syntax checked |
| Incomplete syntax (`- []`, `- [`) | No match, treated as normal list |
| Case variants (`[X]` vs `[x]`) | Both recognized, normalized to `[x]` when toggling |
| Rapid clicks | Each click is independent text operation |

## Non-Goals

- Syncing with separate TodoStore (they remain independent features)
- Batch toggle operations (one task at a time)
- Undo/redo customization (system text undo handles it)
- Visual animations (instant state change)

## Success Criteria

- [x] Click on checkbox toggles status
- [x] Hover shows pointing hand cursor
- [x] Cmd+Enter toggles task at cursor
- [x] Cursor position preserved after toggle
- [x] Auto-save triggers after toggle
- [x] Normal editing unaffected
- [x] Works with nested todos
- [x] No visual clutter (minimal feedback)

## Implementation Plan

Will be created in next phase using `superpowers:writing-plans`.
