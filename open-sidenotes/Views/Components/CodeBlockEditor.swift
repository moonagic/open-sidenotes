import SwiftUI
import AppKit
import Highlighter

struct CodeBlockEditor: NSViewRepresentable {
    @Binding var code: String
    let language: CodeLanguage
    let onCodeChange: (String) -> Void

    func makeNSView(context: Context) -> NSView {
        print("🆕 [CodeBlockEditor] makeNSView called for language: \(language.displayName)")
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0).cgColor
        containerView.layer?.cornerRadius = 8
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0).cgColor

        let copyButton = NSButton()
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
        copyButton.bezelStyle = .regularSquare
        copyButton.isBordered = false
        copyButton.imagePosition = .imageOnly
        copyButton.contentTintColor = NSColor(red: 0.486, green: 0.596, blue: 0.522, alpha: 1.0)
        copyButton.target = context.coordinator
        copyButton.action = #selector(Coordinator.copyCode)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(copyButton)

        let languageLabel = NSTextField(labelWithString: language.displayName.uppercased())
        languageLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        languageLabel.textColor = NSColor(red: 0.486, green: 0.596, blue: 0.522, alpha: 1.0)
        languageLabel.backgroundColor = NSColor(red: 0.486, green: 0.596, blue: 0.522, alpha: 0.15)
        languageLabel.alignment = .center
        languageLabel.isBezeled = false
        languageLabel.isEditable = false
        languageLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(languageLabel)

        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = NSColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.0)
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.delegate = context.coordinator
        textView.string = code

        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        if let textContainer = textView.textContainer {
            textContainer.lineFragmentPadding = 0
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        }

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        containerView.addSubview(scrollView)

        let minHeightConstraint = scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        let maxHeightConstraint = scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 300)
        maxHeightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            copyButton.centerYAnchor.constraint(equalTo: languageLabel.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: languageLabel.leadingAnchor, constant: -8),
            copyButton.widthAnchor.constraint(equalToConstant: 20),
            copyButton.heightAnchor.constraint(equalToConstant: 20),

            languageLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            languageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            languageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            languageLabel.heightAnchor.constraint(equalToConstant: 20),

            scrollView.topAnchor.constraint(equalTo: languageLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            minHeightConstraint,
            maxHeightConstraint
        ])

        context.coordinator.textView = textView
        context.coordinator.copyButton = copyButton
        context.coordinator.scheduleHighlight()

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeBlockEditor
        weak var textView: NSTextView?
        weak var copyButton: NSButton?
        private let highlighter: Highlighter?
        private var highlightWorkItem: DispatchWorkItem?
        private var isHighlighting = false
        private var copyFeedbackWorkItem: DispatchWorkItem?

        init(_ parent: CodeBlockEditor) {
            self.parent = parent
            self.highlighter = Highlighter()
        }

        @objc func copyCode() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(parent.code, forType: .string)
            showCopyFeedback()
        }

        func showCopyFeedback() {
            copyFeedbackWorkItem?.cancel()

            copyButton?.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied")

            let workItem = DispatchWorkItem { [weak self] in
                self?.copyButton?.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
            }

            copyFeedbackWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newCode = textView.string

            parent.onCodeChange(newCode)
            scheduleHighlight()
        }

        func scheduleHighlight() {
            highlightWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, let textView = self.textView else { return }
                self.highlightCode(in: textView)
            }

            highlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
        }

        func highlightCode(in textView: NSTextView) {
            guard !isHighlighting else { return }

            let code = textView.string
            guard !code.isEmpty, let highlighter = highlighter else { return }

            let cursorPosition = textView.selectedRange()

            isHighlighting = true

            if let highlighted = highlighter.highlight(code, as: parent.language.highlightIdentifier) {
                textView.textStorage?.setAttributedString(highlighted)

                let safeLocation = min(cursorPosition.location, textView.string.count)
                let safeLength = min(cursorPosition.length, textView.string.count - safeLocation)
                textView.setSelectedRange(NSRange(location: safeLocation, length: safeLength))
            }

            isHighlighting = false
        }
    }
}
