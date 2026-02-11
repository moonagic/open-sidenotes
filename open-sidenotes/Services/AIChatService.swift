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
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    private let settings = AIChatSettings.shared
    private let systemPrompt = "You are an assistant inside a macOS notes app. Answer clearly and concisely in the user's language."
    private let messagesStorageKey = "openai_chat_messages_v1"
    private let maxStoredMessages = 80
    private let maxMessagesForRequest = 20
    private let maxNoteContextCharacters = 6000

    init() {
        if let restored = loadStoredMessages(), !restored.isEmpty {
            messages = restored
        } else {
            messages = [welcomeMessage]
            persistMessages()
        }
    }

    func clearConversation() {
        messages = [
            ChatMessage(role: .assistant, content: "新的对话已开始。")
        ]
        errorMessage = nil
        inputText = ""
        persistMessages()
    }

    func sendCurrentMessage(noteContext: ChatNoteContext? = nil) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            errorMessage = "请先在 Settings 里填写 OpenAI API Key。"
            return
        }

        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        persistMessages()
        inputText = ""
        errorMessage = nil
        isSending = true

        do {
            let reply = try await requestCompletion(apiKey: apiKey, noteContext: noteContext)
            messages.append(ChatMessage(role: .assistant, content: reply))
            persistMessages()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    private func requestCompletion(apiKey: String, noteContext: ChatNoteContext?) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIChatServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let history = Array(messages.suffix(maxMessagesForRequest)).map {
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

    private var welcomeMessage: ChatMessage {
        ChatMessage(role: .assistant, content: "你好，我已经在侧边笔记里了。你可以让我帮你整理、改写、总结、规划。")
    }

    private func loadStoredMessages() -> [ChatMessage]? {
        guard let data = UserDefaults.standard.data(forKey: messagesStorageKey) else {
            return nil
        }
        return try? JSONDecoder().decode([ChatMessage].self, from: data)
    }

    private func persistMessages() {
        let capped = Array(messages.suffix(maxStoredMessages))
        guard let data = try? JSONEncoder().encode(capped) else { return }
        UserDefaults.standard.set(data, forKey: messagesStorageKey)
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
