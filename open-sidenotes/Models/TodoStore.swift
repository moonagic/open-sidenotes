import Foundation

enum SortOption {
    case createdDate
    case updatedDate
    case priority
}

@MainActor
class TodoStore: ObservableObject {
    @Published private(set) var todos: [Todo] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let fileStorage = TodoStorageService.shared

    init() {
        Task {
            await loadTodos()
        }
    }

    func loadTodos() async {
        isLoading = true
        errorMessage = nil

        do {
            todos = try await fileStorage.loadAllTodos()
        } catch {
            errorMessage = "Failed to load todos: \(error.localizedDescription)"
            print("Error loading todos: \(error)")
        }

        isLoading = false
    }

    func addTodo(listId: UUID, title: String, description: String = "", priority: Todo.Priority = .medium, tags: [String] = []) async -> Todo {
        let todo = Todo(listId: listId, title: title, description: description, priority: priority, tags: tags)
        todos.insert(todo, at: 0)
        await saveTodo(todo)
        return todo
    }

    func todos(for listId: UUID) -> [Todo] {
        todos.filter { $0.listId == listId }
    }

    func updateTodo(_ todo: Todo, title: String, description: String, isCompleted: Bool? = nil, priority: Todo.Priority? = nil, tags: [String]? = nil) async {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].title = title
            todos[index].description = description
            if let isCompleted = isCompleted {
                todos[index].isCompleted = isCompleted
            }
            if let priority = priority {
                todos[index].priority = priority
            }
            if let tags = tags {
                todos[index].tags = tags
            }
            todos[index].updatedAt = Date()
            await saveTodo(todos[index])
        }
    }

    func deleteTodo(_ todo: Todo) async {
        todos.removeAll { $0.id == todo.id }

        do {
            try await fileStorage.deleteTodo(todo)
        } catch {
            errorMessage = "Failed to delete todo: \(error.localizedDescription)"
            print("Error deleting todo: \(error)")
        }
    }

    func getTodo(by id: UUID) -> Todo? {
        todos.first { $0.id == id }
    }

    func toggleCompletion(_ todo: Todo) async {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
            todos[index].updatedAt = Date()
            await saveTodo(todos[index])
        }
    }

    func filterByTag(_ tag: String) -> [Todo] {
        todos.filter { $0.tags.contains(tag) }
    }

    func filterByPriority(_ priority: Todo.Priority) -> [Todo] {
        todos.filter { $0.priority == priority }
    }

    func filterByCompletion(_ completed: Bool) -> [Todo] {
        todos.filter { $0.isCompleted == completed }
    }

    func allTags() -> [String] {
        var tagSet = Set<String>()
        for todo in todos {
            tagSet.formUnion(todo.tags)
        }
        return Array(tagSet).sorted()
    }

    func sortedTodos(by sortOption: SortOption) -> [Todo] {
        switch sortOption {
        case .createdDate:
            return todos.sorted { $0.createdAt > $1.createdAt }
        case .updatedDate:
            return todos.sorted { $0.updatedAt > $1.updatedAt }
        case .priority:
            return todos.sorted { todo1, todo2 in
                let priorityOrder: [Todo.Priority: Int] = [.high: 0, .medium: 1, .low: 2]
                return (priorityOrder[todo1.priority] ?? 1) < (priorityOrder[todo2.priority] ?? 1)
            }
        }
    }

    private func saveTodo(_ todo: Todo) async {
        do {
            try await fileStorage.saveTodo(todo)
        } catch {
            errorMessage = "Failed to save todo: \(error.localizedDescription)"
            print("Error saving todo: \(error)")
        }
    }
}
