import SwiftUI

struct SlashMenuOverlay: View {
    let position: CGPoint
    let query: String
    let selectedIndex: Int
    let onSelect: (SlashCommand) -> Void

    var body: some View {
        GeometryReader { geometry in
            let filteredCommands = SlashCommand.filter(by: query)

            if !filteredCommands.isEmpty {
                SlashCommandMenu(
                    commands: filteredCommands,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect
                )
                .position(x: 140, y: 150)
                .allowsHitTesting(true)
            }
        }
        .allowsHitTesting(true)
    }
}
