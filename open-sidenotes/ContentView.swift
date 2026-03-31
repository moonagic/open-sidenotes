import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var noteStore = NoteStore()

    @State private var selectedNote: Note?
    @State private var editingNoteId: UUID?
    @State private var editingTitle: String = ""
    @State private var editingContent: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showDrawer: Bool = false
    @State private var isLoadingNote: Bool = false
    @State private var showQuickOpen: Bool = false
    @State private var recentNoteIDs: [UUID] = RecentNotesManager.shared.recentNoteIDs()

    private var isEditing: Bool {
        editingNoteId != nil
    }

    private var noteMetaTitle: String {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color(hex: "F4F5F1").ignoresSafeArea()

            VStack(spacing: 8) {
                NotesHeader(
                    metaTitle: noteMetaTitle,
                    onToggleSidebar: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showDrawer.toggle()
                        }
                    },
                    onPrimaryAction: {
                        createNewNote()
                    },
                    onOpenSettings: {
                        openSettings()
                    }
                )

                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "E3E7DF"), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 1)

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
                        },
                        showMenuButton: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(8)

            if showDrawer {
                NoteListDrawer(
                    noteStore: noteStore,
                    selectedNote: $selectedNote,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDrawer = false
                        }
                    }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
                .zIndex(3)
            }

            if showQuickOpen {
                QuickOpenOverlay(
                    notes: noteStore.notes,
                    recentNoteIDs: recentNoteIDs,
                    onSelect: { note in
                        openNoteFromQuickOpen(note)
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            showQuickOpen = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(6)
            }
        }
        .onAppear {
            refreshRecentNotes()
        }
        .onChange(of: selectedNote) { newNote in
            handleNoteSelection(newNote)
        }
        .onChange(of: noteStore.notes) { _ in
            refreshRecentNotes()
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
        .onReceive(NotificationCenter.default.publisher(for: .flushActiveNoteDraft)) { _ in
            flushPendingSaveNow()
        }
        .task {
            await bootstrapNotes()
        }
        .background(workspaceShortcuts)
        .alert(
            "Storage Error",
            isPresented: Binding(
                get: { noteStore.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        noteStore.clearErrorMessage()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                noteStore.clearErrorMessage()
            }
        } message: {
            Text(noteStore.errorMessage ?? "")
        }
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }

    private func bootstrapNotes() async {
        while noteStore.isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if !OnboardingManager.hasCreatedWelcomeNote() {
            let welcomeNote = await noteStore.addNote(
                title: "Welcome",
                content: Constants.defaultWelcomeContent
            )
            OnboardingManager.markWelcomeNoteCreated()
            selectedNote = welcomeNote
            return
        }

        if let lastNoteID = LastOpenedNoteManager.shared.getLastOpenedNoteID(),
           let note = noteStore.getNote(by: lastNoteID) {
            selectedNote = note
            return
        }

        selectedNote = noteStore.notes.first
    }

    private func handleNoteSelection(_ newNote: Note?) {
        if newNote?.id == editingNoteId {
            return
        }

        saveTask?.cancel()

        if let currentId = editingNoteId,
           let newId = newNote?.id,
           currentId != newId {
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
        RecentNotesManager.shared.record(noteID: note.id)
        refreshRecentNotes()

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

    private func flushPendingSaveNow() {
        saveTask?.cancel()
        guard let noteId = editingNoteId else { return }
        noteStore.updateNoteImmediately(noteID: noteId, title: editingTitle, content: editingContent)
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

    private func toggleQuickOpen() {
        withAnimation(.easeInOut(duration: 0.12)) {
            showQuickOpen.toggle()
        }

        if showQuickOpen {
            showDrawer = false
        }
    }

    private func openNoteFromQuickOpen(_ note: Note) {
        withAnimation(.easeInOut(duration: 0.12)) {
            showQuickOpen = false
            showDrawer = false
        }
        selectedNote = note
    }

    private func openOrCreateTodayNote() {
        let now = Date()
        let title = todayNoteTitle(from: now)

        if let existing = findNote(byTitle: title) {
            openNoteFromQuickOpen(existing)
            return
        }

        saveTask?.cancel()
        if let currentId = editingNoteId {
            saveCurrentNote(id: currentId, title: editingTitle, content: editingContent)
        }

        Task {
            let note = await noteStore.addNote(
                title: title,
                content: todayNoteTemplate(from: now)
            )
            await MainActor.run {
                openNoteFromQuickOpen(note)
            }
        }
    }

    private func refreshRecentNotes() {
        let existingIDs = Set(noteStore.notes.map(\.id))
        recentNoteIDs = RecentNotesManager.shared.recentNoteIDs().filter { existingIDs.contains($0) }
    }

    private func findNote(byTitle title: String) -> Note? {
        let normalizedTarget = normalizeTitle(title)
        return noteStore.notes.first { normalizeTitle($0.title) == normalizedTarget }
    }

    private func normalizeTitle(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func todayNoteTitle(from date: Date) -> String {
        "Daily \(Self.dailyNoteDateFormatter.string(from: date))"
    }

    private func todayNoteTemplate(from date: Date) -> String {
        let formattedDate = Self.dailyNoteDateFormatter.string(from: date)
        return """
        # Daily Note \(formattedDate)

        ## Priorities
        - [ ] 

        ## Notes
        - 

        ## Follow-ups
        - [ ] 
        """
    }

    private static let dailyNoteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var workspaceShortcuts: some View {
        Group {
            Button("") {
                createNewNote()
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()

            Button("") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            .hidden()

            Button("") {
                toggleQuickOpen()
            }
            .keyboardShortcut("j", modifiers: .command)
            .hidden()

            Button("") {
                openOrCreateTodayNote()
            }
            .keyboardShortcut("d", modifiers: .command)
            .hidden()
        }
    }
}

private struct NotesHeader: View {
    let metaTitle: String
    let onToggleSidebar: () -> Void
    let onPrimaryAction: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                HeaderIconButton(icon: "sidebar.left", tooltip: "Toggle notes drawer", action: onToggleSidebar)

                Spacer(minLength: 0)

                HeaderActionButton(label: "New note", icon: "square.and.pencil", action: onPrimaryAction)

                HeaderIconButton(icon: "gearshape", tooltip: "Settings", action: onOpenSettings)
            }

            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "6B716B"))

                Text(metaTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "7B817B"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(hex: "F6F8F4"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(hex: "E5E9E1"), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "FBFCFA"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "E3E7DF"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.025), radius: 6, x: 0, y: 1)
        )
    }
}

private struct HeaderIconButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "5E6A61"))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: "F2F5F0"))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

private struct HeaderActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "4C5A51"))
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: "EAF0E8"))
                )
        }
        .buttonStyle(.plain)
        .help("\(label) (⌘N)")
    }
}

#Preview {
    ContentView()
}
