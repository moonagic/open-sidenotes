import Foundation

class TodoListStorageService {
    static let shared = TodoListStorageService()

    private let fileManager = FileManager.default
    private let listsDirectoryName = ".lists"

    var listsDirectory: URL {
        Constants.defaultTodosDirectory()
            .appendingPathComponent(listsDirectoryName, isDirectory: true)
    }

    var tasksDirectory: URL {
        Constants.defaultTodosDirectory()
    }

    private init() {
        createListsDirectoryIfNeeded()
    }

    func loadAllLists() async throws -> [TodoList] {
        print("\n📂 [TodoListStorage] Starting loadAllLists")
        print("📂 [TodoListStorage] Lists directory: \(listsDirectory.path)")

        let fileURLs = try fileManager.contentsOfDirectory(
            at: listsDirectory,
            includingPropertiesForKeys: nil,
            options: []
        ).filter { $0.pathExtension == "json" }

        print("📂 [TodoListStorage] Found \(fileURLs.count) .json files")
        for url in fileURLs {
            print("  - \(url.lastPathComponent)")
        }

        return try await withThrowingTaskGroup(of: TodoList?.self) { group in
            for fileURL in fileURLs {
                group.addTask {
                    do {
                        let list = try await self.loadList(from: fileURL)
                        print("  ✅ [TodoListStorage] Loaded list: \(list.name) (id: \(list.id))")
                        return list
                    } catch {
                        print("  ❌ [TodoListStorage] Failed to load \(fileURL.lastPathComponent): \(error)")
                        return nil
                    }
                }
            }

            var lists: [TodoList] = []
            for try await list in group {
                if let list = list {
                    lists.append(list)
                }
            }
            print("📂 [TodoListStorage] Successfully loaded \(lists.count) lists\n")
            return lists.sorted { $0.createdAt < $1.createdAt }
        }
    }

    func saveList(_ list: TodoList) async throws {
        let fileURL = fileURL(for: list)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(list)
        try data.write(to: fileURL, options: .atomic)

        createTaskDirectoryIfNeeded(for: list.id)
    }

    func deleteList(_ list: TodoList) async throws {
        let fileURL = fileURL(for: list)
        try fileManager.removeItem(at: fileURL)

        let taskDir = taskDirectory(for: list.id)
        if fileManager.fileExists(atPath: taskDir.path) {
            try fileManager.removeItem(at: taskDir)
        }
    }

    func taskDirectory(for listId: UUID) -> URL {
        tasksDirectory.appendingPathComponent(listId.uuidString, isDirectory: true)
    }

    private func fileURL(for list: TodoList) -> URL {
        let filename = "\(list.id.uuidString).json"
        return listsDirectory.appendingPathComponent(filename)
    }

    private func loadList(from fileURL: URL) async throws -> TodoList {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TodoList.self, from: data)
    }

    private func createListsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: listsDirectory.path) {
            try? fileManager.createDirectory(
                at: listsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private func createTaskDirectoryIfNeeded(for listId: UUID) {
        let taskDir = taskDirectory(for: listId)
        if !fileManager.fileExists(atPath: taskDir.path) {
            try? fileManager.createDirectory(
                at: taskDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
