import SwiftUI

struct SlashCommandMenu: View {
    let commands: [SlashCommand]
    let selectedIndex: Int
    let onSelect: (SlashCommand) -> Void
    private let rowHeight: CGFloat = 56
    private let maxMenuHeight: CGFloat = 300

    var body: some View {
        let contentHeight = CGFloat(commands.count) * rowHeight
        let menuHeight = min(maxMenuHeight, max(rowHeight, contentHeight))

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                        Button(action: {
                            onSelect(command)
                        }) {
                            SlashCommandRow(
                                command: command,
                                isSelected: index == selectedIndex
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(command.id)
                    }
                }
            }
            .frame(height: menuHeight)
            .onAppear {
                scrollToSelectedCommand(with: proxy)
            }
            .onChange(of: selectedIndex) {
                scrollToSelectedCommand(with: proxy)
            }
            .onChange(of: commands) {
                scrollToSelectedCommand(with: proxy)
            }
        }
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "E8E8E8"), lineWidth: 1)
        )
    }

    private func scrollToSelectedCommand(with proxy: ScrollViewProxy) {
        guard commands.indices.contains(selectedIndex) else { return }
        let selectedID = commands[selectedIndex].id
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.12)) {
                proxy.scrollTo(selectedID, anchor: .center)
            }
        }
    }
}

struct SlashCommandRow: View {
    let command: SlashCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(isSelected ? Color(hex: "7C9885") : Color(hex: "666666"))
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "2C2C2C") : Color(hex: "444444"))

                Text(command.description)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "999999"))
            }

            Spacer()

            Text("/\(command.trigger)")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color(hex: "AAAAAA"))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: "F5F5F5"))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color(hex: "7C9885").opacity(0.08) : Color.clear)
    }
}

#Preview {
    VStack(spacing: 20) {
        SlashCommandMenu(
            commands: SlashCommand.allCommands,
            selectedIndex: 0,
            onSelect: { _ in }
        )

        SlashCommandMenu(
            commands: SlashCommand.filter(by: "h"),
            selectedIndex: 1,
            onSelect: { _ in }
        )
    }
    .padding()
    .frame(width: 400, height: 600)
    .background(Color(hex: "FAF9F6"))
}
