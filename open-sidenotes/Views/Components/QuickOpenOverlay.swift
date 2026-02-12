import SwiftUI
import AppKit

struct QuickOpenOverlay: View {
    let notes: [Note]
    let recentNoteIDs: [UUID]
    let onSelect: (Note) -> Void
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var keyMonitor: Any?
    @State private var indexedNotes: [QuickOpenSearchService.IndexedNote] = []
    @State private var searchResults: [Note] = []
    @State private var searchGeneration: Int = 0
    @State private var indexGeneration: Int = 0
    @State private var pendingSearchWorkItem: DispatchWorkItem?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(180, geometry.size.width - 24)
            let panelWidth = min(560, availableWidth)
            let listHeight = min(360, max(120, geometry.size.height - 180))

            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onDismiss()
                    }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "7D857D"))

                        TextField("Quick open notes", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .medium))
                            .focused($isSearchFocused)

                        Text("⌘J")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "9AA29A"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "EEF2ED"))
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)

                    Divider()
                        .background(Color(hex: "E3E8E1"))

                    if searchResults.isEmpty {
                        VStack(spacing: 8) {
                            Spacer(minLength: 26)
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundColor(Color(hex: "A4ACA4"))
                            Text("No matching notes")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "8A938A"))
                            Spacer(minLength: 26)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, note in
                                    QuickOpenRow(
                                        note: note,
                                        isSelected: index == selectedIndex,
                                        onTap: { open(note) }
                                    )
                                    .onHover { hovering in
                                        if hovering {
                                            selectedIndex = index
                                        }
                                    }
                                }
                            }
                            .padding(8)
                        }
                        .frame(maxHeight: listHeight)
                        .background(Color.white)
                    }

                    Divider()
                        .background(Color(hex: "E3E8E1"))

                    HStack(spacing: 12) {
                        Text("↩ Open")
                        Text("↑↓ Select")
                        Text("Esc Close")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "9AA29A"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FBFCFA"))
                }
                .frame(width: panelWidth)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "DDE4DA"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 8)
                .padding(.horizontal, 12)
            }
        }
        .onAppear {
            query = ""
            selectedIndex = 0
            indexedNotes = []
            searchResults = []
            rebuildIndexAndSearch()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
            attachKeyMonitor()
        }
        .onDisappear {
            pendingSearchWorkItem?.cancel()
            pendingSearchWorkItem = nil
            detachKeyMonitor()
        }
        .onChange(of: query) {
            selectedIndex = 0
            scheduleSearch()
        }
        .onChange(of: notes) {
            rebuildIndexAndSearch()
        }
        .onChange(of: recentNoteIDs) {
            scheduleSearch()
        }
    }

    private func open(_ note: Note) {
        onSelect(note)
    }

    private func rebuildIndexAndSearch() {
        indexGeneration += 1
        let generation = indexGeneration
        let notesSnapshot = notes
        let querySnapshot = query
        let recentSnapshot = recentNoteIDs

        DispatchQueue.global(qos: .userInitiated).async {
            let rebuiltIndex = QuickOpenSearchService.buildIndex(from: notesSnapshot)
            let ranked = QuickOpenSearchService.rankedNotes(
                from: rebuiltIndex,
                query: querySnapshot,
                recentNoteIDs: recentSnapshot
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
        let querySnapshot = query
        let recentSnapshot = recentNoteIDs
        let indexedSnapshot = indexedNotes

        let workItem = DispatchWorkItem {
            let ranked = QuickOpenSearchService.rankedNotes(
                from: indexedSnapshot,
                query: querySnapshot,
                recentNoteIDs: recentSnapshot
            )

            DispatchQueue.main.async {
                guard generation == searchGeneration else { return }
                applySearchResults(ranked)
            }
        }

        pendingSearchWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.06, execute: workItem)
    }

    private func applySearchResults(_ ranked: [Note]) {
        searchResults = ranked
        if selectedIndex >= ranked.count {
            selectedIndex = max(0, ranked.count - 1)
        }
    }

    private func attachKeyMonitor() {
        detachKeyMonitor()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 125: // Down
                if !searchResults.isEmpty {
                    selectedIndex = min(selectedIndex + 1, searchResults.count - 1)
                    return nil
                }
            case 126: // Up
                if !searchResults.isEmpty {
                    selectedIndex = max(selectedIndex - 1, 0)
                    return nil
                }
            case 36, 76: // Return / Enter
                if !searchResults.isEmpty {
                    open(searchResults[selectedIndex])
                    return nil
                }
            case 53: // Escape
                onDismiss()
                return nil
            default:
                break
            }

            return event
        }
    }

    private func detachKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

private struct QuickOpenRow: View {
    let note: Note
    let isSelected: Bool
    let onTap: () -> Void

    private var titleText: String {
        let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var previewText: String {
        let merged = note.content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return merged.isEmpty ? "No content" : String(merged.prefix(120))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(titleText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "2F3631"))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(relativeTime(from: note.updatedAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "98A098"))
                }

                Text(previewText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "748074"))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? Color(hex: "E1ECE2") : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        if seconds < 604800 { return "\(seconds / 86400)d" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
