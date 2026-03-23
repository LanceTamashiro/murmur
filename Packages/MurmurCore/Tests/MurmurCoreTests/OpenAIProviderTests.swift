import Testing
import Foundation
@testable import AIEditor

@Suite("OpenAI Provider", .serialized)
struct OpenAIProviderTests {

    @Test("Unavailable when API key is empty")
    func unavailableWithoutKey() async {
        let provider = OpenAIProvider(apiKey: "")
        let available = await provider.isAvailable()
        #expect(!available)
    }

    @Test("Available when API key is set")
    func availableWithKey() async {
        let provider = OpenAIProvider(apiKey: "sk-test-key")
        let available = await provider.isAvailable()
        #expect(available)
    }

    @Test("Throws providerUnavailable when key is empty")
    func throwsWhenUnavailable() async {
        let provider = OpenAIProvider(apiKey: "")
        let request = EditingRequest(text: "hello")
        await #expect(throws: AIEditingError.self) {
            try await provider.process(request)
        }
    }

    @Test("Parses successful response correctly")
    func parsesResponse() async throws {
        let url = URL(string: "https://mock-openai.test/v1/chat/completions")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"choices": [{"message": {"role": "assistant", "content": "Hello, world."}}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        let result = try await provider.process(EditingRequest(text: "hello world"))
        #expect(result.processedText == "Hello, world.")
        #expect(result.providerID == "openai")
    }

    @Test("Sends correct headers")
    func sendsHeaders() async throws {
        let url = URL(string: "https://mock-openai.test/headers")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"choices": [{"message": {"role": "assistant", "content": "ok"}}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test-123", endpoint: url, session: session)
        _ = try await provider.process(EditingRequest(text: "hi"))

        let captured = MockURLProtocol.capturedRequest(for: url)
        #expect(captured?.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-123")
        #expect(captured?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("Sends correct request body")
    func sendsRequestBody() async throws {
        let url = URL(string: "https://mock-openai.test/body")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"choices": [{"message": {"role": "assistant", "content": "ok"}}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", model: "gpt-4o", endpoint: url, session: session)
        _ = try await provider.process(EditingRequest(text: "hello world"))

        let captured = MockURLProtocol.capturedRequest(for: url)
        let body = captured?.httpBody ?? Data()
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        #expect(json["model"] as? String == "gpt-4o")
        #expect(json["temperature"] as? Double == 0.3)
        #expect(json["max_tokens"] as? Int == 2048)

        let messages = json["messages"] as! [[String: String]]
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
        #expect(messages[1]["role"] == "user")
        #expect(messages[1]["content"] == "hello world")
    }

    @Test("Custom model name used in request")
    func customModel() async throws {
        let url = URL(string: "https://mock-openai.test/custom-model")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"choices": [{"message": {"role": "assistant", "content": "ok"}}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", model: "gpt-4o-mini", endpoint: url, session: session)
        _ = try await provider.process(EditingRequest(text: "hi"))

        let captured = MockURLProtocol.capturedRequest(for: url)
        let body = captured?.httpBody ?? Data()
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        #expect(json["model"] as? String == "gpt-4o-mini")
    }

    @Test("Throws apiError on non-200 response")
    func apiError() async {
        let url = URL(string: "https://mock-openai.test/error")!
        MockURLProtocol.registerJSON(url: url, json: "Rate limited", statusCode: 429)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        await #expect(throws: AIEditingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("Throws invalidResponse when no choices")
    func invalidResponse() async {
        let url = URL(string: "https://mock-openai.test/empty-choices")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"choices": []}
            """)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        await #expect(throws: AIEditingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("Trims whitespace from response")
    func trimsWhitespace() async throws {
        let url = URL(string: "https://mock-openai.test/whitespace")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"choices": [{"message": {"role": "assistant", "content": "  trimmed  \\n"}}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        let result = try await provider.process(EditingRequest(text: "hello"))
        #expect(result.processedText == "trimmed")
    }

    @Test("Provider id and displayName")
    func identity() {
        let provider = OpenAIProvider(apiKey: "sk-test")
        #expect(provider.id == "openai")
        #expect(provider.displayName == "OpenAI")
    }
}
