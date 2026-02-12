import Foundation

struct SlashCommand: Identifiable, Equatable {
    let id = UUID()
    let trigger: String
    let title: String
    let description: String
    let template: String
    let icon: String
    let needsLanguageSelector: Bool

    static let cursorMarker = "<|cursor|>"

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
            trigger: "quote",
            title: "Quote",
            description: "Insert a quote block",
            template: "> \(cursorMarker)",
            icon: "text.quote",
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
            trigger: "table",
            title: "Table",
            description: "Insert markdown table",
            template: """
            | Column 1 | Column 2 | Column 3 |
            | --- | --- | --- |
            | \(cursorMarker) |  |  |
            """,
            icon: "tablecells",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "date",
            title: "Date",
            description: "Insert current date",
            template: "",
            icon: "calendar",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "today",
            title: "Today",
            description: "Insert today's section",
            template: "",
            icon: "sun.max",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "meeting",
            title: "Meeting Notes",
            description: "Template: meeting notes",
            template: """
            # Meeting Notes
            - Date: {{date}}
            - Attendees:
            - Agenda:

            ## Notes
            - \(cursorMarker)

            ## Action Items
            - [ ] 
            """,
            icon: "person.3",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "daily",
            title: "Daily Report",
            description: "Template: daily report",
            template: """
            # Daily Report
            - Date: {{date}}

            ## Done
            - \(cursorMarker)

            ## In Progress
            - 

            ## Next
            - 

            ## Blockers
            - 
            """,
            icon: "sunrise",
            needsLanguageSelector: false
        ),
        SlashCommand(
            trigger: "issue",
            title: "Issue Log",
            description: "Template: issue tracking note",
            template: """
            # Issue Log
            - Date: {{date}}
            - Severity:
            - Status: Open

            ## Summary
            \(cursorMarker)

            ## Repro Steps
            1. 
            2. 
            3. 

            ## Expected

            ## Actual

            ## Fix Plan
            - [ ] 
            """,
            icon: "exclamationmark.triangle",
            needsLanguageSelector: false
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
            command.title.lowercased().contains(searchTerm.lowercased()) ||
            command.description.lowercased().contains(searchTerm.lowercased())
        }
    }

    func resolvedTemplate(referenceDate: Date = Date()) -> String {
        switch trigger {
        case "date":
            return Self.dateFormatter.string(from: referenceDate)
        case "today":
            return """
            ## Today \(Self.dateFormatter.string(from: referenceDate))
            - \(Self.cursorMarker)
            """
        case "daily":
            return template.replacingOccurrences(
                of: "{{date}}",
                with: Self.dateFormatter.string(from: referenceDate)
            )
        case "meeting":
            return template.replacingOccurrences(
                of: "{{date}}",
                with: Self.dateFormatter.string(from: referenceDate)
            )
        case "issue":
            return template.replacingOccurrences(
                of: "{{date}}",
                with: Self.dateFormatter.string(from: referenceDate)
            )
        default:
            return template
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
