import Foundation

/// The result of running text through the AI editing pipeline.
public struct EditingResult: Sendable {
    /// The processed text after all pipeline stages.
    public let processedText: String

    /// The original raw text before any processing.
    public let rawText: String

    /// Whether the text was modified by the pipeline.
    public var wasModified: Bool { processedText != rawText }

    /// Which stages were actually applied.
    public let appliedStages: Set<EditingStage>

    /// Commands that were executed.
    public let executedCommands: [CommandType]

    /// The provider that performed AI processing (nil if pre-processing only).
    public let providerID: String?

    /// Total pipeline processing time in seconds.
    public let processingTime: TimeInterval

    public init(
        processedText: String,
        rawText: String,
        appliedStages: Set<EditingStage> = [],
        executedCommands: [CommandType] = [],
        providerID: String? = nil,
        processingTime: TimeInterval = 0
    ) {
        self.processedText = processedText
        self.rawText = rawText
        self.appliedStages = appliedStages
        self.executedCommands = executedCommands
        self.providerID = providerID
        self.processingTime = processingTime
    }

    /// Create a passthrough result (no modifications).
    public static func passthrough(_ text: String) -> EditingResult {
        EditingResult(processedText: text, rawText: text)
    }
}
