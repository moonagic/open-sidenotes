import Foundation

@MainActor
class TodoListStore: ObservableObject {
    @Published private(set) var lists: [TodoList] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let storage = TodoListStorageService.shared
    private let migrationKey = "hasCompletedTodoListMigration"

    init() {
        print("\n🏗️ [TodoListStore] Initializing TodoListStore")
        Task {
            await loadLists()
            await cleanupDuplicateInboxes()
        }
    }

    func loadLists() async {
        print("\n📋 [TodoListStore] Starting loadLists")
        isLoading = true
        errorMessage = nil

        do {
            lists = try await storage.loadAllLists()
            print("✅ [TodoListStore] Loaded \(lists.count) lists")
            for list in lists {
                print("  - List '\(list.name)' (id: \(list.id), isInbox: \(list.isInbox))")
            }
            let inboxCount = lists.filter { $0.isInbox }.count
            print("📥 [TodoListStore] Found \(inboxCount) Inbox lists")
        } catch {
            errorMessage = "Failed to load lists: \(error.localizedDescription)"
            print("❌ [TodoListStore] Error loading lists: \(error)")
        }

        isLoading = false
        print("📋 [TodoListStore] isLoading = false, loadLists completed\n")
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
            print("Error deleting list: \(error)")
        }
    }

    func getList(by id: UUID) -> TodoList? {
        lists.first { $0.id == id }
    }

    @discardableResult
    func ensureInboxExists() async -> TodoList {
        print("\n📥 [TodoListStore] Ensuring Inbox exists")
        if let inbox = lists.first(where: { $0.isInbox }) {
            print("✅ [TodoListStore] Inbox found: \(inbox.name) (id: \(inbox.id))")
            return inbox
        }

        print("➕ [TodoListStore] Creating new Inbox")
        let inbox = TodoList(
            name: "Inbox",
            icon: "tray.fill",
            color: "7C9885",
            isInbox: true
        )

        lists.insert(inbox, at: 0)
        await saveList(inbox)
        print("✅ [TodoListStore] Inbox created: \(inbox.id)")
        return inbox
    }

    private func cleanupDuplicateInboxes() async {
        let inboxes = lists.filter { $0.isInbox }
        guard inboxes.count > 1 else { return }

        let oldestInbox = inboxes.min(by: { $0.createdAt < $1.createdAt })!
        print("Found \(inboxes.count) duplicate Inboxes, keeping oldest: \(oldestInbox.id)")

        for inbox in inboxes where inbox.id != oldestInbox.id {
            print("Migrating tasks from duplicate inbox \(inbox.id) to oldest inbox")
            await migrateTasks(from: inbox.id, to: oldestInbox.id)

            lists.removeAll { $0.id == inbox.id }
            do {
                try await storage.deleteList(inbox)
                print("Deleted duplicate inbox: \(inbox.id)")
            } catch {
                print("Failed to delete duplicate inbox: \(error)")
            }
        }

        if let lastListID = LastOpenedTodoListManager.shared.getLastOpenedListID(),
           inboxes.contains(where: { $0.id == lastListID }),
           lastListID != oldestInbox.id {
            LastOpenedTodoListManager.shared.saveLastOpenedList(oldestInbox.id)
            print("Updated last opened list to oldest inbox")
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
            print("Failed to migrate tasks: \(error)")
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
            print("Error saving list: \(error)")
        }
    }
}
