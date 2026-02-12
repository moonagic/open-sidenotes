import SwiftUI
import AppKit

struct ChatWorkspaceView: View {
    @ObservedObject var chatService: AIChatService
    let noteContext: ChatNoteContext?
    var showHeader: Bool = true
    @Binding var isSessionDrawerVisible: Bool
    var onSaveMessageAsNote: ((String) -> Void)? = nil

    @AppStorage("ai_chat_include_note_context") private var includeNoteContext = true
    @State private var isInputFocused: Bool = false

    @State private var editingSessionId: UUID?
    @State private var editingSessionTitle: String = ""
    @State private var sessionSearchText: String = ""
    @State private var hoveredSessionId: UUID?
    @State private var inputFocusTrigger: Int = 0
    @State private var inputHeight: CGFloat = 20

    private let drawerWidth: CGFloat = 208
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
                    inputFocusTrigger += 1
                }
            }
            .onChange(of: chatService.currentSessionId) {
                editingSessionId = nil
                editingSessionTitle = ""
                isSessionDrawerVisible = false
                inputFocusTrigger += 1
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
            if showHeader || noteContext != nil {
                conversationTopBar(isNarrowLayout: isNarrowLayout)
            }

            if shouldShowPromptShortcuts {
                quickPromptSection(isNarrowLayout: isNarrowLayout)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(chatService.messages) { message in
                            ChatMessageBubble(
                                message: message,
                                maxBubbleWidth: bubbleMaxWidth,
                                onSaveAsNote: onSaveMessageAsNote
                            )
                            .id(message.id)
                        }

                        if chatService.isSending {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.85)
                                Text("AI 正在思考...")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "6D756F"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, isNarrowLayout ? 12 : 18)
                    .padding(.vertical, 16)
                }
                .background(Color(hex: "F7F9F6"))
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
            if showHeader {
                HStack(spacing: 6) {
                    Text("AI Chat")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "657067"))

                    Text(chatService.currentSessionTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "2E342F"))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }

            if let context = noteContext {
                HStack(spacing: 10) {
                    Image(systemName: includeNoteContext ? "link.circle.fill" : "link.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: includeNoteContext ? "5D7A66" : "9AA39C"))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color(hex: includeNoteContext ? "EAF2EA" : "EFF2EF"))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前笔记上下文")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "505852"))

                        Text(context.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "7F867F"))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Toggle("Use note context", isOn: $includeNoteContext)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Color(hex: "6F8D79"))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "E4E9E2"), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, isNarrowLayout ? 10 : 14)
        .padding(.top, isNarrowLayout ? 8 : 9)
        .padding(.bottom, 10)
        .background(Color(hex: "F9FBF8"))
        .overlay(
            Rectangle()
                .fill(Color(hex: "E8ECE6"))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func quickPromptSection(isNarrowLayout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "728275"))

                Text("Quick prompts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "6E766F"))
            }
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
                                .foregroundColor(Color(hex: "4E5A51"))
                                .lineLimit(1)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(hex: "DEE6DE"), lineWidth: 1)
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
        .background(Color(hex: "F9FBF8"))
        .overlay(
            Rectangle()
                .fill(Color(hex: "E8EDE8"))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func composerSection(isNarrowLayout: Bool) -> some View {
        let minInputHeight: CGFloat = 20
        let maxInputHeight: CGFloat = isNarrowLayout ? 108 : 124

        return VStack(spacing: 10) {
            if let error = chatService.errorMessage, !error.isEmpty {
                HStack {
                    Text(error)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "D95F5F"))
                    Spacer()
                }
                .padding(.horizontal, isNarrowLayout ? 12 : 16)
            }

            ZStack(alignment: .trailing) {
                AutoGrowingInputTextView(
                    text: $chatService.inputText,
                    dynamicHeight: $inputHeight,
                    isFocused: $isInputFocused,
                    focusTrigger: inputFocusTrigger,
                    isEditable: !chatService.isSending,
                    minHeight: minInputHeight,
                    maxHeight: maxInputHeight
                )
                .frame(height: inputHeight)
                .padding(.leading, 12)
                .padding(.trailing, 44)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    Color(hex: isInputFocused ? "B9C8BA" : "D8DFD8"),
                                    lineWidth: isInputFocused ? 1.25 : 1
                                )
                        )
                )
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(canSend ? Color(hex: "6F8D79") : Color(hex: "B7C2B9"))
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!canSend)
                .padding(.trailing, 10)
            }
            .padding(.horizontal, isNarrowLayout ? 12 : 16)

            HStack {
                if includeNoteContext, let context = effectiveContext {
                    Text(isNarrowLayout ? "Context on" : "Context: \(context.summary)")
                        .lineLimit(1)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "7F8680"))
                } else {
                    Text(noteContext == nil ? "No note context" : "Context off")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "9AA19A"))
                }

                Spacer()

                Text("⌘↩ Send")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "8F9791"))
            }
            .padding(.horizontal, isNarrowLayout ? 12 : 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .background(Color(hex: "F9FBF8"))
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
            inputFocusTrigger += 1
        }
    }

    private func sendMessage() {
        Task {
            await chatService.sendCurrentMessage(noteContext: effectiveContext)
        }
    }
}

private struct AutoGrowingInputTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    @Binding var isFocused: Bool

    let focusTrigger: Int
    let isEditable: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = NSTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.delegate = context.coordinator
        textView.string = text

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
            textContainer.lineFragmentPadding = 0
            textContainer.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        scrollView.documentView = textView

        DispatchQueue.main.async {
            context.coordinator.recalculateHeight(for: textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self

        guard let textView = scrollView.documentView as? NSTextView else { return }

        textView.isEditable = isEditable
        textView.isSelectable = isEditable

        if textView.string != text {
            textView.string = text
        }

        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(
                width: max(0, scrollView.contentSize.width),
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        DispatchQueue.main.async {
            context.coordinator.recalculateHeight(for: textView)
        }

        if focusTrigger != context.coordinator.lastAppliedFocusTrigger {
            context.coordinator.lastAppliedFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                guard isEditable, let window = textView.window else { return }
                window.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoGrowingInputTextView
        var lastAppliedFocusTrigger: Int = 0

        init(_ parent: AutoGrowingInputTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            let newValue = textView.string
            if parent.text != newValue {
                parent.text = newValue
            }

            recalculateHeight(for: textView)
        }

        func textDidBeginEditing(_ notification: Notification) {
            if !parent.isFocused {
                parent.isFocused = true
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            if parent.isFocused {
                parent.isFocused = false
            }
        }

        func recalculateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedHeight = layoutManager.usedRect(for: textContainer).height
            let lineHeight = layoutManager.defaultLineHeight(for: textView.font ?? .systemFont(ofSize: 14))
            let measured = max(lineHeight, ceil(usedHeight))
            let clamped = min(max(parent.minHeight, measured), parent.maxHeight)

            if abs(parent.dynamicHeight - clamped) > 0.5 {
                parent.dynamicHeight = clamped
            }
        }
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage
    let maxBubbleWidth: CGFloat
    var onSaveAsNote: ((String) -> Void)? = nil
    private var isAssistant: Bool { message.role == .assistant }
    private var canSave: Bool {
        guard onSaveAsNote != nil else { return false }
        return !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: isAssistant ? .leading : .trailing, spacing: 4) {
            if isAssistant {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: "7A897D"))
                        .frame(width: 5, height: 5)

                    Text("AI")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "6A756D"))
                }
                .padding(.leading, 4)
            }

            HStack {
                if isAssistant {
                    bubble
                        .frame(maxWidth: maxBubbleWidth, alignment: .leading)

                    Spacer(minLength: 16)
                } else {
                    Spacer(minLength: 16)

                    bubble
                        .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: isAssistant ? .leading : .trailing)
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(message.content)
                .font(.system(size: 14))
                .foregroundColor(isAssistant ? Color(hex: "2C342D") : .white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if canSave {
                HStack {
                    Spacer(minLength: 0)
                    Button(action: {
                        onSaveAsNote?(message.content)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Save")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(isAssistant ? Color(hex: "637063") : Color.white.opacity(0.92))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isAssistant ? Color(hex: "EEF3EE") : Color.white.opacity(0.18))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(bubbleFillStyle)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isAssistant ? Color(hex: "DEE5DE") : Color.clear, lineWidth: 1)
                )
        )
        .shadow(
            color: Color.black.opacity(isAssistant ? 0.04 : 0.08),
            radius: isAssistant ? 2 : 4,
            x: 0,
            y: 1
        )
        .contextMenu {
            if canSave {
                Button("Save as note") {
                    onSaveAsNote?(message.content)
                }
            }
        }
    }

    private var bubbleFillStyle: AnyShapeStyle {
        if isAssistant {
            return AnyShapeStyle(Color.white)
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [Color(hex: "7B9885"), Color(hex: "6E8B79")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
