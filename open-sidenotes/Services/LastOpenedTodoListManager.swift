import Foundation

class LastOpenedTodoListManager {
    static let shared = LastOpenedTodoListManager()

    private let lastListIDKey = "lastOpenedTodoListID"

    private init() {}

    func saveLastOpenedList(_ listID: UUID) {
        UserDefaults.standard.set(listID.uuidString, forKey: lastListIDKey)
    }

    func getLastOpenedListID() -> UUID? {
        guard let uuidString = UserDefaults.standard.string(forKey: lastListIDKey) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }

    func clearLastOpenedList() {
        UserDefaults.standard.removeObject(forKey: lastListIDKey)
    }
}
