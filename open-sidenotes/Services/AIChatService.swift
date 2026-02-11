import Foundation

struct ChatNoteContext {
    let title: String
    let content: String

    var summary: String {
        let singleLine = content.replacingOccurrences(of: "\n", with: " ")
        return String(singleLine.prefix(100))
    }
}

@MainActor
final class AIChatSettings: ObservableObject {
    static let shared = AIChatSettings()

    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: apiKeyKey)
        }
    }

    @Published var modelName: String {
        didSet {
            let trimmed = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = trimmed.isEmpty ? "gpt-4o-mini" : trimmed

            if modelName != normalized {
                modelName = normalized
                return
            }

            UserDefaults.standard.set(normalized, forKey: modelNameKey)
        }
    }

    private let apiKeyKey = "openai_api_key"
    private let modelNameKey = "openai_model_name"

    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: apiKeyKey) ?? ""
        self.modelName = UserDefaults.standard.string(forKey: modelNameKey) ?? "gpt-4o-mini"
    }
}

@MainActor
final class AIChatService: ObservableObject {
    @Published private(set) var sessions: [ChatSession] = []
    @Published private(set) var currentSessionId: UUID?
    @Published private(set) var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    private let settings = AIChatSettings.shared
    private let systemPrompt = "You are an assistant inside a macOS notes app. Answer clearly and concisely in the user's language."

    private let sessionsStorageKey = "openai_chat_sessions_v1"
    private let currentSessionIdKey = "openai_chat_current_session_id_v1"
    private let legacyMessagesStorageKey = "openai_chat_messages_v1"

    private let maxStoredSessions = 40
    private let maxStoredMessages = 80
    private let maxMessagesForRequest = 20
    private let maxNoteContextCharacters = 6000

    var orderedSessions: [ChatSession] {
        sessions.sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var currentSession: ChatSession? {
        guard let currentSessionId else { return nil }
        return sessions.first(where: { $0.id == currentSessionId })
    }

    var currentSessionTitle: String {
        currentSession?.title ?? "New Chat"
    }

    init() {
        bootstrapSessions()
    }

    func startNewSession() {
        let session = ChatSession(
            title: "New Chat",
            messages: [newConversationMessage]
        )
        sessions.insert(session, at: 0)
        currentSessionId = session.id
        inputText = ""
        errorMessage = nil
        reconcileState(shouldPersist: true)
    }

    func switchSession(to sessionId: UUID) {
        guard sessions.contains(where: { $0.id == sessionId }) else { return }
        currentSessionId = sessionId
        inputText = ""
        errorMessage = nil
        syncMessagesFromCurrentSession()
        persistSessions()
    }

    func renameSession(id sessionId: UUID, to title: String) {
        let normalized = normalizeTitle(title)
        guard !normalized.isEmpty else { return }

        mutateSession(id: sessionId) { session in
            session.title = normalized
        }
    }

    func deleteSession(id sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        if sessions.count == 1 {
            clearConversation()
            return
        }

        let deletingCurrent = sessionId == currentSessionId
        sessions.remove(at: index)

        if deletingCurrent {
            currentSessionId = sessions.first?.id
        }

        reconcileState(shouldPersist: true)
    }

    func clearConversation() {
        guard let sessionId = currentSessionId else {
            startNewSession()
            return
        }

        mutateSession(id: sessionId) { session in
            session.messages = [newConversationMessage]
        }

        errorMessage = nil
        inputText = ""
    }

    func sendCurrentMessage(noteContext: ChatNoteContext? = nil) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            errorMessage = "请先在 Settings 里填写 OpenAI API Key。"
            return
        }

        if currentSessionId == nil {
            startNewSession()
        }

        guard let sendingSessionId = currentSessionId else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed)
        let suggestedTitle = shouldAutoNameSession(id: sendingSessionId)
            ? inferSessionTitle(from: trimmed)
            : nil

        mutateSession(id: sendingSessionId) { session in
            session.messages.append(userMessage)
            if let suggestedTitle {
                session.title = suggestedTitle
            }
        }

        inputText = ""
        errorMessage = nil
        isSending = true

        let requestHistory = Array(messagesForSession(id: sendingSessionId).suffix(maxMessagesForRequest))

        do {
            let reply = try await requestCompletion(
                apiKey: apiKey,
                noteContext: noteContext,
                historyMessages: requestHistory
            )
            mutateSession(id: sendingSessionId) { session in
                session.messages.append(ChatMessage(role: .assistant, content: reply))
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    private func requestCompletion(apiKey: String, noteContext: ChatNoteContext?, historyMessages: [ChatMessage]) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIChatServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let history = historyMessages.map {
            ChatCompletionRequest.Message(role: $0.role.rawValue, content: $0.content)
        }

        var prompt = systemPrompt
        if let context = noteContext {
            let trimmedContent = context.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedContent.isEmpty {
                let cappedContent = String(trimmedContent.prefix(maxNoteContextCharacters))
                prompt += "\n\nCurrent note context:\nTitle: \(context.title)\nContent:\n\(cappedContent)\n\nUse this context when it is relevant to the user's request."
            }
        }

        let payload = ChatCompletionRequest(
            model: settings.modelName,
            messages: [ChatCompletionRequest.Message(role: "system", content: prompt)] + history,
            temperature: 0.7
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIChatServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorPayload = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw AIChatServiceError.server(message: errorPayload.error.message)
            }
            throw AIChatServiceError.server(message: "请求失败，状态码 \(httpResponse.statusCode)")
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !content.isEmpty else {
            throw AIChatServiceError.emptyResponse
        }

        return content
    }

    private func bootstrapSessions() {
        if let storedSessions = loadStoredSessions(), !storedSessions.isEmpty {
            sessions = storedSessions
        } else if let legacyMessages = loadLegacyMessages(), !legacyMessages.isEmpty {
            sessions = [
                ChatSession(
                    title: "Imported Chat",
                    createdAt: legacyMessages.first?.createdAt ?? Date(),
                    updatedAt: legacyMessages.last?.createdAt ?? Date(),
                    messages: legacyMessages
                )
            ]
            UserDefaults.standard.removeObject(forKey: legacyMessagesStorageKey)
        } else {
            sessions = [
                ChatSession(
                    title: "New Chat",
                    messages: [welcomeMessage]
                )
            ]
        }

        if let storedCurrentSession = loadStoredCurrentSessionID(),
           sessions.contains(where: { $0.id == storedCurrentSession }) {
            currentSessionId = storedCurrentSession
        } else {
            currentSessionId = sessions.first?.id
        }

        reconcileState(shouldPersist: true)
    }

    private func mutateSession(id sessionId: UUID, touchUpdatedAt: Bool = true, _ mutation: (inout ChatSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        var session = sessions[index]
        mutation(&session)

        session.messages = Array(session.messages.suffix(maxStoredMessages))
        session.title = normalizeTitle(session.title)
        if touchUpdatedAt {
            session.updatedAt = Date()
        }

        sessions[index] = session
        reconcileState(shouldPersist: true)
    }

    private func reconcileState(shouldPersist: Bool) {
        sessions = normalizeSessions(sessions)

        if sessions.isEmpty {
            sessions = [ChatSession(title: "New Chat", messages: [welcomeMessage])]
        }

        if let currentSessionId,
           sessions.contains(where: { $0.id == currentSessionId }) {
            // keep current
        } else {
            currentSessionId = sessions.first?.id
        }

        syncMessagesFromCurrentSession()

        if shouldPersist {
            persistSessions()
        }
    }

    private func syncMessagesFromCurrentSession() {
        messages = currentSession?.messages ?? []
    }

    private func normalizeSessions(_ source: [ChatSession]) -> [ChatSession] {
        var normalized = source.map { session in
            var session = session
            session.title = normalizeTitle(session.title)
            session.messages = Array(session.messages.suffix(maxStoredMessages))

            if session.messages.isEmpty {
                session.messages = [newConversationMessage]
            }

            return session
        }

        normalized.sort {
            if $0.updatedAt == $1.updatedAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.updatedAt > $1.updatedAt
        }

        if normalized.count > maxStoredSessions {
            normalized = Array(normalized.prefix(maxStoredSessions))
        }

        return normalized
    }

    private func messagesForSession(id sessionId: UUID) -> [ChatMessage] {
        sessions.first(where: { $0.id == sessionId })?.messages ?? []
    }

    private func shouldAutoNameSession(id sessionId: UUID) -> Bool {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return false }
        let normalized = normalizeTitle(session.title)
        return normalized == "New Chat" || normalized == "Imported Chat"
    }

    private func inferSessionTitle(from text: String) -> String {
        let singleLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !singleLine.isEmpty else { return "New Chat" }

        let parts = singleLine.split(separator: " ").prefix(8)
        let joined = parts.joined(separator: " ")
        return normalizeTitle(joined)
    }

    private func normalizeTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "New Chat" }
        return String(trimmed.prefix(60))
    }

    private var welcomeMessage: ChatMessage {
        ChatMessage(role: .assistant, content: "你好，我已经在侧边笔记里了。你可以让我帮你整理、改写、总结、规划。")
    }

    private var newConversationMessage: ChatMessage {
        ChatMessage(role: .assistant, content: "新的对话已开始。")
    }

    private func loadStoredSessions() -> [ChatSession]? {
        guard let data = UserDefaults.standard.data(forKey: sessionsStorageKey) else {
            return nil
        }
        return try? JSONDecoder().decode([ChatSession].self, from: data)
    }

    private func loadLegacyMessages() -> [ChatMessage]? {
        guard let data = UserDefaults.standard.data(forKey: legacyMessagesStorageKey) else {
            return nil
        }
        return try? JSONDecoder().decode([ChatMessage].self, from: data)
    }

    private func loadStoredCurrentSessionID() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: currentSessionIdKey) else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    private func persistSessions() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: sessionsStorageKey)
        UserDefaults.standard.set(currentSessionId?.uuidString, forKey: currentSessionIdKey)
    }
}

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct OpenAIErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let message: String
    }

    let error: ErrorBody
}

enum AIChatServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "AI 服务地址无效。"
        case .invalidResponse:
            return "AI 服务返回异常。"
        case .emptyResponse:
            return "AI 没有返回内容。"
        case .server(let message):
            return message
        }
    }
}
