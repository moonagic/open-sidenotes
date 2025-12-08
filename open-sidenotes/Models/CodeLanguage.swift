import Foundation

enum CodeLanguage: String, CaseIterable, Identifiable {
    case swift = "swift"
    case python = "python"
    case javascript = "javascript"
    case typescript = "typescript"
    case json = "json"
    case html = "html"
    case css = "css"
    case plain = ""

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .json: return "JSON"
        case .html: return "HTML"
        case .css: return "CSS"
        case .plain: return "Plain Text"
        }
    }

    var icon: String {
        switch self {
        case .swift: return "swift"
        case .python: return "terminal.fill"
        case .javascript: return "doc.text.fill"
        case .typescript: return "doc.text.fill"
        case .json: return "curlybraces"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .css: return "paintbrush.fill"
        case .plain: return "doc.plaintext"
        }
    }

    var highlightIdentifier: String {
        switch self {
        case .plain: return ""
        default: return rawValue
        }
    }
}
