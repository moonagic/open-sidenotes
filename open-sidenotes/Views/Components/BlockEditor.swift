import SwiftUI

struct BlockEditor: View {
    @Binding var content: String
    @State private var blocks: [any ContentBlock] = []
    @State private var showSlashMenu = false
    @State private var slashMenuPosition: CGPoint = .zero
    @State private var slashMenuQuery = ""
    @State private var slashMenuSelectedIndex = 0
    @State private var showLanguageSelector = false
    @State private var selectedLanguage: CodeLanguage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        blockView(for: block, at: index)
                            .onAppear {
                                print("🎨 [BlockEditor] Block \(index) appeared")
                            }
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
            print("🟢 [BlockEditor] onAppear triggered")
            print("🟢 [BlockEditor] Initial content: '\(content)'")
            parseContent()
        }
        .onChange(of: content) { newValue in
            print("🔵 [BlockEditor] onChange triggered")
            print("🔵 [BlockEditor] Old content length: \(content.count)")
            print("🔵 [BlockEditor] New content length: \(newValue.count)")
            print("🔵 [BlockEditor] New content preview: '\(String(newValue.prefix(100)))'")
            let shouldUpdate = shouldReparse(newValue)
            print("🔵 [BlockEditor] shouldReparse result: \(shouldUpdate)")
            if shouldUpdate {
                DispatchQueue.main.async {
                    parseContent()
                }
            }
        }
        .onDisappear {
            print("🔴 [BlockEditor] onDisappear triggered")
        }
    }

    @ViewBuilder
    private func blockView(for block: any ContentBlock, at index: Int) -> some View {
        if let textBlock = block as? TextBlock {
            let _ = print("🖼️ [BlockEditor] Creating TextBlockEditor for index \(index), content length: \(textBlock.content.count)")
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
        print("🔄 [BlockEditor] parseContent called")
        print("🔄 [BlockEditor] Current content: '\(content)'")
        blocks = BlockParser.parse(content)
        print("🔄 [BlockEditor] Parsed into \(blocks.count) blocks")
        for (index, block) in blocks.enumerated() {
            if let textBlock = block as? TextBlock {
                print("  Block \(index): TextBlock with \(textBlock.content.count) chars")
            } else if let codeBlock = block as? CodeBlock {
                print("  Block \(index): CodeBlock (\(codeBlock.language.displayName)) with \(codeBlock.code.count) chars")
            }
        }
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
        print("🔷 [BlockEditor] updateTextBlock at index \(index)")
        print("🔷 [BlockEditor] New value: '\(newValue)'")

        guard index < blocks.count, blocks[index] is TextBlock else {
            print("❌ [BlockEditor] Index out of bounds or not a TextBlock")
            return
        }

        let oldBlockId = blocks[index].id
        let hasCodeBlock = newValue.contains("```")

        print("🔷 [BlockEditor] Scheduling async update...")

        DispatchQueue.main.async {
            print("🔷 [BlockEditor] Executing async update")
            self.blocks[index] = TextBlock(id: oldBlockId, content: newValue)

            if hasCodeBlock {
                print("✅ [BlockEditor] Contains code block marker, will reparse")
                self.saveContent()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.parseContent()
                }
            } else {
                print("📝 [BlockEditor] Normal text update, saving")
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
        let oldContent = content
        content = BlockParser.serialize(blocks)
        print("💾 [BlockEditor] saveContent called")
        print("💾 [BlockEditor] Old content length: \(oldContent.count)")
        print("💾 [BlockEditor] New content length: \(content.count)")
        if oldContent != content {
            print("💾 [BlockEditor] Content changed!")
        }
    }

    private func deletePreviousBlock(at index: Int) -> Bool {
        print("🗑️ [BlockEditor] deletePreviousBlock called at index \(index)")
        guard index > 0 && index <= blocks.count else {
            print("❌ [BlockEditor] Invalid index")
            return false
        }

        let previousIndex = index - 1
        print("🗑️ [BlockEditor] Deleting block at index \(previousIndex)")

        DispatchQueue.main.async {
            self.blocks.remove(at: previousIndex)
            self.saveContent()
            print("✅ [BlockEditor] Block deleted, new block count: \(self.blocks.count)")
        }

        return true
    }

    private func insertCommand(_ command: SlashCommand) {
        if command.needsLanguageSelector {
            showSlashMenu = false
            withAnimation(.easeInOut(duration: 0.15)) {
                showLanguageSelector = true
            }
        } else {
            showSlashMenu = false
        }
    }

    private func insertCodeBlock(language: CodeLanguage) {
        print("🟢 [BlockEditor] insertCodeBlock called with language: \(language.displayName)")
        withAnimation(.easeInOut(duration: 0.15)) {
            showLanguageSelector = false
        }
        selectedLanguage = language
        print("🟢 [BlockEditor] Set selectedLanguage to \(language.displayName)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🟢 [BlockEditor] Delayed parseContent execution")
            self.parseContent()
        }
    }
}
