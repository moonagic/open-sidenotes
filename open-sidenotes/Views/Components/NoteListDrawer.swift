import SwiftUI

struct NoteListDrawer: View {
    @ObservedObject var noteStore: NoteStore
    @Binding var selectedNote: Note?
    var onClose: () -> Void

    @State private var hoveredNoteId: UUID?
    @State private var searchText: String = ""
    @State private var debouncedSearch: String = ""
    @State private var searchTask: DispatchWorkItem?
    @FocusState private var isSearchFocused: Bool

    private var filteredNotes: [Note] {
        guard !debouncedSearch.isEmpty else { return noteStore.notes }
        let query = debouncedSearch.lowercased()

        return noteStore.notes.filter { note in
            note.title.lowercased().contains(query) ||
            note.content.lowercased().contains(query)
        }
    }

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
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
                .onChange(of: searchText) { newValue in
                    searchTask?.cancel()
                    let task = DispatchWorkItem {
                        debouncedSearch = newValue
                    }
                    searchTask = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: task)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    debouncedSearch = ""
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
                        ForEach(filteredNotes) { note in
                            DrawerNoteListItemCard(
                                note: note,
                                isSelected: selectedNote?.id == note.id,
                                isHovered: hoveredNoteId == note.id,
                                searchQuery: debouncedSearch
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedNote = note
                                onClose()
                            }
                            .onHover { hovering in
                                hoveredNoteId = hovering ? note.id : nil
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

            Text("Switch: ⌘1 / ⌘2")
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

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "7C9885"))
                    .frame(width: 5, height: 5)
                    .opacity(isSelected ? 1 : 0)

                Text(noteTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "9DA39C"))
                    .lineLimit(1)

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
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

    return NoteListDrawer(
        noteStore: noteStore,
        selectedNote: $selectedNote,
        onClose: {}
    )
    .frame(width: 900, height: 600)
}
