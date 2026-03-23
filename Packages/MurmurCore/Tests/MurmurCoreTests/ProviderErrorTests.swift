import Testing
import Foundation
@testable import AIEditor

@Suite("Provider Error Handling", .serialized)
struct ProviderErrorTests {

    // MARK: - Claude Provider Error Paths

    @Test("Claude: malformed JSON response throws DecodingError")
    func claudeMalformedJSON() async {
        let url = URL(string: "https://mock-claude.test/malformed")!
        MockURLProtocol.registerJSON(url: url, json: "not valid json {{{")

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        await #expect(throws: DecodingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("Claude: empty response body throws DecodingError")
    func claudeEmptyBody() async {
        let url = URL(string: "https://mock-claude.test/empty-body")!
        MockURLProtocol.register(url: url, data: Data(), statusCode: 200)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        await #expect(throws: DecodingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("Claude: 500 server error throws apiError")
    func claude500Error() async {
        let url = URL(string: "https://mock-claude.test/500")!
        MockURLProtocol.registerJSON(url: url, json: "Internal Server Error", statusCode: 500)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        await #expect(throws: AIEditingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("Claude: 503 service unavailable throws apiError")
    func claude503Error() async {
        let url = URL(string: "https://mock-claude.test/503")!
        MockURLProtocol.registerJSON(url: url, json: "Service Unavailable", statusCode: 503)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        await #expect(throws: AIEditingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("Claude: 429 rate limit throws apiError")
    func claude429Error() async {
        let url = URL(string: "https://mock-claude.test/429")!
        MockURLProtocol.registerJSON(url: url, json: "Rate limited", statusCode: 429)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        await #expect(throws: AIEditingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("Claude: response with empty text block")
    func claudeEmptyTextBlock() async {
        let url = URL(string: "https://mock-claude.test/empty-text")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"content": [{"type": "text", "text": ""}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = ClaudeProvider(apiKey: "sk-ant-test", endpoint: url, session: session)
        // Empty text after trimming should still return a result (empty string is valid)
        let result = try? await provider.process(EditingRequest(text: "hello"))
        // Either throws or returns empty — both are acceptable
        if let result {
            #expect(result.processedText.isEmpty)
        }
    }

    // MARK: - OpenAI Provider Error Paths

    @Test("OpenAI: malformed JSON response throws DecodingError")
    func openAIMalformedJSON() async {
        let url = URL(string: "https://mock-openai.test/malformed")!
        MockURLProtocol.registerJSON(url: url, json: "<<<invalid>>>")

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        await #expect(throws: DecodingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("OpenAI: empty response body throws DecodingError")
    func openAIEmptyBody() async {
        let url = URL(string: "https://mock-openai.test/empty-body")!
        MockURLProtocol.register(url: url, data: Data(), statusCode: 200)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        await #expect(throws: DecodingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("OpenAI: 500 server error throws")
    func openAI500Error() async {
        let url = URL(string: "https://mock-openai.test/500")!
        MockURLProtocol.registerJSON(url: url, json: "Internal Server Error", statusCode: 500)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        await #expect(throws: AIEditingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("OpenAI: 503 service unavailable throws")
    func openAI503Error() async {
        let url = URL(string: "https://mock-openai.test/503")!
        MockURLProtocol.registerJSON(url: url, json: "Service Unavailable", statusCode: 503)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        await #expect(throws: AIEditingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }

    @Test("OpenAI: response with empty content string")
    func openAIEmptyContent() async {
        let url = URL(string: "https://mock-openai.test/empty-content")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"choices": [{"message": {"role": "assistant", "content": ""}}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        let result = try? await provider.process(EditingRequest(text: "hello"))
        if let result {
            #expect(result.processedText.isEmpty)
        }
    }

    @Test("OpenAI: response with missing content field throws DecodingError")
    func openAIMissingContent() async {
        let url = URL(string: "https://mock-openai.test/missing-content")!
        MockURLProtocol.registerJSON(url: url, json: """
            {"choices": [{"message": {"role": "assistant"}}]}
            """)

        let session = MockURLProtocol.testSession()
        let provider = OpenAIProvider(apiKey: "sk-test", endpoint: url, session: session)
        await #expect(throws: DecodingError.self) {
            try await provider.process(EditingRequest(text: "hello"))
        }
    }
}
