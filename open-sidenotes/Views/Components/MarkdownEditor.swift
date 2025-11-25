import SwiftUI
import AppKit

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var searchQuery: String = ""
    var currentMatchIndex: Int = 0

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.0)
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.delegate = context.coordinator

        if let textContainer = textView.textContainer {
            textContainer.lineFragmentPadding = 0
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: NSColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller = CustomScroller()

        context.coordinator.renderMarkdown(in: textView, text: text)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        context.coordinator.parent = self

        if textView.delegate == nil {
            textView.delegate = context.coordinator
        }

        let queryChanged = context.coordinator.lastSearchQuery != searchQuery
        let indexChanged = context.coordinator.lastMatchIndex != currentMatchIndex

        if textView.string != text && !context.coordinator.isUpdating {
            context.coordinator.renderMarkdown(in: textView, text: text)
        }

        if queryChanged || indexChanged {
            context.coordinator.lastSearchQuery = searchQuery
            context.coordinator.lastMatchIndex = currentMatchIndex
            context.coordinator.applySearchHighlight(in: textView, query: searchQuery, currentIndex: currentMatchIndex)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        var isUpdating = false
        var renderTask: DispatchWorkItem?
        var lastText: String = ""
        var shouldRenderImmediately = false
        var lastSearchQuery: String = ""
        var lastMatchIndex: Int = 0

        init(_ parent: MarkdownEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            let markedRange = textView.markedRange()
            if markedRange.location != NSNotFound && markedRange.length > 0 {
                return
            }

            let plainText = textView.string
            let cursorPosition = textView.selectedRange().location

            isUpdating = true
            parent.text = plainText
            isUpdating = false

            let shouldRenderNow = shouldTriggerImmediateRender(oldText: lastText, newText: plainText)
            lastText = plainText

            renderTask?.cancel()

            if shouldRenderNow {
                renderMarkdown(in: textView, text: plainText, cursorPosition: cursorPosition)
            } else {
                let task = DispatchWorkItem { [weak self, weak textView] in
                    guard let self = self, let textView = textView else { return }

                    DispatchQueue.main.async {
                        let currentText = textView.string
                        let currentCursor = textView.selectedRange().location
                        self.renderMarkdown(in: textView, text: currentText, cursorPosition: currentCursor)
                    }
                }

                renderTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            renderTask?.cancel()
            renderMarkdown(in: textView, text: textView.string)
        }

        private func shouldTriggerImmediateRender(oldText: String, newText: String) -> Bool {
            guard newText.count > oldText.count else { return false }

            let diff = newText.dropFirst(oldText.count)

            return diff.contains("\n") || diff.contains(" ") || diff.hasSuffix("  ")
        }

        func renderMarkdown(in textView: NSTextView, text: String, cursorPosition: Int? = nil) {
            guard let scrollView = textView.enclosingScrollView else { return }

            let visibleRect = scrollView.documentVisibleRect
            let attributedString = MarkdownRenderer.shared.render(text)

            textView.textStorage?.setAttributedString(attributedString)

            if let position = cursorPosition {
                let safePosition = min(position, textView.string.count)
                textView.setSelectedRange(NSRange(location: safePosition, length: 0))
            }

            scrollView.documentView?.scroll(visibleRect.origin)

            applySearchHighlight(in: textView, query: lastSearchQuery, currentIndex: lastMatchIndex)
        }

        func applySearchHighlight(in textView: NSTextView, query: String, currentIndex: Int) {
            guard let textStorage = textView.textStorage else { return }

            let fullRange = NSRange(location: 0, length: textStorage.length)
            textStorage.removeAttribute(.backgroundColor, range: fullRange)

            guard !query.isEmpty else { return }

            let text = textView.string
            let lowerText = text.lowercased()
            let lowerQuery = query.lowercased()

            var matchIndex = 0
            var searchStart = lowerText.startIndex

            while let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
                let nsRange = NSRange(range, in: text)

                let bgColor: NSColor
                if matchIndex == currentIndex {
                    bgColor = NSColor(red: 0.486, green: 0.596, blue: 0.522, alpha: 0.4)
                } else {
                    bgColor = NSColor(red: 0.486, green: 0.596, blue: 0.522, alpha: 0.15)
                }

                textStorage.addAttribute(.backgroundColor, value: bgColor, range: nsRange)

                if matchIndex == currentIndex {
                    textView.scrollRangeToVisible(nsRange)
                }

                matchIndex += 1
                searchStart = range.upperBound
            }
        }
    }
}

#Preview {
    @Previewable @State var text = """
# Heading 1
## Heading 2
### Heading 3

This is **bold** text and this is *italic* text.

Some `inline code` here.

## Task Lists
- [ ] Uncompleted task
- [x] Completed task
- [ ] Another uncompleted task

- List item 1
- List item 2

1. Numbered item
2. Another item

**Bold with `code` inside**
"""

    return MarkdownEditor(text: $text)
        .frame(width: 600, height: 400)
        .padding()
}
