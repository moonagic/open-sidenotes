import Foundation

@MainActor
class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let fileStorage = FileStorageService.shared

    init() {
        Task {
            await loadNotes()
        }
    }

    func loadNotes() async {
        isLoading = true
        errorMessage = nil

        do {
            notes = try await fileStorage.loadAllNotes()
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func addNote(title: String, content: String) async -> Note {
        let note = Note(title: title, content: content)
        notes.insert(note, at: 0)
        await saveNote(note)
        return note
    }

    func updateNote(_ note: Note, title: String, content: String) async {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].title = title
            notes[index].content = content
            notes[index].updatedAt = Date()
            await saveNote(notes[index])
        }
    }

    func deleteNote(_ note: Note) async {
        notes.removeAll { $0.id == note.id }

        do {
            try await fileStorage.deleteNote(note)
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }

    func getNote(by id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    private func saveNote(_ note: Note) async {
        do {
            try await fileStorage.saveNote(note)
        } catch {
            errorMessage = "Failed to save note: \(error.localizedDescription)"
        }
    }
}
