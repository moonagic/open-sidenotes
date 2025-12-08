import Foundation

protocol ContentBlock: Identifiable {
    var id: UUID { get }
    func toMarkdown() -> String
}

struct TextBlock: ContentBlock {
    let id: UUID
    var content: String

    init(id: UUID = UUID(), content: String) {
        self.id = id
        self.content = content
    }

    func toMarkdown() -> String {
        return content
    }
}

struct CodeBlock: ContentBlock {
    let id: UUID
    var language: CodeLanguage
    var code: String

    init(id: UUID = UUID(), language: CodeLanguage, code: String) {
        self.id = id
        self.language = language
        self.code = code
    }

    func toMarkdown() -> String {
        let langId = language.highlightIdentifier
        return "```\(langId)\n\(code)\n```"
    }
}
