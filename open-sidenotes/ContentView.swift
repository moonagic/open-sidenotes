import SwiftUI

struct ContentView: View {
    @StateObject private var noteStore = NoteStore()
    @StateObject private var todoStore = TodoStore()
    @StateObject private var listStore = TodoListStore()
    @State private var activeTab: String = "notes"
    @State private var selectedNote: Note?
    @State private var selectedList: TodoList?
    @State private var editingNoteId: UUID?
    @State private var editingTitle: String = ""
    @State private var editingContent: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showDrawer: Bool = false
    @State private var isLoadingNote: Bool = false

    private var isEditing: Bool {
        editingNoteId != nil
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if activeTab == "notes" {
                NoteEditorView(
                    noteStore: noteStore,
                    selectedNote: $selectedNote,
                    isEditing: .constant(isEditing),
                    title: $editingTitle,
                    content: $editingContent,
                    onToggleDrawer: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDrawer.toggle()
                        }
                    }
                )
            } else {
                TodoListDetailView(
                    listStore: listStore,
                    todoStore: todoStore,
                    selectedList: $selectedList,
                    onToggleDrawer: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDrawer.toggle()
                        }
                    }
                )
            }

            if showDrawer {
                NoteListDrawer(
                    noteStore: noteStore,
                    todoStore: todoStore,
                    listStore: listStore,
                    activeTab: $activeTab,
                    selectedNote: $selectedNote,
                    selectedList: $selectedList,
                    onNewNote: {
                        createNewNote()
                    },
                    onNewTodo: {
                        Task {
                            if let list = selectedList {
                                await listStore.createList(name: "New List")
                            }
                        }
                    },
                    onToggleTodoCompletion: { todo in
                        Task {
                            await todoStore.toggleCompletion(todo)
                        }
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDrawer = false
                        }
                    },
                    onOpenSettings: {
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
            handleNoteSelection(newNote)
        }
        .onChange(of: editingTitle) { _ in
            if !isLoadingNote {
                scheduleAutoSave()
            }
        }
        .onChange(of: editingContent) { _ in
            if !isLoadingNote {
                scheduleAutoSave()
            }
        }
        .onChange(of: selectedList) { newList in
            if let list = newList {
                LastOpenedTodoListManager.shared.saveLastOpenedList(list.id)
            }
        }
        .task {
            print("\n🚀 [ContentView] Starting initialization task")

            print("⏳ [ContentView] Waiting for noteStore to load...")
            while noteStore.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            print("✅ [ContentView] noteStore loaded")

            print("⏳ [ContentView] Waiting for todoStore to load...")
            while todoStore.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            print("✅ [ContentView] todoStore loaded, total todos: \(todoStore.todos.count)")

            print("⏳ [ContentView] Waiting for listStore to load...")
            while listStore.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            print("✅ [ContentView] listStore loaded, total lists: \(listStore.lists.count)")

            let inbox = await listStore.ensureInboxExists()
            print("📥 [ContentView] Inbox ID: \(inbox.id)")

            if !OnboardingManager.hasCreatedWelcomeNote() {
                let welcomeNote = await noteStore.addNote(
                    title: "Welcome",
                    content: Constants.defaultWelcomeContent
                )
                OnboardingManager.markWelcomeNoteCreated()
                selectedNote = welcomeNote
            } else if let lastNoteID = LastOpenedNoteManager.shared.getLastOpenedNoteID(),
                      let note = noteStore.getNote(by: lastNoteID) {
                selectedNote = note
            }

            if let lastListID = LastOpenedTodoListManager.shared.getLastOpenedListID() {
                print("📌 [ContentView] Restoring last opened list: \(lastListID)")
                if let list = listStore.getList(by: lastListID) {
                    print("✅ [ContentView] Found last list: \(list.name)")
                    selectedList = list
                } else {
                    print("⚠️ [ContentView] Last list not found, using inbox")
                    selectedList = inbox
                }
            } else {
                print("📥 [ContentView] No last list, using inbox")
                selectedList = inbox
            }

            print("📝 [ContentView] Selected list: \(selectedList?.name ?? "none") (id: \(selectedList?.id.uuidString ?? "none"))")
            print("🏁 [ContentView] Initialization completed\n")
        }
    }

    private func handleNoteSelection(_ newNote: Note?) {
        if newNote?.id == editingNoteId {
            return
        }

        saveTask?.cancel()

        if let currentId = editingNoteId, let newId = newNote?.id, currentId != newId {
            saveCurrentNote(id: currentId, title: editingTitle, content: editingContent)
        }

        if let note = newNote {
            startEditing(note)
        } else {
            stopEditing()
        }
    }

    private func startEditing(_ note: Note) {
        isLoadingNote = true
        editingNoteId = note.id
        editingTitle = note.title
        editingContent = note.content
        LastOpenedNoteManager.shared.saveLastOpenedNote(note.id)

        DispatchQueue.main.async {
            isLoadingNote = false
        }
    }

    private func stopEditing() {
        editingNoteId = nil
        editingTitle = ""
        editingContent = ""
    }

    private func saveCurrentNote(id: UUID, title: String, content: String) {
        Task {
            if let note = noteStore.getNote(by: id) {
                await noteStore.updateNote(note, title: title, content: content)
            }
        }
    }

    private func scheduleAutoSave() {
        guard let noteId = editingNoteId else { return }

        saveTask?.cancel()

        let titleToSave = editingTitle
        let contentToSave = editingContent

        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            guard !Task.isCancelled else { return }

            if let note = noteStore.getNote(by: noteId) {
                await noteStore.updateNote(note, title: titleToSave, content: contentToSave)
            }
        }
    }

    private func createNewNote() {
        saveTask?.cancel()

        if let currentId = editingNoteId {
            saveCurrentNote(id: currentId, title: editingTitle, content: editingContent)
        }

        isLoadingNote = true
        selectedNote = nil

        Task {
            let newNote = await noteStore.addNote(
                title: "Untitled",
                content: ""
            )

            selectedNote = newNote
        }
    }

}

#Preview {
    ContentView()
}
