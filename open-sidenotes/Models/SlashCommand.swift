import Foundation

struct SlashCommand: Identifiable, Equatable {
    let id = UUID()
    let trigger: String
    let title: String
    let description: String
    let template: String
    let icon: String
    let needsLanguageSelector: Bool

    static let allCommands: [SlashCommand] = [
        SlashCommand(
            trigger: "h1",
            title: "Heading 1",
            description: "Large section heading",
            template: "# ",
            icon: "textformat.size.larger",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "h2",
            title: "Heading 2",
            description: "Medium section heading",
            template: "## ",
            icon: "textformat.size",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "h3",
            title: "Heading 3",
            description: "Small section heading",
            template: "### ",
            icon: "textformat.size.smaller",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "todo",
            title: "Task List",
            description: "Create a task item",
            template: "- [ ] ",
            icon: "checkmark.square",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "ul",
            title: "Bullet List",
            description: "Unordered list item",
            template: "- ",
            icon: "list.bullet",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "ol",
            title: "Numbered List",
            description: "Ordered list item",
            template: "1. ",
            icon: "list.number",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "code",
            title: "Code Block",
            description: "Insert code snippet",
            template: "```\n\n```",
            icon: "chevron.left.forwardslash.chevron.right",
            needsLanguageSelector: true
        ),
        SlashCommand(
            trigger: "bold",
            title: "Bold Text",
            description: "Make text bold",
            template: "**text**",
            icon: "bold",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "italic",
            title: "Italic Text",
            description: "Make text italic",
            template: "*text*",
            icon: "italic",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "link",
            title: "Link",
            description: "Insert a hyperlink",
            template: "[text](url)",
            icon: "link",
            needsLanguageSelector: false
        )
    ]

    static func filter(by query: String) -> [SlashCommand] {
        if query.isEmpty || query == "/" {
            return allCommands
        }

        let searchTerm = query.hasPrefix("/") ? String(query.dropFirst()) : query
        return allCommands.filter { command in
            command.trigger.lowercased().hasPrefix(searchTerm.lowercased()) ||
            command.title.lowercased().contains(searchTerm.lowercased())
        }
    }
}
