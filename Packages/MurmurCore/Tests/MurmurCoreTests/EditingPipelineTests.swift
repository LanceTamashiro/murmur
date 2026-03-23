import Testing
@testable import AIEditor

@Suite("Editing Pipeline")
struct EditingPipelineTests {

    // MARK: - Pre-processing Only (no AI provider)

    @Test("Pipeline with no provider returns pre-processed text")
    func noProvider() async {
        let pipeline = EditingPipeline()
        let request = EditingRequest(text: "um I think uh this is good")
        let result = await pipeline.process(request)
        #expect(result.processedText == "I think this is good")
        #expect(result.providerID == nil)
        #expect(result.appliedStages.contains(.fillerRemoval))
    }

    @Test("Pipeline applies backtrack before filler removal")
    func backtrackThenFiller() async {
        let pipeline = EditingPipeline()
        let request = EditingRequest(text: "send to Bob, um, no wait to Alice")
        let result = await pipeline.process(request)
        #expect(result.processedText == "to Alice")
        #expect(result.appliedStages.contains(.backtrackCorrection))
    }

    @Test("Pipeline with all stages disabled passes through")
    func allStagesDisabled() async {
        let pipeline = EditingPipeline()
        let request = EditingRequest(
            text: "um hello uh world",
            enabledStages: []
        )
        let result = await pipeline.process(request)
        #expect(result.processedText == "um hello uh world")
        #expect(result.appliedStages.isEmpty)
        #expect(!result.wasModified)
    }

    @Test("Pipeline with only filler removal enabled")
    func fillerOnlyEnabled() async {
        let pipeline = EditingPipeline()
        let request = EditingRequest(
            text: "I um think no wait yes",
            enabledStages: [.fillerRemoval]
        )
        let result = await pipeline.process(request)
        // Backtrack NOT applied (disabled), but filler removal IS applied
        #expect(result.processedText == "I think no wait yes")
        #expect(result.appliedStages == [.fillerRemoval])
        #expect(!result.appliedStages.contains(.backtrackCorrection))
    }

    // MARK: - With AI Provider

    @Test("Pipeline sends pre-processed text to AI provider")
    func withProvider() async {
        let mock = MockAIEditingProvider(transform: { $0.uppercased() })
        let pipeline = EditingPipeline(provider: mock)
        let request = EditingRequest(text: "um hello world")
        let result = await pipeline.process(request)
        // Filler removed first, then AI uppercases
        #expect(result.processedText == "HELLO WORLD")
        #expect(result.providerID == "mock")
        #expect(mock.processCount == 1)
    }

    @Test("Pipeline gracefully degrades when provider fails")
    func providerFails() async {
        let mock = MockAIEditingProvider(shouldFail: true)
        let pipeline = EditingPipeline(provider: mock)
        let request = EditingRequest(text: "um hello world")
        let result = await pipeline.process(request)
        // Falls back to pre-processed text
        #expect(result.processedText == "hello world")
        #expect(result.providerID == nil)
    }

    @Test("Pipeline skips AI when provider is unavailable")
    func providerUnavailable() async {
        let mock = MockAIEditingProvider(available: false, transform: { $0.uppercased() })
        let pipeline = EditingPipeline(provider: mock)
        let request = EditingRequest(text: "um hello world")
        let result = await pipeline.process(request)
        #expect(result.processedText == "hello world")
        #expect(mock.processCount == 0)
    }

    @Test("Pipeline skips AI when only pre-processing stages enabled")
    func onlyPreProcessingStages() async {
        let mock = MockAIEditingProvider(transform: { $0.uppercased() })
        let pipeline = EditingPipeline(provider: mock)
        let request = EditingRequest(
            text: "um hello world",
            enabledStages: [.fillerRemoval, .backtrackCorrection]
        )
        let result = await pipeline.process(request)
        // AI not called because no AI stages enabled
        #expect(result.processedText == "hello world")
        #expect(mock.processCount == 0)
    }

    @Test("Pipeline tracks processing time")
    func processingTime() async {
        let pipeline = EditingPipeline()
        let request = EditingRequest(text: "hello")
        let result = await pipeline.process(request)
        #expect(result.processingTime >= 0)
    }

    @Test("Pipeline preserves rawText in result")
    func preservesRawText() async {
        let mock = MockAIEditingProvider(transform: { $0.uppercased() })
        let pipeline = EditingPipeline(provider: mock)
        let request = EditingRequest(text: "um hello")
        let result = await pipeline.process(request)
        #expect(result.rawText == "um hello")
        #expect(result.processedText == "HELLO")
    }
}
