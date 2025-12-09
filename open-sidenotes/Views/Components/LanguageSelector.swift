import SwiftUI

struct LanguageSelector: View {
    let onSelect: (CodeLanguage) -> Void
    @State private var selectedIndex: Int = 0
    @State private var eventMonitor: Any?
    @State private var isReady: Bool = false

    private let languages: [CodeLanguage] = [
        .swift, .python,
        .javascript, .typescript,
        .json, .html,
        .css, .plain
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(languages.enumerated()), id: \.element) { index, language in
                    LanguageOptionRow(
                        language: language,
                        isSelected: index == selectedIndex,
                        onTap: {
                            onSelect(language)
                        }
                    )
                    .onTapGesture {
                        onSelect(language)
                    }
                }
            }
            .padding(8)
        }
        .frame(width: 300)
        .background(Color(hex: "FFFFFF"))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isReady = true
                self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    self.handleKeyEvent(event)
                }
                print("🎹 [LanguageSelector] Keyboard monitor added")
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
                print("🎹 [LanguageSelector] Keyboard monitor removed")
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isReady else {
            print("🎹 [LanguageSelector] Not ready yet, ignoring key event")
            return event
        }

        switch event.keyCode {
        case 123:
            selectedIndex = max(0, selectedIndex - 1)
            return nil
        case 124:
            selectedIndex = min(languages.count - 1, selectedIndex + 1)
            return nil
        case 125:
            selectedIndex = min(languages.count - 1, selectedIndex + 2)
            return nil
        case 126:
            selectedIndex = max(0, selectedIndex - 2)
            return nil
        case 36:
            print("🎹 [LanguageSelector] Enter pressed, selecting: \(languages[selectedIndex].displayName)")
            onSelect(languages[selectedIndex])
            return nil
        case 53:
            return nil
        default:
            return event
        }
    }
}

struct LanguageOptionRow: View {
    let language: CodeLanguage
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: language.icon)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "7C9885"))
                .frame(width: 16, height: 16)

            Text(language.displayName)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(hex: "2C2C2C"))

            Spacer()
        }
        .frame(height: 36)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(hex: "7C9885").opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color(hex: "7C9885").opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
