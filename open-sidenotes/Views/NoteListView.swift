import SwiftUI

struct NoteListView: View {
    @ObservedObject var noteStore: NoteStore
    @Binding var selectedNote: Note?
    var onNewNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("Notes")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "6B6B6B"))
                    .tracking(0.5)
                    .textCase(.uppercase)

                Spacer()

                Button(action: onNewNote) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "7C9885"))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "7C9885").opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Create new note")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
                .background(Color(hex: "E8E8E8"))

            if noteStore.isLoading {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if noteStore.notes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(Color(hex: "CACACA"))
                    Text("No notes yet")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "999999"))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                CustomScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(noteStore.notes) { note in
                            NoteListItemView(
                                note: note,
                                isSelected: selectedNote?.id == note.id,
                                onSelect: {
                                    selectedNote = note
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 260)
        .background(Color(hex: "FAF9F6"))
    }
}

struct NoteListItemView: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isSelected ? Color(hex: "2C2C2C") : Color(hex: "3C3C3C"))
                .lineLimit(1)

            if !note.content.isEmpty {
                Text(note.content.prefix(80))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "888888"))
                    .lineLimit(2)
                    .lineSpacing(2)
            }

            Text(timeAgo(from: note.updatedAt))
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(Color(hex: "AAAAAA"))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color(hex: "7C9885").opacity(0.08) : (isHovered ? Color(hex: "F0F0F0") : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color(hex: "7C9885").opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    @Previewable @State var selectedNote: Note? = nil
    let noteStore = NoteStore()

    return NoteListView(
        noteStore: noteStore,
        selectedNote: $selectedNote,
        onNewNote: {}
    )
    .frame(height: 600)
}
