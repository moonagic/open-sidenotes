import SwiftUI
import Foundation

private enum WorkspaceMode: String, CaseIterable, Identifiable {
    case notes
    case chat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes:
            return "Notes"
        case .chat:
            return "AI Chat"
        }
    }

    var subtitle: String {
        switch self {
        case .notes:
            return "Write fast, organize later"
        case .chat:
            return "Think with AI, grounded in your notes"
        }
    }

    var icon: String {
        switch self {
        case .notes:
            return "note.text"
        case .chat:
            return "bubble.left.and.bubble.right"
        }
    }

    var shortcut: String {
        switch self {
        case .notes:
            return "⌘1"
        case .chat:
            return "⌘2"
        }
    }
}

struct ContentView: View {
    @StateObject private var noteStore = NoteStore()
    @StateObject private var chatService = AIChatService()
    @AppStorage("workspace_mode") private var workspaceModeRawValue: String = WorkspaceMode.notes.rawValue

    @State private var mode: WorkspaceMode = .notes
    @State private var selectedNote: Note?
    @State private var editingNoteId: UUID?
    @State private var editingTitle: String = ""
    @State private var editingContent: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showDrawer: Bool = false
    @State private var showChatDrawer: Bool = false
    @State private var isLoadingNote: Bool = false

    private var isEditing: Bool {
        editingNoteId != nil
    }

    private var currentNoteContext: ChatNoteContext? {
        let sourceTitle = isEditing ? editingTitle : (selectedNote?.title ?? "")
        let sourceContent = isEditing ? editingContent : (selectedNote?.content ?? "")
        let trimmedContent = sourceContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return nil }

        let normalizedTitle = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = normalizedTitle.isEmpty ? "Untitled" : normalizedTitle
        return ChatNoteContext(title: title, content: trimmedContent)
    }

    private var modeMetaTitle: String {
        switch mode {
        case .notes:
            let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Untitled" : trimmed
        case .chat:
            return chatService.currentSessionTitle
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color(hex: "F4F5F1").ignoresSafeArea()

            VStack(spacing: 8) {
                WorkspaceHeader(
                    mode: $mode,
                    metaTitle: modeMetaTitle,
                    onSelectMode: { selected in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            mode = selected
                            if selected != .notes {
                                showDrawer = false
                            }
                            if selected != .chat {
                                showChatDrawer = false
                            }
                        }
                    },
                    onToggleSidebar: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            if mode == .notes {
                                showDrawer.toggle()
                            } else {
                                showChatDrawer.toggle()
                            }
                        }
                    },
                    onPrimaryAction: {
                        if mode == .notes {
                            createNewNote()
                        } else {
                            chatService.startNewSession()
                        }
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

                    Group {
                        if mode == .notes {
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
                        } else {
                            ChatWorkspaceView(
                                chatService: chatService,
                                noteContext: currentNoteContext,
                                showHeader: false,
                                isSessionDrawerVisible: $showChatDrawer
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(8)

            if showDrawer && mode == .notes {
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
        }
        .onAppear {
            restoreWorkspaceMode()
        }
        .onChange(of: mode) { newMode in
            workspaceModeRawValue = newMode.rawValue
            if newMode != .notes {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showDrawer = false
                }
            }
            if newMode != .chat {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showChatDrawer = false
                }
            }
        }
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
        .task {
            await bootstrapNotes()
        }
        .background(workspaceShortcuts)
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
            mode = .notes
        }
    }

    private func restoreWorkspaceMode() {
        mode = WorkspaceMode(rawValue: workspaceModeRawValue) ?? .notes
    }

    private var workspaceShortcuts: some View {
        Group {
            Button("") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    mode = .notes
                }
            }
            .keyboardShortcut("1", modifiers: .command)
            .hidden()

            Button("") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    mode = .chat
                }
            }
            .keyboardShortcut("2", modifiers: .command)
            .hidden()

            Button("") {
                if mode == .notes {
                    createNewNote()
                } else {
                    chatService.startNewSession()
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()

            Button("") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            .hidden()
        }
    }
}

private struct WorkspaceHeader: View {
    @Binding var mode: WorkspaceMode
    let metaTitle: String
    let onSelectMode: (WorkspaceMode) -> Void
    let onToggleSidebar: () -> Void
    let onPrimaryAction: () -> Void
    let onOpenSettings: () -> Void

    private var sidebarTooltip: String {
        mode == .notes ? "Toggle notes drawer" : "Toggle chats drawer"
    }

    private var primaryActionLabel: String {
        mode == .notes ? "New note" : "New chat"
    }

    private var primaryActionIcon: String {
        mode == .notes ? "square.and.pencil" : "plus.bubble"
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                HeaderIconButton(icon: "sidebar.left", tooltip: sidebarTooltip, action: onToggleSidebar)

                WorkspaceModeSwitcher(mode: $mode, onSelectMode: onSelectMode)

                Spacer(minLength: 0)

                HeaderActionButton(label: primaryActionLabel, icon: primaryActionIcon, action: onPrimaryAction)

                HeaderIconButton(icon: "gearshape", tooltip: "Settings", action: onOpenSettings)
            }

            HStack(spacing: 6) {
                Image(systemName: mode.icon)
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

private struct WorkspaceModeSwitcher: View {
    @Binding var mode: WorkspaceMode
    let onSelectMode: (WorkspaceMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(WorkspaceMode.allCases) { item in
                Button {
                    onSelectMode(item)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(item.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(mode == item ? Color(hex: "3F5F4B") : Color(hex: "6B6F69"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(mode == item ? Color(hex: "DCE8DD") : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .help("\(item.title) (\(item.shortcut))")
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "F2F5F0"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "E4E6DF"), lineWidth: 1)
                )
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
