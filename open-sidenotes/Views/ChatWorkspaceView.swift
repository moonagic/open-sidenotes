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
    @State private var hoveredSessionId: UUID?
    @State private var isSessionDrawerVisible: Bool = false

    private let drawerWidth: CGFloat = 220
    private let narrowWidthThreshold: CGFloat = 760

    private var effectiveContext: ChatNoteContext? {
        includeNoteContext ? noteContext : nil
    }

    private var canSend: Bool {
        !chatService.isSending && !chatService.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        GeometryReader { geometry in
            let isNarrowLayout = geometry.size.width < narrowWidthThreshold
            let bubbleMaxWidth = max(220, min(620, geometry.size.width * (isNarrowLayout ? 0.86 : 0.72)))

            ZStack(alignment: .leading) {
                conversationPanel(
                    isNarrowLayout: isNarrowLayout,
                    bubbleMaxWidth: bubbleMaxWidth
                )

                if isSessionDrawerVisible {
                    Color.black.opacity(0.16)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isSessionDrawerVisible = false
                            }
                        }
                        .transition(.opacity)
                        .zIndex(1)

                    sessionDrawer(isNarrowLayout: isNarrowLayout)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(2)
                }
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
                isSessionDrawerVisible = false
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                if newWidth >= narrowWidthThreshold {
                    hoveredSessionId = nil
                }
            }
        }
    }

    private func conversationPanel(isNarrowLayout: Bool, bubbleMaxWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            conversationTopBar(isNarrowLayout: isNarrowLayout)

            if shouldShowPromptShortcuts {
                quickPromptSection(isNarrowLayout: isNarrowLayout)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatService.messages) { message in
                            ChatMessageBubble(
                                message: message,
                                maxBubbleWidth: bubbleMaxWidth
                            )
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
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.horizontal, isNarrowLayout ? 12 : 16)
                    .padding(.vertical, 14)
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

            composerSection(isNarrowLayout: isNarrowLayout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func conversationTopBar(isNarrowLayout: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSessionDrawerVisible.toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 12, weight: .semibold))

                        if !isNarrowLayout {
                            Text("Chats")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .foregroundColor(Color(hex: "5F6A62"))
                    .padding(.horizontal, isNarrowLayout ? 8 : 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "EEF2EC"))
                    )
                }
                .buttonStyle(.plain)
                .help("Show chats")

                if showHeader {
                    Text("AI Chat")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "546058"))
                }

                Text(chatService.currentSessionTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "2E342F"))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button(action: {
                    chatService.startNewSession()
                }) {
                    if isNarrowLayout {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "5F6A62"))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "EEF2EC"))
                            )
                    } else {
                        Label("New chat", systemImage: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "5F6A62"))
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "EEF2EC"))
                            )
                    }
                }
                .buttonStyle(.plain)
                .help("New chat")
            }

            if let context = noteContext {
                HStack(spacing: 8) {
                    Image(systemName: includeNoteContext ? "link.circle.fill" : "link.circle")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: includeNoteContext ? "7C9885" : "A5A5A5"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前笔记上下文")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "5B635D"))

                        Text(context.title)
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "8A8A8A"))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Button(includeNoteContext ? "ON" : "OFF") {
                        includeNoteContext.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(includeNoteContext ? Color(hex: "7C9885") : Color(hex: "A0A0A0"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(hex: "F4F7F4"))
                )
            }
        }
        .padding(.horizontal, isNarrowLayout ? 10 : 14)
        .padding(.top, isNarrowLayout ? 8 : 10)
        .padding(.bottom, 10)
        .background(Color(hex: "FCFDFC"))
        .overlay(
            Rectangle()
                .fill(Color(hex: "E8ECE6"))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func quickPromptSection(isNarrowLayout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick prompts")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "7C837D"))
                .padding(.horizontal, isNarrowLayout ? 12 : 16)
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
                .padding(.horizontal, isNarrowLayout ? 12 : 16)
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

    private func composerSection(isNarrowLayout: Bool) -> some View {
        VStack(spacing: 8) {
            if let error = chatService.errorMessage, !error.isEmpty {
                HStack {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "D95F5F"))
                    Spacer()
                }
                .padding(.horizontal, isNarrowLayout ? 12 : 16)
            }

            HStack(alignment: .bottom, spacing: 8) {
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
            .padding(.horizontal, isNarrowLayout ? 12 : 16)

            HStack {
                if includeNoteContext, let context = effectiveContext {
                    Text(isNarrowLayout ? "Context: On" : "Context: \(context.summary)")
                        .lineLimit(1)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8C8C8C"))
                } else {
                    Text("Context: Off")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "A0A0A0"))
                }

                Spacer()

                Text("Send: ⌘↩")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "9A9A9A"))
            }
            .padding(.horizontal, isNarrowLayout ? 12 : 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .background(Color(hex: "FAFAFA"))
    }

    private func sessionDrawer(isNarrowLayout: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chats")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "3C443F"))

                    Text("\(chatService.sessions.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "A0A79F"))
                }

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSessionDrawerVisible = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "5F6A62"))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color(hex: "EEF2EC"))
                        )
                }
                .buttonStyle(.plain)
                .help("Close chats")
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "97A097"))

                TextField("Search", text: $sessionSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))

                if !sessionSearchText.isEmpty {
                    Button(action: {
                        sessionSearchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "A8AEA8"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(hex: "EEF2EC"))
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 4) {
                    if filteredSessions.isEmpty {
                        Text("No matching chats")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "A1A8A1"))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 18)
                    } else {
                        ForEach(filteredSessions) { session in
                            sessionRow(session)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            HStack {
                Text("⌘N New chat")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "9CA39C"))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .overlay(
                Rectangle()
                    .fill(Color(hex: "E7EBE3"))
                    .frame(height: 1),
                alignment: .top
            )
        }
        .frame(width: drawerWidth)
        .frame(maxHeight: .infinity)
        .background(Color(hex: "F9FBF8"))
        .overlay(
            Rectangle()
                .fill(Color(hex: "E2E6DE"))
                .frame(width: 1),
            alignment: .trailing
        )
        .shadow(
            color: Color.black.opacity(isNarrowLayout ? 0.14 : 0.1),
            radius: isNarrowLayout ? 18 : 14,
            x: 5,
            y: 0
        )
    }

    private func sessionRow(_ session: ChatSession) -> some View {
        let isSelected = chatService.currentSessionId == session.id
        let isEditing = editingSessionId == session.id
        let isHovered = hoveredSessionId == session.id

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if isEditing {
                    TextField("Chat title", text: $editingSessionTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .onSubmit {
                            commitSessionRename()
                        }
                } else {
                    Text(session.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? Color(hex: "2F4E3D") : Color(hex: "3E4641"))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 4)

                if !isEditing {
                    Text(sessionRelativeTime(from: session.updatedAt))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "A1A8A1"))
                        .lineLimit(1)
                        .fixedSize()

                    Group {
                        if isSelected || isHovered {
                            Menu {
                                Button("Rename") {
                                    beginSessionRename(session)
                                }
                                if chatService.sessions.count > 1 {
                                    Button("Delete", role: .destructive) {
                                        chatService.deleteSession(id: session.id)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "8D9A90"))
                                    .frame(width: 16, height: 16)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        } else {
                            Color.clear
                                .frame(width: 16, height: 16)
                        }
                    }
                }
            }

            if !isEditing && isSelected {
                Text(sessionPreview(session))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "879087"))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color(hex: "DDE9DD") : (isHovered ? Color(hex: "F0F4EF") : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            chatService.switchSession(to: session.id)
            withAnimation(.easeInOut(duration: 0.18)) {
                isSessionDrawerVisible = false
            }
        }
        .onHover { hovering in
            if hovering {
                hoveredSessionId = session.id
            } else if hoveredSessionId == session.id {
                hoveredSessionId = nil
            }
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
    let maxBubbleWidth: CGFloat

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                    .frame(maxWidth: maxBubbleWidth, alignment: .leading)

                Spacer(minLength: 12)
            } else {
                Spacer(minLength: 12)

                bubble
                    .frame(maxWidth: maxBubbleWidth, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .assistant ? .leading : .trailing)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .assistant ? "AI" : "You")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(message.role == .assistant ? Color(hex: "6C7A70") : Color.white.opacity(0.85))

            Text(message.content)
                .font(.system(size: 14))
                .foregroundColor(message.role == .assistant ? Color(hex: "2C2C2C") : .white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
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
