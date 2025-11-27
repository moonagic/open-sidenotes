import Foundation

class TodoStorageService {
    static let shared = TodoStorageService()

    private let fileManager = FileManager.default
    private let storageDirectoryKey = "customTodoStorageDirectory"

    var storageDirectory: URL {
        get {
            if let customPath = UserDefaults.standard.string(forKey: storageDirectoryKey) {
                return URL(fileURLWithPath: customPath)
            }
            return Constants.defaultTodosDirectory()
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: storageDirectoryKey)
            createStorageDirectoryIfNeeded()
        }
    }

    private init() {
        createStorageDirectoryIfNeeded()
    }

    func loadAllTodos() async throws -> [Todo] {
        var allTodos: [Todo] = []

        let contents = try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  item.lastPathComponent != ".lists" else { continue }

            let fileURLs = try fileManager.contentsOfDirectory(
                at: item,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "md" }

            let todos = try await withThrowingTaskGroup(of: Todo?.self) { group in
                for fileURL in fileURLs {
                    group.addTask {
                        try? await self.loadTodo(from: fileURL)
                    }
                }

                var result: [Todo] = []
                for try await todo in group {
                    if let todo = todo {
                        result.append(todo)
                    }
                }
                return result
            }

            allTodos.append(contentsOf: todos)
        }

        return allTodos.sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveTodo(_ todo: Todo) async throws {
        try? await removeOldFile(for: todo)

        let fileURL = fileURL(for: todo)
        let content = formatTodoContent(todo)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func deleteTodo(_ todo: Todo) async throws {
        if let existingURL = findFile(byId: todo.id) {
            try fileManager.removeItem(at: existingURL)
        }
    }

    func fileURL(for todo: Todo) -> URL {
        let listDir = TodoListStorageService.shared.taskDirectory(for: todo.listId)
        let safeName = sanitizeFileName(todo.title)
        let baseName = safeName.isEmpty ? "Untitled" : safeName
        return uniqueFileURL(baseName: baseName, todoId: todo.id, in: listDir)
    }

    private func sanitizeFileName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.components(separatedBy: illegal).joined()
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func uniqueFileURL(baseName: String, todoId: UUID, in directory: URL) -> URL {
        let baseURL = directory.appendingPathComponent("\(baseName).md")

        if !fileManager.fileExists(atPath: baseURL.path) {
            return baseURL
        }

        if let existingTodo = try? loadTodoSync(from: baseURL), existingTodo.id == todoId {
            return baseURL
        }

        var counter = 1
        while true {
            let url = directory.appendingPathComponent("\(baseName) \(counter).md")
            if !fileManager.fileExists(atPath: url.path) {
                return url
            }
            if let existingTodo = try? loadTodoSync(from: url), existingTodo.id == todoId {
                return url
            }
            counter += 1
        }
    }

    private func findFile(byId id: UUID) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter({ $0.pathExtension == "md" }) else { return nil }

        for file in files {
            if let todo = try? loadTodoSync(from: file), todo.id == id {
                return file
            }
        }
        return nil
    }

    private func removeOldFile(for todo: Todo) async throws {
        guard let oldURL = findFile(byId: todo.id) else { return }
        let newURL = fileURL(for: todo)

        if oldURL != newURL {
            try fileManager.removeItem(at: oldURL)
        }
    }

    private func loadTodoSync(from fileURL: URL) throws -> Todo {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return parseTodoContent(content, fileURL: fileURL)
    }

    private func loadTodo(from fileURL: URL) async throws -> Todo {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return parseTodoContent(content, fileURL: fileURL)
    }

    private func formatTodoContent(_ todo: Todo) -> String {
        let formatter = ISO8601DateFormatter()
        let tagsString = todo.tags.joined(separator: ",")

        return """
        ---
        title: \(todo.title)
        id: \(todo.id.uuidString)
        listId: \(todo.listId.uuidString)
        isCompleted: \(todo.isCompleted)
        priority: \(todo.priority.rawValue)
        tags: \(tagsString)
        createdAt: \(formatter.string(from: todo.createdAt))
        updatedAt: \(formatter.string(from: todo.updatedAt))
        ---

        \(todo.description)
        """
    }

    private func parseTodoContent(_ content: String, fileURL: URL) -> Todo {
        let components = content.components(separatedBy: "---")

        let listId = UUID(uuidString: fileURL.deletingLastPathComponent().lastPathComponent) ?? UUID()

        guard components.count >= 3 else {
            return Todo(
                id: UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent) ?? UUID(),
                listId: listId,
                title: "Untitled",
                description: content
            )
        }

        let frontMatter = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let description = components[2...].joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)

        var title = "Untitled"
        var id = UUID()
        var parsedListId: UUID?
        var isCompleted = false
        var priority: Todo.Priority = .medium
        var tags: [String] = []
        var createdAt = Date()
        var updatedAt = Date()

        let lines = frontMatter.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ": ")
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            switch key {
            case "title":
                title = value
            case "id":
                id = UUID(uuidString: value) ?? UUID()
            case "listId":
                parsedListId = UUID(uuidString: value)
            case "isCompleted":
                isCompleted = value.lowercased() == "true"
            case "priority":
                priority = Todo.Priority(rawValue: value) ?? .medium
            case "tags":
                tags = value.isEmpty ? [] : value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "createdAt":
                createdAt = ISO8601DateFormatter().date(from: value) ?? Date()
            case "updatedAt":
                updatedAt = ISO8601DateFormatter().date(from: value) ?? Date()
            default:
                break
            }
        }

        return Todo(
            id: id,
            listId: parsedListId ?? listId,
            title: title,
            description: description,
            isCompleted: isCompleted,
            priority: priority,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func createStorageDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
