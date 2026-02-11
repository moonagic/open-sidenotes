import SwiftUI

struct NoteEditorView: View {
    @ObservedObject var noteStore: NoteStore
    @Binding var selectedNote: Note?
    @Binding var isEditing: Bool
    @Binding var title: String
    @Binding var content: String
    var onToggleDrawer: () -> Void
    var showMenuButton: Bool = true

    @State private var isHoveringMenu = false
    @State private var showFindBar = false
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var showReplace = false
    @State private var matches: [Range<String.Index>] = []
    @State private var currentMatchIndex = 0
    @State private var isHoveringFindButton = false

    private var wordCount: Int {
        content
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    private var contentStats: String {
        "\(wordCount) words · \(content.count) chars"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if showMenuButton {
                    Button(action: onToggleDrawer) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "7C9885"))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isHoveringMenu ? Color(hex: "7C9885").opacity(0.15) : Color(hex: "7C9885").opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringMenu = hovering
                    }
                }

                Spacer()

                if isEditing || !content.isEmpty {
                    Text(contentStats)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "9AA097"))
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showFindBar.toggle()
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "66716A"))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHoveringFindButton ? Color(hex: "EEF1EC") : Color(hex: "F6F7F4"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: "E2E6DE"), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringFindButton = hovering
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if showFindBar {
                FindReplaceBar(
                    searchText: $findText,
                    replaceText: $replaceText,
                    showReplace: $showReplace,
                    matchCount: matches.count,
                    currentMatch: matches.isEmpty ? 0 : currentMatchIndex + 1,
                    onNext: { navigateMatch(forward: true) },
                    onPrevious: { navigateMatch(forward: false) },
                    onReplace: { replaceCurrent() },
                    onReplaceAll: { replaceAll() },
                    onClose: { showFindBar = false }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if isEditing || selectedNote == nil {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Untitled", text: $title)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(Color(hex: "2C2C2C"))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    if isEditing, let note = selectedNote {
                        HStack(spacing: 12) {
                            Text("Last edited \(timeAgo(from: note.updatedAt))")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(Color(hex: "999999"))

                            Circle()
                                .fill(Color(hex: "CCCCCC"))
                                .frame(width: 3, height: 3)

                            Text("Auto-saving")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(Color(hex: "7C9885"))
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                    }

                    Divider()
                        .background(Color(hex: "E8E8E8"))
                        .padding(.horizontal, 32)

                    BlockEditor(content: $content)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(selectedNote?.id)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 12) {
                    Spacer()

                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(Color(hex: "CACACA"))

                    Text("Select a note to edit")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "999999"))

                    Text("or create a new one")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "BBBBBB"))

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "FFFFFF"))
        .onChange(of: findText) { _ in
            updateMatches()
        }
        .onChange(of: content) { _ in
            if showFindBar {
                updateMatches()
            }
        }
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showFindBar.toggle()
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()
        )
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func updateMatches() {
        guard !findText.isEmpty else {
            matches = []
            currentMatchIndex = 0
            return
        }

        var found: [Range<String.Index>] = []
        var searchStart = content.startIndex
        let searchQuery = findText.lowercased()
        let lowerContent = content.lowercased()

        while let range = lowerContent.range(of: searchQuery, range: searchStart..<lowerContent.endIndex) {
            let originalRange = content.index(content.startIndex, offsetBy: lowerContent.distance(from: lowerContent.startIndex, to: range.lowerBound))
                ..< content.index(content.startIndex, offsetBy: lowerContent.distance(from: lowerContent.startIndex, to: range.upperBound))
            found.append(originalRange)
            searchStart = range.upperBound
        }

        matches = found
        if currentMatchIndex >= matches.count {
            currentMatchIndex = max(0, matches.count - 1)
        }
    }

    private func navigateMatch(forward: Bool) {
        guard !matches.isEmpty else { return }
        if forward {
            currentMatchIndex = (currentMatchIndex + 1) % matches.count
        } else {
            currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
        }
    }

    private func replaceCurrent() {
        guard !matches.isEmpty, currentMatchIndex < matches.count else { return }
        let range = matches[currentMatchIndex]
        content.replaceSubrange(range, with: replaceText)
        updateMatches()
    }

    private func replaceAll() {
        guard !findText.isEmpty else { return }
        content = content.replacingOccurrences(of: findText, with: replaceText, options: .caseInsensitive)
        updateMatches()
    }

}

#Preview {
    @Previewable @State var selectedNote: Note? = Note(
        title: "Sample Note",
        content: "# Heading\n\nThis is **bold** text and this is *italic* text.\n\n- List item 1\n- List item 2\n\nSome `code` here."
    )
    @Previewable @State var isEditing = true
    @Previewable @State var title = "Sample Note"
    @Previewable @State var content = "# Heading\n\nThis is **bold** text and this is *italic* text.\n\n- List item 1\n- List item 2\n\nSome `code` here."

    let noteStore = NoteStore()

    return NoteEditorView(
        noteStore: noteStore,
        selectedNote: $selectedNote,
        isEditing: $isEditing,
        title: $title,
        content: $content,
        onToggleDrawer: {}
    )
    .frame(width: 800, height: 600)
}
