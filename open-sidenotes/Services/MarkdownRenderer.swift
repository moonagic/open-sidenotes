import AppKit
import Highlighter

class MarkdownRenderer {
    static let shared = MarkdownRenderer()
    private let highlighter: Highlighter?

    init() {
        self.highlighter = Highlighter()
    }

    private let baseFont = NSFont.systemFont(ofSize: 15, weight: .regular)
    private let baseColor = NSColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.0)
    private let markColor = NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 0.5)
    private let codeColor = NSColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0)
    private let linkColor = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
    private let completedTaskColor = NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
    private let quoteColor = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)

    func render(_ markdown: String) -> NSAttributedString {
        guard !markdown.isEmpty else {
            return NSAttributedString(string: "")
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        let attributed = NSMutableAttributedString(
            string: markdown,
            attributes: [
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        applyCodeBlocks(to: attributed)
        applyHeadings(to: attributed)
        applyTaskLists(to: attributed)
        applyQuotes(to: attributed)
        applyBold(to: attributed)
        applyItalic(to: attributed)
        applyLinks(to: attributed)
        applyInlineCode(to: attributed)
        applyLists(to: attributed)

        return attributed
    }

    private func applyHeadings(to attributed: NSMutableAttributedString) {
        let text = attributed.string
        let lines = text.components(separatedBy: "\n")
        var offset = 0

        let pattern = "^(#{1,6})\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        for line in lines {
            let lineRange = NSRange(location: offset, length: line.count)

            if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) {
                let hashRange = NSRange(location: offset + match.range(at: 1).location,
                                        length: match.range(at: 1).length)
                let contentRange = NSRange(location: offset + match.range(at: 2).location,
                                           length: match.range(at: 2).length)

                let hashCount = match.range(at: 1).length
                let fontSize: CGFloat
                let lineSpacing: CGFloat

                switch hashCount {
                case 1: fontSize = 28; lineSpacing = 8
                case 2: fontSize = 24; lineSpacing = 8
                case 3: fontSize = 20; lineSpacing = 7
                case 4: fontSize = 17; lineSpacing = 6
                case 5: fontSize = 15; lineSpacing = 6
                default: fontSize = 13; lineSpacing = 6
                }

                let headingFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)
                let markFont = NSFont.systemFont(ofSize: 12, weight: .regular)

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = lineSpacing

                attributed.addAttribute(.font, value: markFont, range: hashRange)
                attributed.addAttribute(.foregroundColor, value: markColor, range: hashRange)

                attributed.addAttribute(.font, value: headingFont, range: contentRange)
                attributed.addAttribute(.foregroundColor, value: baseColor, range: contentRange)

                // Apply paragraphStyle only to current line (excluding newline)
                attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)
            }

            offset += line.count + 1
        }
    }

    private func applyBold(to attributed: NSMutableAttributedString) {
        let pattern = "(\\*\\*|__)(.+?)(\\*\\*|__)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length))

        for match in matches.reversed() {
            let openRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let closeRange = match.range(at: 3)

            let boldFont = NSFont.systemFont(ofSize: 15, weight: .bold)
            let markFont = NSFont.systemFont(ofSize: 11, weight: .regular)

            attributed.addAttribute(.font, value: markFont, range: openRange)
            attributed.addAttribute(.foregroundColor, value: markColor, range: openRange)

            attributed.addAttribute(.font, value: boldFont, range: contentRange)
            attributed.addAttribute(.foregroundColor, value: baseColor, range: contentRange)

            attributed.addAttribute(.font, value: markFont, range: closeRange)
            attributed.addAttribute(.foregroundColor, value: markColor, range: closeRange)
        }
    }

    private func applyItalic(to attributed: NSMutableAttributedString) {
        let pattern = "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length))

        for match in matches.reversed() {
            let fullRange = match.range
            let text = (attributed.string as NSString).substring(with: fullRange)

            if text.hasPrefix("**") || text.hasSuffix("**") { continue }

            let contentRange = match.range(at: 1)
            let italicFont = NSFont.systemFont(ofSize: 15, weight: .regular).italic()

            let openRange = NSRange(location: fullRange.location, length: 1)
            let closeRange = NSRange(location: fullRange.location + fullRange.length - 1, length: 1)

            attributed.addAttribute(.foregroundColor, value: markColor, range: openRange)
            attributed.addAttribute(.foregroundColor, value: markColor, range: closeRange)
            attributed.addAttribute(.font, value: italicFont, range: contentRange)
        }
    }

    private func applyInlineCode(to attributed: NSMutableAttributedString) {
        let pattern = "`(.+?)`"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length))

        for match in matches.reversed() {
            let contentRange = match.range(at: 1)
            let codeFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

            let openRange = NSRange(location: match.range.location, length: 1)
            let closeRange = NSRange(location: match.range.location + match.range.length - 1, length: 1)

            attributed.addAttribute(.foregroundColor, value: markColor, range: openRange)
            attributed.addAttribute(.foregroundColor, value: markColor, range: closeRange)
            attributed.addAttribute(.font, value: codeFont, range: contentRange)
            attributed.addAttribute(.foregroundColor, value: codeColor, range: contentRange)
        }
    }

    private func applyTaskLists(to attributed: NSMutableAttributedString) {
        let pattern = "^(\\s*)([-*+])\\s+\\[([ xX])\\]\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }

        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length))

        for match in matches.reversed() {
            let markerRange = match.range(at: 2)
            let checkboxRange = match.range(at: 3)
            let contentRange = match.range(at: 4)

            let checkboxChar = (attributed.string as NSString).substring(with: checkboxRange)
            let isChecked = checkboxChar.lowercased() == "x"

            let markFont = NSFont.systemFont(ofSize: 11, weight: .regular)

            attributed.addAttribute(.foregroundColor, value: markColor, range: markerRange)

            let checkboxStart = checkboxRange.location - 1
            let checkboxLength = checkboxRange.length + 2
            let fullCheckboxRange = NSRange(location: checkboxStart, length: checkboxLength)

            attributed.addAttribute(.font, value: markFont, range: fullCheckboxRange)
            attributed.addAttribute(.foregroundColor, value: markColor, range: fullCheckboxRange)

            if isChecked {
                attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                attributed.addAttribute(.foregroundColor, value: completedTaskColor, range: contentRange)
            }
        }
    }

    private func applyLists(to attributed: NSMutableAttributedString) {
        let pattern = "^(\\s*)([-*+]|\\d+\\.)\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }

        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length))

        for match in matches.reversed() {
            let markerRange = match.range(at: 2)

            attributed.addAttribute(.foregroundColor, value: markColor, range: markerRange)
        }
    }

    private func applyLinks(to attributed: NSMutableAttributedString) {
        // Match [text](url) format
        let pattern = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length))

        for match in matches.reversed() {
            let fullRange = match.range
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            let linkText = (attributed.string as NSString).substring(with: textRange)
            let urlString = (attributed.string as NSString).substring(with: urlRange)

            // Create attributed string for the link
            let linkAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: urlString,
                .font: baseFont
            ]

            let linkAttributedString = NSAttributedString(string: linkText, attributes: linkAttributes)
            attributed.replaceCharacters(in: fullRange, with: linkAttributedString)
        }
    }

    private func applyCodeBlocks(to attributed: NSMutableAttributedString) {
        let pattern = "```([a-z0-9]*)\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length))

        for match in matches.reversed() {
            let fullRange = match.range
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)

            let language = (attributed.string as NSString).substring(with: languageRange)
            let code = (attributed.string as NSString).substring(with: codeRange)

            let codeLines = code.components(separatedBy: "\n")

            let codeBlockAttr = NSMutableAttributedString()

            let openingMark = NSAttributedString(
                string: "```\(language)\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: markColor
                ]
            )
            codeBlockAttr.append(openingMark)

            let codeFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            let lineNumberFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            let lineNumberColor = NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)

            var highlightedCode: NSAttributedString?
            if !language.isEmpty, let highlighter = highlighter {
                highlightedCode = highlighter.highlight(code, as: language)
            }

            for (index, line) in codeLines.enumerated() {
                let lineNumber = "\(index + 1)  "
                let lineNumberAttr = NSAttributedString(
                    string: lineNumber,
                    attributes: [
                        .font: lineNumberFont,
                        .foregroundColor: lineNumberColor,
                        .backgroundColor: NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
                    ]
                )
                codeBlockAttr.append(lineNumberAttr)

                if let highlighted = highlightedCode {
                    let lineStart = code.components(separatedBy: "\n").prefix(index).joined(separator: "\n").count + (index > 0 ? 1 : 0)
                    let lineLength = line.count

                    if lineStart + lineLength <= highlighted.length {
                        let lineRange = NSRange(location: lineStart, length: lineLength)
                        let highlightedLine = highlighted.attributedSubstring(from: lineRange)

                        let styledLine = NSMutableAttributedString(attributedString: highlightedLine)
                        styledLine.addAttribute(.backgroundColor, value: NSColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0), range: NSRange(location: 0, length: styledLine.length))
                        codeBlockAttr.append(styledLine)
                    } else {
                        let plainLine = NSAttributedString(
                            string: line,
                            attributes: [
                                .font: codeFont,
                                .foregroundColor: baseColor,
                                .backgroundColor: NSColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
                            ]
                        )
                        codeBlockAttr.append(plainLine)
                    }
                } else {
                    let plainLine = NSAttributedString(
                        string: line,
                        attributes: [
                            .font: codeFont,
                            .foregroundColor: baseColor,
                            .backgroundColor: NSColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
                        ]
                    )
                    codeBlockAttr.append(plainLine)
                }

                if index < codeLines.count - 1 {
                    codeBlockAttr.append(NSAttributedString(string: "\n"))
                }
            }

            let closingMark = NSAttributedString(
                string: "\n```",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: markColor
                ]
            )
            codeBlockAttr.append(closingMark)

            if !language.isEmpty {
                let languageLabel = NSAttributedString(
                    string: " [\(language.uppercased())]",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                        .foregroundColor: NSColor(red: 0.486, green: 0.596, blue: 0.522, alpha: 1.0),
                        .backgroundColor: NSColor(red: 0.486, green: 0.596, blue: 0.522, alpha: 0.15)
                    ]
                )
                codeBlockAttr.append(languageLabel)
            }

            attributed.replaceCharacters(in: fullRange, with: codeBlockAttr)
        }
    }

    private func applyQuotes(to attributed: NSMutableAttributedString) {
        let text = attributed.string
        let lines = text.components(separatedBy: "\n")
        var offset = 0

        let pattern = "^(>+)\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        for line in lines {
            let lineRange = NSRange(location: offset, length: line.count)

            if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) {
                let markerRange = NSRange(location: offset + match.range(at: 1).location,
                                        length: match.range(at: 1).length)
                let contentRange = NSRange(location: offset + match.range(at: 2).location,
                                          length: match.range(at: 2).length)

                let quoteLevel = match.range(at: 1).length
                let leftIndent: CGFloat = CGFloat(quoteLevel) * 20.0

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 6
                paragraphStyle.firstLineHeadIndent = leftIndent
                paragraphStyle.headIndent = leftIndent

                // Style the marker
                let markFont = NSFont.systemFont(ofSize: 12, weight: .regular)
                attributed.addAttribute(.font, value: markFont, range: markerRange)
                attributed.addAttribute(.foregroundColor, value: markColor, range: markerRange)

                // Style the content
                attributed.addAttribute(.foregroundColor, value: quoteColor, range: contentRange)
                attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)
            }

            offset += line.count + 1
        }
    }
}

extension NSFont {
    func italic() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
