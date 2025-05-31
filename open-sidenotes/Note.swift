import Foundation

struct Note: Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String, content: String) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []

    func addNote(title: String, content: String) {
        let note = Note(title: title, content: content)
        notes.append(note)
    }

    func updateNote(_ note: Note, title: String, content: String) {
        if let index = notes.firstIndex(of: note) {
            notes[index].title = title
            notes[index].content = content
            notes[index].updatedAt = Date()
        }
    }

    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
    }

    func getNote(by id: UUID) -> Note? {
        notes.first { $0.id == id }
    }
}