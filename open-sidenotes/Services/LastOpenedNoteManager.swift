import Foundation

class LastOpenedNoteManager {
    static let shared = LastOpenedNoteManager()

    private let lastNoteIDKey = "lastOpenedNoteID"

    private init() {}

    func saveLastOpenedNote(_ noteID: UUID) {
        UserDefaults.standard.set(noteID.uuidString, forKey: lastNoteIDKey)
    }

    func getLastOpenedNoteID() -> UUID? {
        guard let uuidString = UserDefaults.standard.string(forKey: lastNoteIDKey) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }

    func clearLastOpenedNote() {
        UserDefaults.standard.removeObject(forKey: lastNoteIDKey)
    }
}
