import Foundation
import AppKit

struct MarkdownConverter {
    static func toAttributedString(_ markdown: String) -> NSAttributedString {
        if #available(macOS 12.0, *) {
            do {
                let attributedString = try AttributedString(
                    markdown: markdown,
                    options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
                )
                return NSAttributedString(attributedString)
            } catch {
                print("Markdown parsing error: \(error)")
                return NSAttributedString(string: markdown, attributes: defaultAttributes())
            }
        } else {
            return applyBasicMarkdownStyles(to: markdown)
        }
    }

    static func toMarkdown(_ attributedString: NSAttributedString) -> String {
        attributedString.string
    }

    private static func defaultAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor
        ]
    }

    private static func applyBasicMarkdownStyles(to markdown: String) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString(
            string: markdown,
            attributes: defaultAttributes()
        )

        let text = markdown as NSString
        let range = NSRange(location: 0, length: text.length)

        let boldPattern = "\\*\\*(.+?)\\*\\*"
        if let boldRegex = try? NSRegularExpression(pattern: boldPattern) {
            boldRegex.enumerateMatches(in: markdown, range: range) { match, _, _ in
                if let matchRange = match?.range(at: 1) {
                    mutableAttributedString.addAttribute(
                        .font,
                        value: NSFont.boldSystemFont(ofSize: 14),
                        range: matchRange
                    )
                }
            }
        }

        let italicPattern = "\\*(.+?)\\*"
        if let italicRegex = try? NSRegularExpression(pattern: italicPattern) {
            italicRegex.enumerateMatches(in: markdown, range: range) { match, _, _ in
                if let matchRange = match?.range(at: 1) {
                    let descriptor = NSFont.systemFont(ofSize: 14).fontDescriptor.withSymbolicTraits(.italic)
                    let italicFont = NSFont(descriptor: descriptor, size: 14) ?? NSFont.systemFont(ofSize: 14)
                    mutableAttributedString.addAttribute(
                        .font,
                        value: italicFont,
                        range: matchRange
                    )
                }
            }
        }

        return mutableAttributedString
    }
}
