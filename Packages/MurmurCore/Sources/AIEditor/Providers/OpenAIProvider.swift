import Foundation

/// AI editing provider that uses the OpenAI Chat Completions API.
///
/// Sends pre-processed text to the API with a system prompt constructed from
/// the editing request configuration. API key is passed at init and not stored
/// by the provider — the app layer manages Keychain access.
public final class OpenAIProvider: AIEditingProvider, @unchecked Sendable {

    public let id: String = "openai"
    public let displayName: String = "OpenAI"

    private let apiKey: String
    private let model: String
    private let endpoint: URL
    private let maxTokens: Int
    private let timeout: TimeInterval
    private let promptBuilder: ProviderSystemPrompt
    private let session: URLSession

    public init(
        apiKey: String,
        model: String = "gpt-4o",
        endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        maxTokens: Int = 2048,
        timeout: TimeInterval = 10,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.maxTokens = maxTokens
        self.timeout = timeout
        self.promptBuilder = ProviderSystemPrompt()
        self.session = session
    }

    public func isAvailable() async -> Bool {
        !apiKey.isEmpty
    }

    public func process(_ request: EditingRequest) async throws -> EditingResult {
        guard !apiKey.isEmpty else {
            throw AIEditingError.providerUnavailable(id)
        }

        let systemPrompt = promptBuilder.build(for: request)
        let body = OpenAIRequestBody(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: request.text),
            ],
            max_tokens: maxTokens,
            temperature: 0.3
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIEditingError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AIEditingError.apiError("OpenAI: \(message)")
        }

        let decoded = try JSONDecoder().decode(OpenAIResponseBody.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AIEditingError.invalidResponse
        }

        return EditingResult(
            processedText: content.trimmingCharacters(in: .whitespacesAndNewlines),
            rawText: request.text,
            appliedStages: request.enabledStages,
            executedCommands: [],
            providerID: id,
            processingTime: 0
        )
    }
}

// MARK: - API Types

struct OpenAIRequestBody: Codable, Sendable {
    let model: String
    let messages: [OpenAIMessage]
    let max_tokens: Int
    let temperature: Double
}

struct OpenAIMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct OpenAIResponseBody: Codable, Sendable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable, Sendable {
    let message: OpenAIMessage
}
