import Testing
@testable import AIEditor

@Suite("Provider System Prompt")
struct ProviderSystemPromptTests {

    let builder = ProviderSystemPrompt()

    @Test("Base prompt includes text editing assistant role")
    func basePrompt() {
        let request = EditingRequest(text: "hello", enabledStages: [])
        let prompt = builder.build(for: request)
        #expect(prompt.contains("text editing assistant"))
        #expect(prompt.contains("Return ONLY the edited text"))
    }

    @Test("Grammar correction stage adds grammar instruction")
    func grammarStage() {
        let request = EditingRequest(text: "hello", enabledStages: [.grammarCorrection])
        let prompt = builder.build(for: request)
        #expect(prompt.contains("Fix grammar"))
    }

    @Test("Tone adaptation with profile adds tone instruction")
    func toneWithProfile() {
        let request = EditingRequest(
            text: "hello",
            enabledStages: [.toneAdaptation],
            toneProfile: "professional"
        )
        let prompt = builder.build(for: request)
        #expect(prompt.contains("professional"))
    }

    @Test("Tone adaptation without profile adds nothing extra")
    func toneWithoutProfile() {
        let request = EditingRequest(text: "hello", enabledStages: [.toneAdaptation])
        let prompt = builder.build(for: request)
        #expect(!prompt.contains("Adjust the tone"))
    }

    @Test("Custom vocabulary included in prompt")
    func customVocabulary() {
        let request = EditingRequest(
            text: "hello",
            enabledStages: [.grammarCorrection],
            customVocabulary: ["Murmur", "SwiftUI"]
        )
        let prompt = builder.build(for: request)
        #expect(prompt.contains("Murmur"))
        #expect(prompt.contains("SwiftUI"))
    }

    @Test("Non-English language noted in prompt")
    func nonEnglishLanguage() {
        let request = EditingRequest(
            text: "bonjour",
            language: "fr-FR",
            enabledStages: [.grammarCorrection]
        )
        let prompt = builder.build(for: request)
        #expect(prompt.contains("French"))
    }

    @Test("English language does not add language note")
    func englishLanguage() {
        let request = EditingRequest(
            text: "hello",
            language: "en-US",
            enabledStages: [.grammarCorrection]
        )
        let prompt = builder.build(for: request)
        #expect(!prompt.contains("The text is in"))
    }

    @Test("Translate command adds translation instruction")
    func translateCommand() {
        let cmd = DetectedCommand(
            type: .translateTo,
            range: "hello".startIndex..<"hello".endIndex,
            phrase: "translate to Spanish",
            argument: "Spanish"
        )
        let request = EditingRequest(
            text: "hello",
            enabledStages: [.commandExecution],
            detectedCommands: [cmd]
        )
        let prompt = builder.build(for: request)
        #expect(prompt.contains("Translate the text to Spanish"))
    }

    @Test("Summarize command adds summarize instruction")
    func summarizeCommand() {
        let cmd = DetectedCommand(
            type: .summarize,
            range: "hello".startIndex..<"hello".endIndex,
            phrase: "summarize this"
        )
        let request = EditingRequest(
            text: "hello",
            enabledStages: [.commandExecution],
            detectedCommands: [cmd]
        )
        let prompt = builder.build(for: request)
        #expect(prompt.contains("Summarize"))
    }

    @Test("Make formal command adds formal instruction")
    func makeFormalCommand() {
        let cmd = DetectedCommand(
            type: .makeFormal,
            range: "hello".startIndex..<"hello".endIndex,
            phrase: "make this formal"
        )
        let request = EditingRequest(
            text: "hello",
            enabledStages: [.commandExecution],
            detectedCommands: [cmd]
        )
        let prompt = builder.build(for: request)
        #expect(prompt.contains("formal"))
    }

    @Test("Bullet list command adds bullet instruction")
    func bulletListCommand() {
        let cmd = DetectedCommand(
            type: .bulletList,
            range: "hello".startIndex..<"hello".endIndex,
            phrase: "bullet point this"
        )
        let request = EditingRequest(
            text: "hello",
            enabledStages: [.commandExecution],
            detectedCommands: [cmd]
        )
        let prompt = builder.build(for: request)
        #expect(prompt.contains("bullet"))
    }

    @Test("Fix grammar only command overrides to grammar-only")
    func fixGrammarOnlyCommand() {
        let cmd = DetectedCommand(
            type: .fixGrammarOnly,
            range: "hello".startIndex..<"hello".endIndex,
            phrase: "fix the grammar only"
        )
        let request = EditingRequest(
            text: "hello",
            enabledStages: [.commandExecution],
            detectedCommands: [cmd]
        )
        let prompt = builder.build(for: request)
        #expect(prompt.contains("ONLY fix grammar"))
    }

    @Test("Multiple stages and commands combined in prompt")
    func multipleStagesAndCommands() {
        let cmd = DetectedCommand(
            type: .translateTo,
            range: "hello".startIndex..<"hello".endIndex,
            phrase: "translate to French",
            argument: "French"
        )
        let request = EditingRequest(
            text: "hello",
            enabledStages: [.grammarCorrection, .toneAdaptation, .commandExecution],
            toneProfile: "casual",
            customVocabulary: ["Murmur"],
            detectedCommands: [cmd]
        )
        let prompt = builder.build(for: request)
        #expect(prompt.contains("Fix grammar"))
        #expect(prompt.contains("casual"))
        #expect(prompt.contains("Murmur"))
        #expect(prompt.contains("French"))
    }

    @Test("Output instruction always present")
    func outputInstruction() {
        let request = EditingRequest(text: "hello", enabledStages: [])
        let prompt = builder.build(for: request)
        #expect(prompt.contains("Do not add any text"))
    }
}
