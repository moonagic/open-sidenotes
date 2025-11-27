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
            await ensureInboxExists()
        }
    }

    func loadLists() async {
        isLoading = true
        errorMessage = nil

        do {
            lists = try await storage.loadAllLists()
        } catch {
            errorMessage = "Failed to load lists: \(error.localizedDescription)"
            print("Error loading lists: \(error)")
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
            print("Error deleting list: \(error)")
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
