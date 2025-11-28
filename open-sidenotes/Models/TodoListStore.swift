import Foundation

@MainActor
class TodoListStore: ObservableObject {
    @Published private(set) var lists: [TodoList] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let storage = TodoListStorageService.shared
    private let migrationKey = "hasCompletedTodoListMigration"

    init() {
        Task {
            await loadLists()
            await cleanupDuplicateInboxes()
        }
    }

    func loadLists() async {
        isLoading = true
        errorMessage = nil

        do {
            lists = try await storage.loadAllLists()
        } catch {
            errorMessage = "Failed to load lists: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func createList(name: String) async -> TodoList {
        let list = TodoList(name: name)
        lists.append(list)
        await saveList(list)
        return list
    }

    func updateList(_ list: TodoList, name: String) async {
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            lists[index].name = name
            lists[index].updatedAt = Date()
            await saveList(lists[index])
        }
    }

    func deleteList(_ list: TodoList) async {
        guard !list.isInbox else { return }
        lists.removeAll { $0.id == list.id }

        do {
            try await storage.deleteList(list)
        } catch {
            errorMessage = "Failed to delete list: \(error.localizedDescription)"
        }
    }

    func getList(by id: UUID) -> TodoList? {
        lists.first { $0.id == id }
    }

    @discardableResult
    func ensureInboxExists() async -> TodoList {
        if let inbox = lists.first(where: { $0.isInbox }) {
            return inbox
        }

        let inbox = TodoList(
            name: "Inbox",
            icon: "tray.fill",
            color: "7C9885",
            isInbox: true
        )

        lists.insert(inbox, at: 0)
        await saveList(inbox)
        return inbox
    }

    private func cleanupDuplicateInboxes() async {
        let inboxes = lists.filter { $0.isInbox }
        guard inboxes.count > 1 else { return }

        let oldestInbox = inboxes.min(by: { $0.createdAt < $1.createdAt })!

        for inbox in inboxes where inbox.id != oldestInbox.id {
            await migrateTasks(from: inbox.id, to: oldestInbox.id)

            lists.removeAll { $0.id == inbox.id }
            do {
                try await storage.deleteList(inbox)
            } catch {
            }
        }

        if let lastListID = LastOpenedTodoListManager.shared.getLastOpenedListID(),
           inboxes.contains(where: { $0.id == lastListID }),
           lastListID != oldestInbox.id {
            LastOpenedTodoListManager.shared.saveLastOpenedList(oldestInbox.id)
        }
    }

    private func migrateTasks(from sourceListId: UUID, to targetListId: UUID) async {
        let sourceDir = storage.taskDirectory(for: sourceListId)
        let targetDir = storage.taskDirectory(for: targetListId)

        guard FileManager.default.fileExists(atPath: sourceDir.path) else { return }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: sourceDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "md" }

            for file in files {
                let targetFile = targetDir.appendingPathComponent(file.lastPathComponent)
                if FileManager.default.fileExists(atPath: targetFile.path) {
                    let uniqueName = "\(UUID().uuidString).md"
                    let uniqueTarget = targetDir.appendingPathComponent(uniqueName)
                    try FileManager.default.moveItem(at: file, to: uniqueTarget)
                } else {
                    try FileManager.default.moveItem(at: file, to: targetFile)
                }
            }

            try FileManager.default.removeItem(at: sourceDir)
        } catch {
        }
    }

    func hasCompletedMigration() -> Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }

    func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    private func saveList(_ list: TodoList) async {
        do {
            try await storage.saveList(list)
        } catch {
            errorMessage = "Failed to save list: \(error.localizedDescription)"
        }
    }
}
