import Testing
import Foundation
@testable import AIEditor

@Suite("Claude Provider", .serialized)
struct ClaudeProviderTests {

    @Test("Unavailable when API key is empty")
    func unavailableWithoutKey() async {
        let provider = ClaudeProvider(apiKey: "")
        let available = await provider.isAvailable()
        #expect(!available)
    }

    @Test("Available when API key is set")
    func availableWithKey() async {
        let provider = ClaudeProvider(apiKey: "sk-ant-test")
        let available = await provider.isAvailable()
        #expect(available)
    }

    @Test("Throws providerUnavailable when key is empty")
    func throwsWhenUnavailable() async {
        let provider = ClaudeProvider(apiKey: "")
        let request = EditingRequest(text: "hello")
        await #expect(throws: AIEditingError.self) {
            try await provider.process(request)
        }
    }

    @Test("Parses successful response correctly")
    func parsesResponse() async throws {
        let url = URL(string: "https://mock-claude.test/v1/messages")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"content": [{"type": "text", "text": "Hello, world."}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        let result = try await provider.process(EditingRequest(text: "hello world"))
        #expect(result.processedText == "Hello, world.")
        #expect(result.providerID == "claude")
    }

    @Test("Sends correct headers")
    func sendsHeaders() async throws {
        let url = URL(string: "https://mock-claude.test/headers")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"content": [{"type": "text", "text": "ok"}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-key-123", endpoint: url, session: session)
        _ = try await provider.process(EditingRequest(text: "hi"))

        let captured = MockURLProtocol.capturedRequest(for: url)
        #expect(captured?.value(forHTTPHeaderField: "x-api-key") == "sk-ant-key-123")
        #expect(captured?.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(captured?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("Sends correct request body")
    func sendsRequestBody() async throws {
        let url = URL(string: "https://mock-claude.test/body")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"content": [{"type": "text", "text": "ok"}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", model: "claude-sonnet-4-5-20241022", endpoint: url, session: session)
        _ = try await provider.process(EditingRequest(text: "hello world"))

        let captured = MockURLProtocol.capturedRequest(for: url)
        let body = captured?.httpBody ?? Data()
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        #expect(json["model"] as? String == "claude-sonnet-4-5-20241022")
        #expect(json["max_tokens"] as? Int == 2048)
        #expect(json["system"] is String)

        let messages = json["messages"] as! [[String: String]]
        #expect(messages.count == 1)
        #expect(messages[0]["role"] == "user")
        #expect(messages[0]["content"] == "hello world")
    }

    @Test("Custom model name used in request")
    func customModel() async throws {
        let url = URL(string: "https://mock-claude.test/custom-model")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"content": [{"type": "text", "text": "ok"}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", model: "claude-haiku-4-5-20251001", endpoint: url, session: session)
        _ = try await provider.process(EditingRequest(text: "hi"))

        let captured = MockURLProtocol.capturedRequest(for: url)
        let body = captured?.httpBody ?? Data()
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        #expect(json["model"] as? String == "claude-haiku-4-5-20251001")
    }

    @Test("Throws apiError on non-200 response")
    func apiError() async {
        let url = URL(string: "https://mock-claude.test/error")!
        MockURLProtocol.registerJSON(url: url, json: "Overloaded", statusCode: 529)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        await #expect(throws: AIEditingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("Throws invalidResponse when no text block")
    func invalidResponse() async {
        let url = URL(string: "https://mock-claude.test/empty-content")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"content": []}
            """)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        await #expect(throws: AIEditingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("Trims whitespace from response")
    func trimsWhitespace() async throws {
        let url = URL(string: "https://mock-claude.test/whitespace")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"content": [{"type": "text", "text": "  trimmed  \\n"}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        let result = try await provider.process(EditingRequest(text: "hello"))
        #expect(result.processedText == "trimmed")
    }

    @Test("Provider id and displayName")
    func identity() {
        let provider = ClaudeProvider(apiKey: "sk-ant-test")
        #expect(provider.id == "claude")
        #expect(provider.displayName == "Claude")
    }
}
