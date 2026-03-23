import Testing
@testable import AIEditor

@Suite("Fallback Chain")
struct FallbackChainTests {

    @Test("Uses first available provider")
    func firstProvider() async throws {
        let primary = MockAIEditingProvider(id: "primary", transform: { $0 + " [primary]" })
        let secondary = MockAIEditingProvider(id: "secondary", transform: { $0 + " [secondary]" })
        let chain = FallbackChain(providers: [primary, secondary])

        let request = EditingRequest(text: "hello")
        let result = try await chain.process(request)
        #expect(result.processedText == "hello [primary]")
        #expect(result.providerID == "primary")
        #expect(primary.processCount == 1)
        #expect(secondary.processCount == 0)
    }

    @Test("Falls back to secondary when primary fails")
    func fallbackOnFailure() async throws {
        let primary = MockAIEditingProvider(id: "primary", shouldFail: true)
        let secondary = MockAIEditingProvider(id: "secondary", transform: { $0 + " [secondary]" })
        let chain = FallbackChain(providers: [primary, secondary])

        let request = EditingRequest(text: "hello")
        let result = try await chain.process(request)
        #expect(result.processedText == "hello [secondary]")
        #expect(result.providerID == "secondary")
    }

    @Test("Falls back to secondary when primary unavailable")
    func fallbackOnUnavailable() async throws {
        let primary = MockAIEditingProvider(id: "primary", available: false)
        let secondary = MockAIEditingProvider(id: "secondary", transform: { $0 + " [secondary]" })
        let chain = FallbackChain(providers: [primary, secondary])

        let request = EditingRequest(text: "hello")
        let result = try await chain.process(request)
        #expect(result.processedText == "hello [secondary]")
    }

    @Test("Throws when all providers fail")
    func allFail() async {
        let primary = MockAIEditingProvider(id: "primary", shouldFail: true)
        let secondary = MockAIEditingProvider(id: "secondary", shouldFail: true)
        let chain = FallbackChain(providers: [primary, secondary])

        let request = EditingRequest(text: "hello")
        await #expect(throws: AIEditingError.self) {
            try await chain.process(request)
        }
    }

    @Test("Throws when all providers unavailable")
    func allUnavailable() async {
        let primary = MockAIEditingProvider(id: "primary", available: false)
        let secondary = MockAIEditingProvider(id: "secondary", available: false)
        let chain = FallbackChain(providers: [primary, secondary])

        let request = EditingRequest(text: "hello")
        await #expect(throws: AIEditingError.self) {
            try await chain.process(request)
        }
    }

    @Test("isAvailable returns true when at least one provider available")
    func isAvailable() async {
        let unavailable = MockAIEditingProvider(id: "a", available: false)
        let available = MockAIEditingProvider(id: "b", available: true)
        let chain = FallbackChain(providers: [unavailable, available])
        #expect(await chain.isAvailable())
    }

    @Test("isAvailable returns false when no providers available")
    func isNotAvailable() async {
        let a = MockAIEditingProvider(id: "a", available: false)
        let b = MockAIEditingProvider(id: "b", available: false)
        let chain = FallbackChain(providers: [a, b])
        #expect(await !chain.isAvailable())
    }

    @Test("Circuit breaker skips provider after threshold failures")
    func circuitBreaker() async throws {
        let flaky = MockAIEditingProvider(id: "flaky", shouldFail: true)
        let backup = MockAIEditingProvider(id: "backup", transform: { $0 + " [backup]" })

        // Low threshold for testing
        let chain = FallbackChain(
            providers: [flaky, backup],
            failureThreshold: 3,
            failureWindow: 60,
            cooldownDuration: 5
        )

        let request = EditingRequest(text: "hello")

        // First 3 calls: flaky fails, backup handles it (flaky tried each time)
        for _ in 0..<3 {
            let result = try await chain.process(request)
            #expect(result.providerID == "backup")
        }

        // After 3 failures, flaky should be in cooldown — backup handles directly
        // (flaky should NOT be tried, so backup.processCount should increment but
        // flaky.processCount should stay at 3)
        let flakyCountBefore = flaky.processCount
        let result = try await chain.process(request)
        #expect(result.providerID == "backup")
        #expect(flaky.processCount == flakyCountBefore) // Not tried (in cooldown)
    }

    @Test("Circuit breaker resets after successful call")
    func circuitBreakerReset() async throws {
        let provider = MockAIEditingProvider(id: "p", shouldFail: true)
        let backup = MockAIEditingProvider(id: "backup")
        let chain = FallbackChain(
            providers: [provider, backup],
            failureThreshold: 3,
            failureWindow: 60,
            cooldownDuration: 5
        )

        let request = EditingRequest(text: "hello")

        // Cause 2 failures (below threshold)
        _ = try await chain.process(request)
        _ = try await chain.process(request)

        // Now make it succeed
        provider.setShouldFail(false)
        let result = try await chain.process(request)
        #expect(result.providerID == "p")

        // Make it fail again — counter should have reset, so 2 more failures
        // should NOT trigger cooldown
        provider.setShouldFail(true)
        _ = try await chain.process(request)
        _ = try await chain.process(request)
        // Should still try provider (not in cooldown)
        #expect(provider.processCount == 5) // 2 fail + 1 success + 2 fail = 5
    }
}
