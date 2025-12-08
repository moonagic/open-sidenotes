import Foundation

class BlockParser {
    static func parse(_ markdown: String) -> [any ContentBlock] {
        print("🔍 [BlockParser] parse called")
        print("🔍 [BlockParser] Input markdown length: \(markdown.count)")
        print("🔍 [BlockParser] Input markdown: '\(markdown)'")

        var blocks: [any ContentBlock] = []

        let pattern = "```([a-z0-9]*)\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("❌ [BlockParser] Failed to create regex")
            return [TextBlock(content: markdown)]
        }

        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: markdown.count))
        print("🔍 [BlockParser] Found \(matches.count) code block matches")

        if matches.isEmpty {
            print("🔍 [BlockParser] No code blocks found, returning single TextBlock")
            return [TextBlock(content: markdown)]
        }

        var lastEnd = 0

        for (index, match) in matches.enumerated() {
            print("🔍 [BlockParser] Processing match \(index)")

            let fullRange = match.range
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)

            print("🔍 [BlockParser] Match range: \(fullRange.location)-\(fullRange.location + fullRange.length)")

            if fullRange.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: fullRange.location - lastEnd)
                let text = (markdown as NSString).substring(with: textRange)
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("✅ [BlockParser] Adding TextBlock before code block")
                    blocks.append(TextBlock(content: text))
                }
            }

            let languageStr = (markdown as NSString).substring(with: languageRange)
            let code = (markdown as NSString).substring(with: codeRange)

            print("🔍 [BlockParser] Language: '\(languageStr)', Code length: \(code.count)")

            let language: CodeLanguage
            if let lang = CodeLanguage.allCases.first(where: { $0.highlightIdentifier == languageStr }) {
                language = lang
                print("✅ [BlockParser] Matched language: \(language.displayName)")
            } else {
                language = .plain
                print("⚠️ [BlockParser] Unknown language, using plain")
            }

            print("✅ [BlockParser] Adding CodeBlock")
            blocks.append(CodeBlock(language: language, code: code))

            lastEnd = fullRange.location + fullRange.length
        }

        if lastEnd < markdown.count {
            let textRange = NSRange(location: lastEnd, length: markdown.count - lastEnd)
            let text = (markdown as NSString).substring(with: textRange)
            print("✅ [BlockParser] Adding TextBlock after code block")
            blocks.append(TextBlock(content: text))
        } else {
            print("✅ [BlockParser] Adding empty TextBlock at the end for user input")
            blocks.append(TextBlock(content: ""))
        }

        if blocks.isEmpty {
            print("⚠️ [BlockParser] No blocks created, adding empty TextBlock")
            blocks.append(TextBlock(content: ""))
        }

        print("✅ [BlockParser] Returning \(blocks.count) blocks")
        return blocks
    }

    static func serialize(_ blocks: [any ContentBlock]) -> String {
        var blocksToSerialize = blocks

        if let lastBlock = blocksToSerialize.last as? TextBlock,
           lastBlock.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocksToSerialize.removeLast()
            print("🔧 [BlockParser] Removed empty TextBlock at end during serialization")
        }

        return blocksToSerialize.map { $0.toMarkdown() }.joined(separator: "\n")
    }
}
