import SwiftUI

struct ContentView: View {
    @StateObject private var noteStore = NoteStore()
    @State private var selectedNote: Note?
    @State private var title: String = ""
    @State private var content: String = Constants.defaultWelcomeContent
    @State private var isEditing: Bool = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showDrawer: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Base layer: Full-width editor
            NoteEditorView(
                noteStore: noteStore,
                selectedNote: $selectedNote,
                isEditing: $isEditing,
                title: $title,
                content: $content,
                onToggleDrawer: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDrawer.toggle()
                    }
                }
            )

            // Overlay: Drawer (when shown)
            if showDrawer {
                NoteListDrawer(
                    noteStore: noteStore,
                    selectedNote: $selectedNote,
                    onNewNote: {
                        createNewNote()
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDrawer = false
                        }
                    },
                    onOpenSettings: {
                        print("⚙️ onOpenSettings triggered - posting notification")
                        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
                    }
                )
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
        }
        .background(Color(hex: "FAF9F6"))
        .clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .bottomLeft]))
        .onChange(of: selectedNote) { newNote in
            if let note = newNote {
                title = note.title
                content = note.content
                isEditing = true
                LastOpenedNoteManager.shared.saveLastOpenedNote(note.id)
            }
        }
        .task {
            while noteStore.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            if let lastNoteID = LastOpenedNoteManager.shared.getLastOpenedNoteID(),
               let note = noteStore.getNote(by: lastNoteID) {
                selectedNote = note
            }
        }
        .onChange(of: title) { _ in
            scheduleAutoSave()
        }
        .onChange(of: content) { _ in
            scheduleAutoSave()
        }
    }

    private func scheduleAutoSave() {
        saveTask?.cancel()

        guard isEditing, let note = selectedNote else { return }

        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            guard !Task.isCancelled else { return }

            await noteStore.updateNote(note, title: title, content: content)
        }
    }

    private func createNewNote() {
        Task {
            let newNote = await noteStore.addNote(
                title: "Untitled",
                content: Constants.defaultWelcomeContent
            )

            selectedNote = newNote
            title = newNote.title
            content = newNote.content
            isEditing = true
        }
    }
}

#Preview {
    ContentView()
}
