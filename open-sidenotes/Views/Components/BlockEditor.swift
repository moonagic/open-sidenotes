import SwiftUI

struct BlockEditor: View {
    @Binding var content: String
    @State private var blocks: [any ContentBlock] = []
    @State private var showSlashMenu = false
    @State private var slashMenuPosition: CGPoint = .zero
    @State private var slashMenuQuery = ""
    @State private var slashMenuSelectedIndex = 0
    @State private var selectedSlashCommand: SlashCommand?
    @State private var showLanguageSelector = false
    @State private var selectedLanguage: CodeLanguage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        blockView(for: block, at: index)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }

            if showSlashMenu {
                SlashCommandMenu(
                    commands: SlashCommand.filter(by: slashMenuQuery),
                    selectedIndex: slashMenuSelectedIndex,
                    onSelect: { command in
                        insertCommand(command)
                    }
                )
                .padding(.leading, 48)
                .padding(.top, 72)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if showLanguageSelector {
                LanguageSelector(onSelect: { language in
                    insertCodeBlock(language: language)
                })
                .padding(.leading, 48)
                .padding(.top, 72)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onAppear {
            parseContent()
        }
        .onChange(of: content) { newValue in
            let shouldUpdate = shouldReparse(newValue)
            if shouldUpdate {
                DispatchQueue.main.async {
                    parseContent()
                }
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: any ContentBlock, at index: Int) -> some View {
        if let textBlock = block as? TextBlock {
            TextBlockEditor(
                text: Binding(
                    get: { textBlock.content },
                    set: { newValue in
                        updateTextBlock(at: index, with: newValue)
                    }
                ),
                onTextChange: { newValue in
                    updateTextBlock(at: index, with: newValue)
                },
                onDeletePreviousBlock: index > 0 ? {
                    deletePreviousBlock(at: index)
                } : nil,
                showSlashMenu: $showSlashMenu,
                slashMenuPosition: $slashMenuPosition,
                slashMenuQuery: $slashMenuQuery,
                slashMenuSelectedIndex: $slashMenuSelectedIndex,
                selectedSlashCommand: $selectedSlashCommand,
                selectedLanguage: $selectedLanguage,
                showLanguageSelector: $showLanguageSelector
            )
        } else if let codeBlock = block as? CodeBlock {
            CodeBlockEditor(
                code: Binding(
                    get: { codeBlock.code },
                    set: { newValue in
                        updateCodeBlock(at: index, with: newValue)
                    }
                ),
                language: codeBlock.language,
                onCodeChange: { newValue in
                    updateCodeBlock(at: index, with: newValue)
                }
            )
        }
    }

    private func parseContent() {
        blocks = BlockParser.parse(content)
    }

    private func shouldReparse(_ newContent: String) -> Bool {
        let hasCodeBlockMarker = newContent.contains("```")
        let currentHasCodeBlock = blocks.contains(where: { $0 is CodeBlock })

        if hasCodeBlockMarker && !currentHasCodeBlock {
            return true
        }

        return false
    }

    private func updateTextBlock(at index: Int, with newValue: String) {
        guard index < blocks.count, blocks[index] is TextBlock else {
            return
        }

        let oldBlockId = blocks[index].id
        let hasCodeBlock = newValue.contains("```")

        DispatchQueue.main.async {
            self.blocks[index] = TextBlock(id: oldBlockId, content: newValue)

            if hasCodeBlock {
                self.saveContent()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.parseContent()
                }
            } else {
                self.saveContent()
            }
        }
    }

    private func updateCodeBlock(at index: Int, with newValue: String) {
        guard index < blocks.count, let codeBlock = blocks[index] as? CodeBlock else { return }

        let blockId = codeBlock.id
        let language = codeBlock.language

        DispatchQueue.main.async {
            self.blocks[index] = CodeBlock(id: blockId, language: language, code: newValue)
            self.saveContent()
        }
    }

    private func saveContent() {
        content = BlockParser.serialize(blocks)
    }

    private func deletePreviousBlock(at index: Int) -> Bool {
        guard index > 0 && index <= blocks.count else {
            return false
        }

        let previousIndex = index - 1

        DispatchQueue.main.async {
            self.blocks.remove(at: previousIndex)
            self.saveContent()
        }

        return true
    }

    private func insertCommand(_ command: SlashCommand) {
        if command.needsLanguageSelector {
            selectedSlashCommand = nil
            showSlashMenu = false
            withAnimation(.easeInOut(duration: 0.15)) {
                showLanguageSelector = true
            }
        } else {
            showSlashMenu = false
            selectedSlashCommand = command
        }
    }

    private func insertCodeBlock(language: CodeLanguage) {
        withAnimation(.easeInOut(duration: 0.15)) {
            showLanguageSelector = false
        }
        selectedLanguage = language
    }
}
