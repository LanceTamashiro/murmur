import Foundation

/// Orchestrates the full AI editing pipeline: pre-processing → AI provider → result.
///
/// The pipeline runs stages in order: backtrack correction → filler removal →
/// AI provider (grammar, tone, commands) → final result. Each stage can be
/// individually disabled via `enabledStages`. If the AI provider is unavailable
/// or fails, pre-processed text is returned (graceful degradation).
public final class EditingPipeline: Sendable {

    private let provider: (any AIEditingProvider)?
    private let fillerProcessor: FillerWordProcessor
    private let backtrackProcessor: BacktrackProcessor
    private let commandDetector: CommandDetector
    private let commandExecutor: CommandExecutor

    public init(
        provider: (any AIEditingProvider)? = nil,
        fillerProcessor: FillerWordProcessor = FillerWordProcessor(),
        backtrackProcessor: BacktrackProcessor = BacktrackProcessor(),
        commandDetector: CommandDetector = CommandDetector(),
        commandExecutor: CommandExecutor = CommandExecutor()
    ) {
        self.provider = provider
        self.fillerProcessor = fillerProcessor
        self.backtrackProcessor = backtrackProcessor
        self.commandDetector = commandDetector
        self.commandExecutor = commandExecutor
    }

    /// Process text through the editing pipeline.
    ///
    /// - Parameter request: The editing request with text, language, enabled stages, etc.
    /// - Returns: The editing result with processed text and metadata.
    public func process(_ request: EditingRequest) async -> EditingResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let rawText = request.text
        var processedText = rawText
        var appliedStages: Set<EditingStage> = []

        // Stage 1: Backtrack correction (pre-processing, no AI needed)
        if request.enabledStages.contains(.backtrackCorrection) {
            let backtracked = backtrackProcessor.process(processedText)
            if backtracked != processedText {
                processedText = backtracked
                appliedStages.insert(.backtrackCorrection)
            }
        }

        // Stage 2: Filler word removal (pre-processing, no AI needed)
        if request.enabledStages.contains(.fillerRemoval) {
            let defillered = fillerProcessor.process(processedText)
            if defillered != processedText {
                processedText = defillered
                appliedStages.insert(.fillerRemoval)
            }
        }

        // Stage 3: Command detection and local execution
        var detectedCommands: [DetectedCommand] = []
        var executedCommands: [CommandType] = []

        if request.enabledStages.contains(.commandExecution) {
            detectedCommands = commandDetector.detect(in: processedText)
            if !detectedCommands.isEmpty {
                let (commandResult, executed) = commandExecutor.execute(
                    text: processedText, commands: detectedCommands
                )
                processedText = commandResult
                executedCommands = executed
                appliedStages.insert(.commandExecution)
            }
        }

        // Stage 4: AI provider (grammar, tone, AI-delegated commands)
        // Only runs if at least one AI-dependent stage is enabled
        let aiStages: Set<EditingStage> = [.grammarCorrection, .toneAdaptation, .commandExecution]
        let requestedAIStages = request.enabledStages.intersection(aiStages)

        var providerID: String? = nil

        // Collect AI-delegated commands (commands that were detected but not locally executed)
        let aiDelegatedCommands = detectedCommands.filter { cmd in
            CommandExecutor.aiCommands.contains(cmd.type)
        }

        if !requestedAIStages.isEmpty, let provider {
            // Build a modified request with pre-processed text and detected AI commands
            let aiRequest = EditingRequest(
                text: processedText,
                language: request.language,
                enabledStages: requestedAIStages,
                toneProfile: request.toneProfile,
                customVocabulary: request.customVocabulary,
                appBundleIdentifier: request.appBundleIdentifier,
                detectedCommands: aiDelegatedCommands
            )

            do {
                if await provider.isAvailable() {
                    let aiResult = try await provider.process(aiRequest)
                    processedText = aiResult.processedText
                    appliedStages.formUnion(aiResult.appliedStages)
                    executedCommands.append(contentsOf: aiResult.executedCommands)
                    providerID = aiResult.providerID
                }
            } catch {
                // AI provider failed — graceful degradation, use pre-processed text
                // The caller gets the pre-processed text without AI enhancements
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        return EditingResult(
            processedText: processedText,
            rawText: rawText,
            appliedStages: appliedStages,
            executedCommands: executedCommands,
            providerID: providerID,
            processingTime: elapsed
        )
    }
}
