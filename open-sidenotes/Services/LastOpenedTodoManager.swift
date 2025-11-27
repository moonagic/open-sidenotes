import Foundation

class LastOpenedTodoManager {
    static let shared = LastOpenedTodoManager()

    private let lastTodoIDKey = "lastOpenedTodoID"

    private init() {}

    func saveLastOpenedTodo(_ todoID: UUID) {
        UserDefaults.standard.set(todoID.uuidString, forKey: lastTodoIDKey)
    }

    func getLastOpenedTodoID() -> UUID? {
        guard let uuidString = UserDefaults.standard.string(forKey: lastTodoIDKey) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }

    func clearLastOpenedTodo() {
        UserDefaults.standard.removeObject(forKey: lastTodoIDKey)
    }
}
