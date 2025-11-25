import SwiftUI

struct NoteListDrawer: View {
    @ObservedObject var noteStore: NoteStore
    @Binding var selectedNote: Note?
    var onNewNote: () -> Void
    var onClose: () -> Void
    var onOpenSettings: () -> Void

    @State private var hoveredNoteId: UUID?
    @State private var searchText: String = ""
    @State private var debouncedSearch: String = ""
    @State private var searchTask: DispatchWorkItem?
    @FocusState private var isSearchFocused: Bool

    private var filteredNotes: [Note] {
        guard !debouncedSearch.isEmpty else { return noteStore.notes }
        let query = debouncedSearch.lowercased()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return noteStore.notes.filter { note in
            note.title.lowercased().contains(query) ||
            note.content.lowercased().contains(query) ||
            dateFormatter.string(from: note.updatedAt).contains(query) ||
            dateFormatter.string(from: note.createdAt).contains(query)
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background overlay - tap to close
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            // Drawer content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    Text("NOTES")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(Color(hex: "888888"))

                    Spacer()

                    Button(action: {
                        onNewNote()
                        onClose()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "7C9885"))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(hex: "7C9885").opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .background(Color(hex: "E8E8E8"))

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "888888"))

                    TextField("Search notes...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "2C2C2C"))
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { newValue in
                            searchTask?.cancel()
                            let task = DispatchWorkItem {
                                debouncedSearch = newValue
                            }
                            searchTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                        }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            debouncedSearch = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "888888"))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "F5F5F5"))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Notes list
                if noteStore.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if noteStore.notes.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(Color(hex: "888888"))

                        Text("No notes yet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "888888"))

                        Text("Create your first note")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else if filteredNotes.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(Color(hex: "888888"))

                        Text("No results")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "888888"))

                        Text("Try a different search term")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredNotes) { note in
                                DrawerNoteListItemView(
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
                                    if hovering {
                                        NSCursor.arrow.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                .contextMenu {
                                    Button(action: {
                                        Task {
                                            if selectedNote?.id == note.id {
                                                selectedNote = nil
                                            }
                                            await noteStore.deleteNote(note)
                                        }
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Divider()
                    .background(Color(hex: "E8E8E8"))

                Button(action: {
                    onOpenSettings()
                    onClose()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "888888"))

                        Text("Settings")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "666666"))

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 280)
            .background(Color(hex: "FAF9F6"))
            .cornerRadius(12, corners: [.topRight, .bottomRight])
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 4, y: 0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
        }
    }
}

// Note list item for drawer
private struct DrawerNoteListItemView: View {
    let note: Note
    let isSelected: Bool
    let isHovered: Bool
    var searchQuery: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(highlightedTitle)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)

            Text(highlightedPreview)
                .font(.system(size: 13))
                .lineLimit(2)

            Text(relativeTime(from: note.updatedAt))
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "999999"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .stroke(Color(hex: "7C9885").opacity(0.3), lineWidth: 1)
                .opacity(isSelected ? 1 : 0)
        )
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(hex: "7C9885").opacity(0.08)
        } else if isHovered {
            return Color(hex: "F0F0F0")
        } else {
            return Color.clear
        }
    }

    private var notePreview: String {
        let preview = note.content.replacingOccurrences(of: "\n", with: " ")
        return String(preview.prefix(80))
    }

    private var highlightedTitle: AttributedString {
        let title = note.title.isEmpty ? "Untitled" : note.title
        return highlight(text: title, query: searchQuery, baseColor: Color(hex: "2C2C2C"))
    }

    private var highlightedPreview: AttributedString {
        return highlight(text: notePreview, query: searchQuery, baseColor: Color(hex: "888888"))
    }

    private func highlight(text: String, query: String, baseColor: Color) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = baseColor

        guard !query.isEmpty else { return attributed }

        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        var searchStart = lowerText.startIndex

        while let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
            let attrRange = AttributedString.Index(range.lowerBound, within: attributed)!
                ..< AttributedString.Index(range.upperBound, within: attributed)!
            attributed[attrRange].foregroundColor = Color(hex: "7C9885")
            attributed[attrRange].backgroundColor = Color(hex: "7C9885").opacity(0.15)
            searchStart = range.upperBound
        }

        return attributed
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) min ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours) hour\(hours > 1 ? "s" : "") ago"
        } else if seconds < 604800 {
            let days = seconds / 86400
            return "\(days) day\(days > 1 ? "s" : "") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// Helper extension for custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))

        // Top edge and top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                radius: tr,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
        }

        // Right edge and bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                radius: br,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
        }

        // Bottom edge and bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                radius: bl,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
        }

        // Left edge and top-left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                radius: tl,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
        }

        return path
    }
}
