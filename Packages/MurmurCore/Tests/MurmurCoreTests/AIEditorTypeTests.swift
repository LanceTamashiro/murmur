import Foundation
import Testing
@testable import AIEditor

@Suite("AIEditor Types")
struct AIEditorTypeTests {

    // MARK: - EditingStage

    @Test("EditingStage has all expected cases")
    func editingStageAllCases() {
        let cases = EditingStage.allCases
        #expect(cases.count == 6)
        #expect(cases.contains(.fillerRemoval))
        #expect(cases.contains(.backtrackCorrection))
        #expect(cases.contains(.grammarCorrection))
        #expect(cases.contains(.toneAdaptation))
        #expect(cases.contains(.commandExecution))
        #expect(cases.contains(.snippetExpansion))
    }

    @Test("EditingStage is Codable")
    func editingStageCodable() throws {
        let stage = EditingStage.fillerRemoval
        let data = try JSONEncoder().encode(stage)
        let decoded = try JSONDecoder().decode(EditingStage.self, from: data)
        #expect(decoded == stage)
    }

    // MARK: - EditingRequest

    @Test("EditingRequest defaults")
    func editingRequestDefaults() {
        let request = EditingRequest(text: "Hello world")
        #expect(request.text == "Hello world")
        #expect(request.language == "en-US")
        #expect(request.enabledStages == Set(EditingStage.allCases))
        #expect(request.toneProfile == nil)
        #expect(request.customVocabulary.isEmpty)
        #expect(request.appBundleIdentifier == nil)
        #expect(request.detectedCommands.isEmpty)
    }

    @Test("EditingRequest with custom parameters")
    func editingRequestCustom() {
        let request = EditingRequest(
            text: "Test",
            language: "fr-FR",
            enabledStages: [.grammarCorrection, .toneAdaptation],
            toneProfile: "formal",
            customVocabulary: ["Murmur", "SwiftUI"],
            appBundleIdentifier: "com.apple.mail"
        )
        #expect(request.language == "fr-FR")
        #expect(request.enabledStages.count == 2)
        #expect(request.toneProfile == "formal")
        #expect(request.customVocabulary == ["Murmur", "SwiftUI"])
        #expect(request.appBundleIdentifier == "com.apple.mail")
    }

    // MARK: - EditingResult

    @Test("EditingResult wasModified when text changes")
    func editingResultWasModified() {
        let modified = EditingResult(processedText: "Fixed text", rawText: "fixd text")
        #expect(modified.wasModified)

        let unchanged = EditingResult(processedText: "Same", rawText: "Same")
        #expect(!unchanged.wasModified)
    }

    @Test("EditingResult passthrough creates unmodified result")
    func editingResultPassthrough() {
        let result = EditingResult.passthrough("Hello")
        #expect(result.processedText == "Hello")
        #expect(result.rawText == "Hello")
        #expect(!result.wasModified)
        #expect(result.appliedStages.isEmpty)
        #expect(result.executedCommands.isEmpty)
        #expect(result.providerID == nil)
    }

    // MARK: - CommandType

    @Test("CommandType has all expected cases")
    func commandTypeAllCases() {
        let cases = CommandType.allCases
        #expect(cases.count == 15)
        #expect(cases.contains(.newLine))
        #expect(cases.contains(.deleteThat))
        #expect(cases.contains(.translateTo))
        #expect(cases.contains(.summarize))
    }

    // MARK: - MockAIEditingProvider

    @Test("MockAIEditingProvider returns transformed text")
    func mockProviderTransform() async throws {
        let provider = MockAIEditingProvider(
            transform: { $0.uppercased() }
        )
        let request = EditingRequest(text: "hello world")
        let result = try await provider.process(request)
        #expect(result.processedText == "HELLO WORLD")
        #expect(result.rawText == "hello world")
        #expect(result.providerID == "mock")
        #expect(provider.processCount == 1)
    }

    @Test("MockAIEditingProvider availability")
    func mockProviderAvailability() async {
        let provider = MockAIEditingProvider(available: false)
        #expect(await !provider.isAvailable())
        provider.setAvailable(true)
        #expect(await provider.isAvailable())
    }

    @Test("MockAIEditingProvider failure mode")
    func mockProviderFailure() async {
        let provider = MockAIEditingProvider(shouldFail: true)
        let request = EditingRequest(text: "test")
        await #expect(throws: AIEditingError.self) {
            try await provider.process(request)
        }
    }

    @Test("MockAIEditingProvider tracks process count")
    func mockProviderProcessCount() async throws {
        let provider = MockAIEditingProvider()
        let request = EditingRequest(text: "test")
        #expect(provider.processCount == 0)
        _ = try await provider.process(request)
        _ = try await provider.process(request)
        #expect(provider.processCount == 2)
    }
}
