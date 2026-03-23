import Foundation

/// AI editing provider that uses the Anthropic Messages API.
///
/// Sends pre-processed text to the API with a system prompt constructed from
/// the editing request configuration. API key is passed at init and not stored
/// by the provider — the app layer manages Keychain access.
public final class ClaudeProvider: AIEditingProvider, @unchecked Sendable {

    public let id: String = "claude"
    public let displayName: String = "Claude"

    private let apiKey: String
    private let model: String
    private let endpoint: URL
    private let maxTokens: Int
    private let timeout: TimeInterval
    private let apiVersion: String
    private let promptBuilder: ProviderSystemPrompt
    private let session: URLSession

    public init(
        apiKey: String,
        model: String = "claude-sonnet-4-5-20241022",
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
        maxTokens: Int = 2048,
        timeout: TimeInterval = 10,
        apiVersion: String = "2023-06-01",
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.maxTokens = maxTokens
        self.timeout = timeout
        self.apiVersion = apiVersion
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
        let body = ClaudeRequestBody(
            model: model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: [
                .init(role: "user", content: request.text),
            ]
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIEditingError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AIEditingError.apiError("Claude: \(message)")
        }

        let decoded = try JSONDecoder().decode(ClaudeResponseBody.self, from: data)
        guard let textBlock = decoded.content.first(where: { $0.type == "text" }) else {
            throw AIEditingError.invalidResponse
        }

        return EditingResult(
            processedText: textBlock.text.trimmingCharacters(in: .whitespacesAndNewlines),
            rawText: request.text,
            appliedStages: request.enabledStages,
            executedCommands: [],
            providerID: id,
            processingTime: 0
        )
    }
}

// MARK: - API Types

struct ClaudeRequestBody: Codable, Sendable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessage]
}

struct ClaudeMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct ClaudeResponseBody: Codable, Sendable {
    let content: [ClaudeContentBlock]
}

struct ClaudeContentBlock: Codable, Sendable {
    let type: String
    let text: String
}
