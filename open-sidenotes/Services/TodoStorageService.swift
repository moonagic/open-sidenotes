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
        Task {
            await migrateOldTodoFiles()
        }
    }

    func loadAllTodos() async throws -> [Todo] {
        print("\n📁 [TodoStorage] Starting loadAllTodos")
        print("📁 [TodoStorage] Storage directory: \(storageDirectory.path)")

        var allTodos: [Todo] = []

        let contents = try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        print("📁 [TodoStorage] Found \(contents.count) items in storage directory")

        for item in contents {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  item.lastPathComponent != ".lists" else {
                print("📁 [TodoStorage] Skipping item: \(item.lastPathComponent)")
                continue
            }

            print("📁 [TodoStorage] Scanning list directory: \(item.lastPathComponent)")

            let fileURLs = try fileManager.contentsOfDirectory(
                at: item,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "md" }

            print("📁 [TodoStorage] Found \(fileURLs.count) .md files in \(item.lastPathComponent)")

            let todos = try await withThrowingTaskGroup(of: Todo?.self) { group in
                for fileURL in fileURLs {
                    group.addTask {
                        do {
                            let todo = try await self.loadTodo(from: fileURL)
                            print("  ✅ [TodoStorage] Loaded todo: \(todo.title) (id: \(todo.id)) from \(fileURL.lastPathComponent)")
                            return todo
                        } catch {
                            print("  ❌ [TodoStorage] Failed to load \(fileURL.lastPathComponent): \(error)")
                            return nil
                        }
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
            print("📁 [TodoStorage] Loaded \(todos.count) todos from \(item.lastPathComponent)")
        }

        print("📁 [TodoStorage] Total todos loaded: \(allTodos.count)")
        for todo in allTodos {
            print("  - \(todo.title) (listId: \(todo.listId), id: \(todo.id))")
        }

        return allTodos.sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveTodo(_ todo: Todo) async throws {
        let fileURL = fileURL(for: todo)
        print("💾 [TodoStorage] Saving todo: \(todo.title) (id: \(todo.id))")
        print("💾 [TodoStorage] File path: \(fileURL.path)")
        let content = formatTodoContent(todo)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        print("✅ [TodoStorage] Saved successfully")
    }

    func deleteTodo(_ todo: Todo) async throws {
        let fileURL = fileURL(for: todo)
        print("🗑️ [TodoStorage] Deleting todo: \(todo.title) (id: \(todo.id))")
        print("🗑️ [TodoStorage] File path: \(fileURL.path)")
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            print("✅ [TodoStorage] Deleted successfully")
        } else {
            print("⚠️ [TodoStorage] File not found, nothing to delete")
        }
    }

    func fileURL(for todo: Todo) -> URL {
        let listDir = TodoListStorageService.shared.taskDirectory(for: todo.listId)
        return listDir.appendingPathComponent("\(todo.id.uuidString).md")
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
        let fileId = UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent) ?? UUID()
        let listId = UUID(uuidString: fileURL.deletingLastPathComponent().lastPathComponent) ?? UUID()

        let components = content.components(separatedBy: "---")

        guard components.count >= 3 else {
            return Todo(
                id: fileId,
                listId: listId,
                title: "Untitled",
                description: content
            )
        }

        let frontMatter = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let description = components[2...].joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)

        var title = "Untitled"
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
            id: fileId,
            listId: listId,
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

    private func migrateOldTodoFiles() async {
        let migrationKey = "hasMigratedTodoFilesToUUID_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            print("✅ [Migration] Todo files already migrated, skipping")
            return
        }

        print("\n🔄 [Migration] Starting todo file migration...")

        do {
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

                for oldFileURL in fileURLs {
                    let content = try String(contentsOf: oldFileURL, encoding: .utf8)
                    let components = content.components(separatedBy: "---")

                    guard components.count >= 3 else { continue }

                    let frontMatter = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let lines = frontMatter.components(separatedBy: .newlines)

                    var todoId: UUID?
                    for line in lines {
                        let parts = line.components(separatedBy: ": ")
                        guard parts.count == 2 else { continue }
                        if parts[0].trimmingCharacters(in: .whitespaces) == "id",
                           let id = UUID(uuidString: parts[1].trimmingCharacters(in: .whitespaces)) {
                            todoId = id
                            break
                        }
                    }

                    if let todoId = todoId {
                        let newFileURL = item.appendingPathComponent("\(todoId.uuidString).md")
                        if oldFileURL != newFileURL {
                            if fileManager.fileExists(atPath: newFileURL.path) {
                                try fileManager.removeItem(at: oldFileURL)
                                print("  ⚠️ [Migration] Removed duplicate: \(oldFileURL.lastPathComponent)")
                            } else {
                                try fileManager.moveItem(at: oldFileURL, to: newFileURL)
                                print("  ✅ [Migration] Migrated: \(oldFileURL.lastPathComponent) → \(newFileURL.lastPathComponent)")
                            }
                        }
                    }
                }
            }

            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ [Migration] Todo file migration completed\n")
        } catch {
            print("❌ [Migration] Migration failed: \(error)\n")
        }
    }
}
