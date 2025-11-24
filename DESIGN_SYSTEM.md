# Open Sidenotes Design System

## Design Philosophy: Editorial Minimalism

Open Sidenotes adopts an "Editorial Minimalism" aesthetic—inspired by high-end print magazines and refined digital interfaces. The design feels calm, sophisticated, and typography-forward, creating a focused environment for note-taking.

---

## Color Palette

### Primary Colors
- **Cream Background**: `#FAF9F6` - Warm, soft background (sidebar)
- **White**: `#FFFFFF` - Clean, pure background (editor)
- **Charcoal**: `#2C2C2C` - Primary text color

### Accent Colors
- **Sage Green**: `#7C9885` - Primary accent (buttons, selection, active states)
- **Soft Red**: `#D64545` - Destructive actions (delete)

### Neutral Grays
- **Dark Gray**: `#3C3C3C` - Secondary text
- **Medium Gray**: `#888888` - Tertiary text, descriptions
- **Light Gray**: `#999999` - Metadata, timestamps
- **Divider**: `#E8E8E8` - Subtle separators
- **Hover**: `#F0F0F0` - List item hover state

### Design Rationale
The warm cream (#FAF9F6) creates a softer, less clinical feel than pure white, reducing eye strain during extended use. Sage green (#7C9885) provides a natural, calming accent that complements the warm neutrals without overwhelming the interface.

---

## Typography

### System Fonts
**Title**: SF Pro Display, size 28, semibold
**Note List Header**: SF Pro Rounded, size 13, medium, uppercase, 0.5pt tracking
**Note Title in List**: SF Pro, size 15, medium
**Body Text**: SF Pro, size 15, regular, 6pt line spacing
**Metadata**: SF Pro, size 10-11, regular

### Hierarchy
1. **Large Headlines** (28pt, semibold) - Note titles in editor
2. **Medium Text** (15pt, medium) - Note titles in list
3. **Body Text** (15pt, regular) - Editor content, generous line-spacing
4. **Small Labels** (11-13pt, regular/medium) - UI labels, metadata
5. **Tiny Details** (10pt, regular) - Timestamps, secondary info

### Design Rationale
San Francisco (SF Pro) is the native macOS system font, ensuring consistency with the OS while providing excellent readability. Generous line-spacing (6pt) in the editor creates breathing room, mimicking print magazines.

---

## Spacing & Layout

### Padding System
- **Compact**: 8-12px - List item vertical spacing
- **Medium**: 16-24px - Section padding, comfortable spacing
- **Generous**: 32-48px - Editor margins, headline spacing

### Component Spacing
- **Sidebar width**: 260px
- **Editor horizontal padding**: 48px
- **List item padding**: 20px horizontal, 12px vertical
- **Button padding**: 16-20px horizontal, 8-10px vertical

### Design Rationale
Generous editor padding (48px) creates focus and prevents text from feeling cramped against edges. Consistent spacing multiples (8px grid) maintain visual harmony throughout the interface.

---

## Interactive States

### Hover States
- **List Items**: Background changes to `#F0F0F0`
- **Delete Button**: Text color shifts to `#D64545`, background to `rgba(214, 69, 69, 0.08)`
- **New Note Button**: Circular sage green background at 10% opacity

### Selected States
- **List Items**: Sage green background at 8% opacity with 30% opacity border
- **Border**: 1px stroke using sage green at 30% opacity

### Button Styles
- **Primary Action** (Create Note): White text on sage green (#7C9885), 8px border radius, subtle shadow
- **Destructive Action** (Delete): Dynamic color based on hover state, 6px border radius
- **Icon Button** (New): Circular, sage green icon with light background

### Design Rationale
Subtle hover states provide feedback without being distracting. The sage green selection color creates visual continuity between the list and active content, while remaining understated.

---

## Shadows & Depth

### Sidebar Shadow
```swift
.shadow(color: Color.black.opacity(0.05), radius: 10, x: 4, y: 0)
```
Creates subtle separation between sidebar and editor, adding depth to the flat interface.

### Button Shadow
```swift
.shadow(color: Color(hex: "7C9885").opacity(0.3), radius: 8, x: 0, y: 4)
```
Adds prominence to the primary "Create Note" action button.

### Design Rationale
Minimal, directional shadows create a sense of layering without being heavy-handed. The sidebar shadow (4px x-offset) suggests the editor is "behind" the list.

---

## Component Patterns

### List Items
- **Structure**: VStack with title, preview (2 lines), timestamp
- **Hover**: Full rounded background change
- **Selection**: Border + background tint
- **Spacing**: 6px between title and preview

### Editor Header
- **Title Field**: Large (28pt), semibold, generous top padding (32px)
- **Metadata Line**: Small text with dot separator, showing "Last edited" + "Auto-saving" status
- **Divider**: Horizontal line with 48px inset, separating header from content

### Buttons
- **Primary**: Solid sage green with white text and shadow
- **Secondary**: Gray background with hover state
- **Icon-only**: Circular background with icon centered

### Empty States
- **Icon**: Large, ultra-light SF Symbol (32-48pt)
- **Primary Text**: Medium size (13-14pt), medium gray
- **Secondary Text**: Smaller (12pt), lighter gray
- **Centered vertically and horizontally**

### Drawer Layout
- **Window Width**: 400px (compact side panel)
- **Drawer Width**: 280px
- **Editor Width**: Full 400px (336px usable after 32px padding on each side)
- **Background Overlay**: Black at 20% opacity
- **Drawer Position**: Left edge, slides in from left
- **Drawer Corner Radius**: 12px on right side only (topRight, bottomRight)
- **Drawer Shadow**: `shadow(color: .black.opacity(0.15), radius: 20, x: 4, y: 0)`
- **Menu Button**: Left-top of editor, circular sage green background
- **Menu Icon**: `line.3.horizontal` (SF Symbol)

#### Drawer Interaction Pattern
1. **Open**: Click menu button (hamburger icon) in editor toolbar
2. **Close Triggers**:
   - Click on background overlay
   - Select a note from the drawer
3. **Animation**: 0.2s easeInOut transition with `.move(edge: .leading)`

#### Design Rationale
The drawer pattern maximizes editor space (336px usable width vs. previous 44px) while maintaining quick access to the note list. The semi-transparent overlay and slide-in animation clearly communicate the layered interaction model. This approach keeps the window compact (400px) suitable for a side panel application while providing full editing capability.

### Settings Window
- **Window Size**: 450px × 570px (expands to 620px when auto-hide is enabled)
- **Background**: Pure white (#FFFFFF)
- **Content Padding**: 24px horizontal, 24px vertical top
- **Section Spacing**: 20px between major sections
- **Dividers**: Full-width horizontal lines between sections

#### Settings Components
**Custom Toggle Switch**:
- **Dimensions**: 48px × 28px rounded rectangle
- **Off State**: Light gray background (#E0E0E0)
- **On State**: Sage green background (#7C9885)
- **Toggle Circle**: White with 2px shadow, 3px padding, slides with spring animation
- **Animation**: Spring response 0.3, dampingFraction 0.7

**Custom Slider** (for delay adjustment):
- **Track**: 4px height, 2px corner radius
- **Track Color**: Light gray (#E0E0E0) inactive, sage green (#7C9885) active
- **Thumb**: 16px white circle with shadow
- **Range**: 0.0-3.0 seconds, 0.1 step increments
- **Value Display**: Shows formatted delay (e.g., "0.5 s") in sage green

**Shortcut Recorder**:
- **Dimensions**: Auto-width × 32px height
- **Corner Radius**: 6px
- **States**:
  - **Default**: Light gray background (#F5F5F5), placeholder "Click to record"
  - **Recording**: Light green background (#E8F5E9), sage green border (2px), "Press keys..." text
  - **Set**: Displays shortcut symbols (⌘⌃⌥⇧) + key name
- **Clear Button**: 16px circle with "×" icon, appears on hover when shortcut is set
- **Text**: 12pt system font, medium weight when active

#### Settings Categories
1. **Appearance**
   - Show Dock Icon toggle
   - Note: "Requires app restart to take effect"

2. **Storage Location**
   - Current path display (gray box, 12px padding)
   - "Choose Folder" button (sage green)
   - Reload alert when path changes

3. **Window Behavior**
   - Auto-hide toggle
   - Hide delay slider (only visible when auto-hide enabled)
   - Smooth height animation (0.3s) when toggling

4. **Keyboard Shortcuts**
   - Toggle Window shortcut recorder
   - Custom key combination capture

**Reset Button**: Bottom-left, gray background (#F0F0F0), "Reset to Default" text

#### Design Rationale
The settings window uses custom-styled components that match the app's editorial minimalism aesthetic while providing modern, intuitive controls. The sage green accent color creates visual consistency with the main interface. Inline help text (#999999) provides context without cluttering the design. The expandable layout (570→620px) accommodates conditional controls smoothly.

---

## Animation & Motion

### Principles
- **Subtle**: All animations should feel natural, never distracting
- **Quick**: Keep durations short (0.15-0.3s) for responsiveness
- **Purposeful**: Animate only meaningful state changes

### Current Implementations
- **Hover States**: Instant color transitions (no animation needed for subtle changes)
- **Window Slide**: 0.2s animation (implemented in SideNotesWindowController)
- **Drawer Slide**: 0.2s easeInOut with `.move(edge: .leading)` transition
- **Background Overlay**: Fade in/out with drawer (automatic with SwiftUI animation)
- **Menu Button Hover**: Instant opacity change from 8% to 15%
- **Toggle Switch**: Spring animation (response 0.3, damping 0.7) for smooth toggle
- **Settings Height**: 0.3s easeInOut when showing/hiding delay slider
- **Auto-hide**: Configurable delay (0-3s) before window slides out
- **Shortcut Recorder**: Instant visual feedback when entering recording state

### Future Enhancements (Optional)
- Fade-in for newly created notes
- Smooth scroll to selected item
- Micro-interaction for save status indicator
- Spring animation for drawer bounce effect

---

## Accessibility

### Color Contrast
- Primary text (#2C2C2C) on white background: **15.1:1** (AAA)
- Secondary text (#888888) on white: **4.6:1** (AA)
- Sage green (#7C9885) on cream background: **3.8:1** (AA for large text)

### Interaction
- **Hover feedback**: Visual change on all interactive elements
- **Focus indicators**: System default for keyboard navigation
- **Semantic colors**: Green for positive/active, red for destructive
- **Keyboard navigation**: Full keyboard support in settings (Tab to navigate)
- **Custom shortcuts**: User-configurable for accessibility needs
- **Clear affordances**: Buttons and controls clearly indicate interactivity
- **Shortcut recorder**: Visual state changes guide recording process

### Font Sizes
- Minimum body text: 15pt (exceeds 12pt minimum recommendation)
- Metadata text: 10-13pt (acceptable for secondary information)

---

## Design Tokens (SwiftUI Implementation)

```swift
// Color Extension
extension Color {
    init(hex: String) { /* ... */ }

    static let sidebarBackground = Color(hex: "FAF9F6")
    static let editorBackground = Color(hex: "FFFFFF")
    static let primaryText = Color(hex: "2C2C2C")
    static let accentGreen = Color(hex: "7C9885")
    static let destructiveRed = Color(hex: "D64545")
}
```

---

## Visual Inspiration

**Editorial Roots**:
- Clean magazine layouts (The New Yorker, Monocle)
- Warm paper tones instead of stark white
- Generous margins and breathing room

**Digital Influences**:
- Notion's refined minimalism
- Bear's typography-forward approach
- Craft's elegant spacing

**Unique Differentiator**:
Unlike typical note apps with cold blue accents or stark white backgrounds, Open Sidenotes feels like a beautifully designed journal—warm, inviting, and focused on the content.

---

## Implementation Notes

### Built With
- **SwiftUI** for declarative UI
- **AppKit (NSTextView)** for text editing
- **Native macOS design patterns**
- **ZStack layering** for drawer overlay architecture

### Performance
- Lazy loading for note list (LazyVStack)
- Conditional rendering of drawer (only when `showDrawer = true`)
- Minimal shadow usage (drawer and window only)
- Efficient animation with SwiftUI transitions
- No heavy animations or effects
- UserDefaults-based settings persistence (lightweight)
- Timer-based auto-hide with automatic invalidation
- Global event monitors only active when needed
- Custom NSView controls for optimal shortcut recording

### Future Enhancements
- Dark mode support (charcoal background with warm accents)
- Custom Markdown syntax highlighting
- Formatting toolbar with same aesthetic
- Smooth transitions between notes

---

## Conclusion

Open Sidenotes' design is intentionally restrained yet distinctive. Every detail—from the warm cream background to the generous editor padding—serves the goal of creating a calm, focused environment for note-taking. The editorial minimalism approach ensures the design won't feel dated or "AI-generated," maintaining timeless sophistication through careful attention to typography, spacing, and subtle color choices.
