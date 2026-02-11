import SwiftUI

struct ChatWorkspaceView: View {
    @ObservedObject var chatService: AIChatService
    let noteContext: ChatNoteContext?
    var showHeader: Bool = true

    @AppStorage("ai_chat_include_note_context") private var includeNoteContext = true
    @FocusState private var isInputFocused: Bool

    @State private var editingSessionId: UUID?
    @State private var editingSessionTitle: String = ""
    @State private var sessionSearchText: String = ""

    private var effectiveContext: ChatNoteContext? {
        includeNoteContext ? noteContext : nil
    }

    private var canSend: Bool {
        !chatService.isSending && !chatService.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowTopSection: Bool {
        showHeader || noteContext != nil
    }

    private var filteredSessions: [ChatSession] {
        let query = sessionSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return chatService.orderedSessions }
        return chatService.orderedSessions.filter { sessionMatchesQuery($0, query: query) }
    }

    private var shouldShowPromptShortcuts: Bool {
        !chatService.isSending && chatService.messages.count <= 1
    }

    private var quickPrompts: [String] {
        if noteContext != nil {
            return [
                "请总结当前笔记的核心观点，并给出 3 个可执行下一步。",
                "帮我把当前笔记改写成更清晰的结构化内容。",
                "请从当前笔记中提炼待办事项，按优先级排序。",
                "请从当前笔记里找出风险点和缺失信息。"
            ]
        }

        return [
            "帮我把这个想法扩展成一个清晰提纲。",
            "我需要一份今天的高效工作计划。",
            "请帮我把这段内容改写得更简洁专业。",
            "你先问我 3 个问题，帮我澄清目标。"
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            sessionSidebar

            Divider()
                .background(Color(hex: "E2E6DE"))

            conversationPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .onChange(of: chatService.currentSessionId) {
            editingSessionId = nil
            editingSessionTitle = ""
        }
    }

    private var sessionSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chats")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "3C443F"))

                Spacer()

                Button(action: {
                    chatService.startNewSession()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "5F6A62"))
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color(hex: "EEF2EC"))
                        )
                }
                .buttonStyle(.plain)
                .help("New chat")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "97A097"))

                TextField("Search chats", text: $sessionSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !sessionSearchText.isEmpty {
                    Button(action: {
                        sessionSearchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "A8AEA8"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(hex: "EEF2EC"))
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if filteredSessions.isEmpty {
                        Text("No matching chats")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "A1A8A1"))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 22)
                    } else {
                        ForEach(filteredSessions) { session in
                            sessionRow(session)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }

            HStack {
                Text("New chat: ⌘N")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "9CA39C"))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                Rectangle()
                    .fill(Color(hex: "E7EBE3"))
                    .frame(height: 1),
                alignment: .top
            )
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(Color(hex: "F9FBF8"))
    }

    private func sessionRow(_ session: ChatSession) -> some View {
        let isSelected = chatService.currentSessionId == session.id
        let isEditing = editingSessionId == session.id

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if isEditing {
                    TextField("Chat title", text: $editingSessionTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .onSubmit {
                            commitSessionRename()
                        }
                } else {
                    Text(session.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? Color(hex: "2F4E3D") : Color(hex: "3E4641"))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isSelected && !isEditing {
                    Button(action: {
                        beginSessionRename(session)
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "809488"))
                    }
                    .buttonStyle(.plain)
                    .help("Rename")
                }

                if chatService.sessions.count > 1 {
                    Button(action: {
                        chatService.deleteSession(id: session.id)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "A2AAA3"))
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }

            if !isEditing {
                Text(sessionPreview(session))
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "879087"))
                    .lineLimit(2)

                Text(sessionRelativeTime(from: session.updatedAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "A1A8A1"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color(hex: "DDE9DD") : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            chatService.switchSession(to: session.id)
        }
        .onTapGesture(count: 2) {
            beginSessionRename(session)
        }
        .contextMenu {
            Button("Rename") {
                beginSessionRename(session)
            }
            if chatService.sessions.count > 1 {
                Button("Delete", role: .destructive) {
                    chatService.deleteSession(id: session.id)
                }
            }
        }
    }

    private var conversationPanel: some View {
        VStack(spacing: 0) {
            if shouldShowTopSection {
                VStack(spacing: 10) {
                    if showHeader {
                        HStack {
                            Text(chatService.currentSessionTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "2C2C2C"))
                                .lineLimit(1)

                            Spacer()

                            Button(action: {
                                chatService.startNewSession()
                            }) {
                                Label("New Chat", systemImage: "plus.bubble")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "6B6B6B"))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let context = noteContext {
                        HStack(spacing: 10) {
                            Image(systemName: includeNoteContext ? "link.circle.fill" : "link.circle")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: includeNoteContext ? "7C9885" : "A5A5A5"))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("当前笔记上下文")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "555555"))
                                Text(context.title)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "8A8A8A"))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(includeNoteContext ? "ON" : "OFF") {
                                includeNoteContext.toggle()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(includeNoteContext ? Color(hex: "7C9885") : Color(hex: "A0A0A0"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: "F4F7F4"))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, showHeader ? 14 : 10)
                .padding(.bottom, 10)

                Divider()
                    .background(Color(hex: "E8E8E8"))
            }

            if shouldShowPromptShortcuts {
                quickPromptSection
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatService.messages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }

                        if chatService.isSending {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.85)
                                Text("AI 正在思考...")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "7A7A7A"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(Color(hex: "FBFBFB"))
                .onChange(of: chatService.messages.count) {
                    if let last = chatService.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
                .background(Color(hex: "E8E8E8"))

            VStack(spacing: 8) {
                if let error = chatService.errorMessage, !error.isEmpty {
                    HStack {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "D95F5F"))
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    TextEditor(text: $chatService.inputText)
                        .font(.system(size: 14))
                        .focused($isInputFocused)
                        .frame(minHeight: 56, maxHeight: 110)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "DCDCDC"), lineWidth: 1)
                        )
                        .disabled(chatService.isSending)

                    Button(action: {
                        sendMessage()
                    }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color(hex: "7C9885")))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!canSend)
                }
                .padding(.horizontal, 18)

                HStack {
                    if includeNoteContext, let context = effectiveContext {
                        Text("Context: \(context.summary)")
                            .lineLimit(1)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8C8C8C"))
                    } else {
                        Text("Context: Off")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "A0A0A0"))
                    }

                    Spacer()

                    Text("Send: ⌘⏎")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "9A9A9A"))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
            .padding(.top, 10)
            .background(Color(hex: "FAFAFA"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var quickPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick prompts")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "7C837D"))
                .padding(.horizontal, 16)
                .padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickPrompts, id: \.self) { prompt in
                        Button(action: {
                            applyQuickPrompt(prompt)
                        }) {
                            Text(prompt)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "566257"))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "EEF3EE"))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(hex: "DDE5DD"), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        .background(Color(hex: "FCFDFC"))
        .overlay(
            Rectangle()
                .fill(Color(hex: "E8EDE8"))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func beginSessionRename(_ session: ChatSession) {
        editingSessionId = session.id
        editingSessionTitle = session.title
    }

    private func commitSessionRename() {
        guard let sessionId = editingSessionId else { return }
        chatService.renameSession(id: sessionId, to: editingSessionTitle)
        editingSessionId = nil
        editingSessionTitle = ""
    }

    private func sessionPreview(_ session: ChatSession) -> String {
        guard let last = session.messages.last else { return "No messages" }
        let plain = last.content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? "No messages" : String(plain.prefix(56))
    }

    private func sessionRelativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "now"
        }
        if seconds < 3600 {
            return "\(seconds / 60)m ago"
        }
        if seconds < 86400 {
            return "\(seconds / 3600)h ago"
        }
        if seconds < 604800 {
            return "\(seconds / 86400)d ago"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func sessionMatchesQuery(_ session: ChatSession, query: String) -> Bool {
        let title = session.title.lowercased()
        if title.contains(query) {
            return true
        }

        guard let latestMessage = session.messages.last?.content.lowercased() else {
            return false
        }
        return latestMessage.contains(query)
    }

    private func applyQuickPrompt(_ prompt: String) {
        chatService.inputText = prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isInputFocused = true
        }
    }

    private func sendMessage() {
        Task {
            await chatService.sendCurrentMessage(noteContext: effectiveContext)
        }
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 44)
            } else {
                Spacer(minLength: 44)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .assistant ? "AI" : "You")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(message.role == .assistant ? Color(hex: "6C7A70") : Color.white.opacity(0.85))

            Text(message.content)
                .font(.system(size: 14))
                .foregroundColor(message.role == .assistant ? Color(hex: "2C2C2C") : .white)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(message.role == .assistant ? Color(hex: "EEF3EF") : Color(hex: "7C9885"))
        )
    }
}
