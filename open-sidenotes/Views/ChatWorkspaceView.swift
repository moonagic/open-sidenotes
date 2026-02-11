import SwiftUI

struct ChatWorkspaceView: View {
    @ObservedObject var chatService: AIChatService
    let noteContext: ChatNoteContext?
    var showHeader: Bool = true

    @AppStorage("ai_chat_include_note_context") private var includeNoteContext = true
    @FocusState private var isInputFocused: Bool

    private var effectiveContext: ChatNoteContext? {
        includeNoteContext ? noteContext : nil
    }

    private var canSend: Bool {
        !chatService.isSending && !chatService.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowTopSection: Bool {
        showHeader || noteContext != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if shouldShowTopSection {
                VStack(spacing: 10) {
                    if showHeader {
                        HStack {
                            Text("AI Chat")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "2C2C2C"))

                            Spacer()

                            Button(action: {
                                chatService.clearConversation()
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
                .padding(.horizontal, 24)
                .padding(.top, showHeader ? 16 : 12)
                .padding(.bottom, 12)

                Divider()
                    .background(Color(hex: "E8E8E8"))
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
                .onChange(of: chatService.messages.count) { _ in
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
        .background(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
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
