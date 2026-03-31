import SwiftUI
import AppKit

struct NoteListDrawer: View {
    @ObservedObject var noteStore: NoteStore
    @Binding var selectedNote: Note?
    let recentNoteIDs: [UUID]
    var onClose: () -> Void

    @State private var hoveredNoteId: UUID?
    @State private var searchText: String = ""
    @State private var filteredNotes: [Note] = []
    @State private var selectedIndex: Int = 0
    @State private var keyMonitor: Any?
    @State private var indexedNotes: [QuickOpenSearchService.IndexedNote] = []
    @State private var searchGeneration: Int = 0
    @State private var indexGeneration: Int = 0
    @State private var pendingSearchWorkItem: DispatchWorkItem?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    drawerHeader
                    searchBar
                    drawerBody
                    drawerFooter
                }
                .frame(width: 332)
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "FCFDFC"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "E6EAE3"), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.09), radius: 20, x: 6, y: 0)
                )
                .padding(.leading, 12)
                .padding(.vertical, 12)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            rebuildIndexAndSearch()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
            attachKeyMonitor()
            syncSelectionToCurrentNote()
        }
        .onDisappear {
            pendingSearchWorkItem?.cancel()
            pendingSearchWorkItem = nil
            detachKeyMonitor()
        }
        .onChange(of: searchText) {
            selectedIndex = 0
            scheduleSearch()
        }
        .onChange(of: noteStore.notes) {
            rebuildIndexAndSearch()
        }
        .onChange(of: recentNoteIDs) {
            scheduleSearch()
        }
        .onChange(of: selectedNote) {
            syncSelectionToCurrentNote()
        }
    }

    private var drawerHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes Library")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "242824"))

                Text("\(noteStore.notes.count) note\(noteStore.notes.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "8B8F89"))
            }

            Spacer(minLength: 10)

            DrawerIconButton(icon: "xmark", tooltip: "Close") {
                onClose()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "8D928B"))

            TextField("Search notes", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "2E332F"))
                .focused($isSearchFocused)
                .onSubmit {
                    openSelectedNote()
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "9CA099"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color(hex: "F3F6F1"))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Color(hex: "E3E8DF"), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var drawerBody: some View {
        Group {
            if noteStore.isLoading {
                VStack(spacing: 10) {
                    Spacer()
                    ProgressView()
                    Text("Loading notes...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "9AA097"))
                    Spacer()
                }
            } else if noteStore.notes.isEmpty {
                drawerState(
                    icon: "note.text",
                    title: "No notes yet",
                    subtitle: "Create your first note to get started"
                )
            } else if filteredNotes.isEmpty {
                drawerState(
                    icon: "magnifyingglass",
                    title: "No results",
                    subtitle: "Try a different keyword"
                )
            } else {
                CustomScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                            DrawerNoteListItemCard(
                                note: note,
                                isSelected: selectedNote?.id == note.id,
                                isFocused: index == selectedIndex,
                                isHovered: hoveredNoteId == note.id,
                                searchQuery: searchText
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedNote = note
                                onClose()
                            }
                            .onHover { hovering in
                                hoveredNoteId = hovering ? note.id : nil
                                if hovering {
                                    selectedIndex = index
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        let deletingSelected = selectedNote?.id == note.id
                                        await noteStore.deleteNote(note)
                                        if deletingSelected {
                                            selectedNote = noteStore.notes.first
                                        }
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var drawerFooter: some View {
        HStack {
            Text("New note: ⌘N")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "A0A59F"))

            Spacer()

            Text("Quick open: ⌘J")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "A0A59F"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(
            Rectangle()
                .fill(Color(hex: "E7EBE4"))
                .frame(height: 1),
            alignment: .top
        )
        .background(Color(hex: "FCFDFC"))
        .clipShape(
            RoundedRectangle(cornerRadius: 20)
        )
    }

    private func drawerState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundColor(Color(hex: "9EA39D"))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "727771"))

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "A0A59F"))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private func rebuildIndexAndSearch() {
        indexGeneration += 1
        let generation = indexGeneration
        let notesSnapshot = noteStore.notes
        let querySnapshot = searchText
        let recentSnapshot = recentNoteIDs

        if querySnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filteredNotes = notesSnapshot
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let rebuiltIndex = QuickOpenSearchService.buildIndex(from: notesSnapshot)
            let ranked = QuickOpenSearchService.rankedNotes(
                from: rebuiltIndex,
                query: querySnapshot,
                recentNoteIDs: recentSnapshot,
                limit: max(24, rebuiltIndex.count)
            )

            DispatchQueue.main.async {
                guard generation == indexGeneration else { return }
                indexedNotes = rebuiltIndex
                applySearchResults(ranked)
            }
        }
    }

    private func scheduleSearch() {
        pendingSearchWorkItem?.cancel()

        searchGeneration += 1
        let generation = searchGeneration
        let querySnapshot = searchText
        let recentSnapshot = recentNoteIDs
        let indexedSnapshot = indexedNotes

        let workItem = DispatchWorkItem {
            let ranked = QuickOpenSearchService.rankedNotes(
                from: indexedSnapshot,
                query: querySnapshot,
                recentNoteIDs: recentSnapshot,
                limit: max(24, indexedSnapshot.count)
            )

            DispatchQueue.main.async {
                guard generation == searchGeneration else { return }
                applySearchResults(ranked)
            }
        }

        pendingSearchWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func applySearchResults(_ ranked: [Note]) {
        filteredNotes = ranked

        let hasQuery = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasQuery,
           let currentSelected = selectedNote,
           let currentIndex = ranked.firstIndex(where: { $0.id == currentSelected.id }) {
            selectedIndex = currentIndex
            return
        }

        if selectedIndex >= ranked.count {
            selectedIndex = max(0, ranked.count - 1)
        }
    }

    private func openSelectedNote() {
        guard !filteredNotes.isEmpty else {
            return
        }

        let safeIndex = min(max(0, selectedIndex), filteredNotes.count - 1)
        selectedNote = filteredNotes[safeIndex]
        onClose()
    }

    private func moveSelection(by offset: Int) {
        guard !filteredNotes.isEmpty else {
            return
        }

        selectedIndex = min(max(0, selectedIndex + offset), filteredNotes.count - 1)
    }

    private func syncSelectionToCurrentNote() {
        guard let selectedNote,
              let index = filteredNotes.firstIndex(where: { $0.id == selectedNote.id }) else {
            return
        }

        selectedIndex = index
    }

    private func attachKeyMonitor() {
        detachKeyMonitor()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if !modifiers.isEmpty {
                return event
            }

            switch event.keyCode {
            case 125: // Down
                moveSelection(by: 1)
                return nil
            case 126: // Up
                moveSelection(by: -1)
                return nil
            case 36, 76: // Return / Enter
                openSelectedNote()
                return nil
            case 53: // Escape
                onClose()
                return nil
            default:
                return event
            }
        }
    }

    private func detachKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

private struct DrawerIconButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "606660"))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(hex: "F1F5EF"))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

private struct DrawerNoteListItemCard: View {
    let note: Note
    let isSelected: Bool
    let isFocused: Bool
    let isHovered: Bool
    let searchQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(highlightedTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(relativeTime(from: note.updatedAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "A0A59F"))
            }

            Text(highlightedPreview)
                .font(.system(size: 12, weight: .regular))
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(hex: "7C9885").opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cardBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color(hex: "7C9885").opacity(0.13))
        }
        if isFocused {
            return AnyShapeStyle(Color(hex: "EEF3EC"))
        }
        if isHovered {
            return AnyShapeStyle(Color(hex: "F1F4EE"))
        }
        return AnyShapeStyle(Color(hex: "FAFBF8"))
    }

    private var noteTitle: String {
        let normalized = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "Untitled" : normalized
    }

    private var notePreview: String {
        let preview = note.content.replacingOccurrences(of: "\n", with: " ")
        let normalized = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "No content" : String(normalized.prefix(120))
    }

    private var highlightedTitle: AttributedString {
        highlight(text: noteTitle, query: searchQuery, baseColor: Color(hex: "2D322F"))
    }

    private var highlightedPreview: AttributedString {
        highlight(text: notePreview, query: searchQuery, baseColor: Color(hex: "798078"))
    }

    private func highlight(text: String, query: String, baseColor: Color) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = baseColor

        guard !query.isEmpty else { return attributed }

        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        var searchStart = lowerText.startIndex

        while let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
            if let lower = AttributedString.Index(range.lowerBound, within: attributed),
               let upper = AttributedString.Index(range.upperBound, within: attributed) {
                attributed[lower..<upper].foregroundColor = Color(hex: "5E7D68")
                attributed[lower..<upper].backgroundColor = Color(hex: "BFD3C4").opacity(0.35)
            }
            searchStart = range.upperBound
        }

        return attributed
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "now"
        }
        if seconds < 3600 {
            return "\(seconds / 60)m"
        }
        if seconds < 86400 {
            return "\(seconds / 3600)h"
        }
        if seconds < 604800 {
            return "\(seconds / 86400)d"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    @Previewable @State var selectedNote: Note? = nil
    let noteStore = NoteStore()

    NoteListDrawer(
        noteStore: noteStore,
        selectedNote: $selectedNote,
        recentNoteIDs: [],
        onClose: {}
    )
    .frame(width: 900, height: 600)
}
