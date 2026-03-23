#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// AI editing provider that uses Apple's on-device Foundation Models framework.
///
/// Runs inference entirely on-device using `SystemLanguageModel.default`.
/// No API key needed. Available on Apple Silicon Macs with macOS 26+.
@available(macOS 26.0, *)
public final class AppleIntelligenceProvider: AIEditingProvider, Sendable {

    public let id: String = "apple-intelligence"
    public let displayName: String = "Apple Intelligence"

    private let promptBuilder: ProviderSystemPrompt

    public init() {
        self.promptBuilder = ProviderSystemPrompt()
    }

    public func isAvailable() async -> Bool {
        SystemLanguageModel.default.isAvailable
    }

    public func process(_ request: EditingRequest) async throws -> EditingResult {
        guard SystemLanguageModel.default.isAvailable else {
            throw AIEditingError.providerUnavailable(id)
        }

        let systemPrompt = promptBuilder.build(for: request)
        let session = LanguageModelSession(
            model: .default,
            instructions: systemPrompt
        )

        let response = try await session.respond(to: request.text)
        let processedText = String(response.content).trimmingCharacters(in: .whitespacesAndNewlines)

        return EditingResult(
            processedText: processedText,
            rawText: request.text,
            appliedStages: request.enabledStages,
            executedCommands: [],
            providerID: id,
            processingTime: 0
        )
    }
}
#endif
