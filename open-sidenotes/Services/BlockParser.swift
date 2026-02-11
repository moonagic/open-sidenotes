import Foundation

class BlockParser {
    static func parse(_ markdown: String) -> [any ContentBlock] {

        var blocks: [any ContentBlock] = []

        let pattern = "```([a-z0-9]*)\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [TextBlock(content: markdown)]
        }

        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: markdown.count))

        if matches.isEmpty {
            return [TextBlock(content: markdown)]
        }

        var lastEnd = 0

        for match in matches {

            let fullRange = match.range
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)


            if fullRange.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: fullRange.location - lastEnd)
                let text = (markdown as NSString).substring(with: textRange)
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(TextBlock(content: text))
                }
            }

            let languageStr = (markdown as NSString).substring(with: languageRange)
            let code = (markdown as NSString).substring(with: codeRange)


            let language: CodeLanguage
            if let lang = CodeLanguage.allCases.first(where: { $0.highlightIdentifier == languageStr }) {
                language = lang
            } else {
                language = .plain
            }

            blocks.append(CodeBlock(language: language, code: code))

            lastEnd = fullRange.location + fullRange.length
        }

        if lastEnd < markdown.count {
            let textRange = NSRange(location: lastEnd, length: markdown.count - lastEnd)
            let text = (markdown as NSString).substring(with: textRange)
            blocks.append(TextBlock(content: text))
        } else {
            blocks.append(TextBlock(content: ""))
        }

        if blocks.isEmpty {
            blocks.append(TextBlock(content: ""))
        }

        return blocks
    }

    static func serialize(_ blocks: [any ContentBlock]) -> String {
        var blocksToSerialize = blocks

        if let lastBlock = blocksToSerialize.last as? TextBlock,
           lastBlock.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocksToSerialize.removeLast()
        }

        return blocksToSerialize.map { $0.toMarkdown() }.joined(separator: "\n")
    }
}
