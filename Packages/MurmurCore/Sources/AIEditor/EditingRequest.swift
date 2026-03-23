import Foundation

/// A request to the AI editing pipeline.
public struct EditingRequest: Sendable {
    /// The raw transcribed text to process.
    public let text: String

    /// The detected language (e.g., "en-US").
    public let language: String

    /// Which pipeline stages are enabled for this request.
    public let enabledStages: Set<EditingStage>

    /// Optional tone/style instruction (e.g., "formal", "casual").
    public let toneProfile: String?

    /// Custom vocabulary words to preserve (from personal dictionary).
    public let customVocabulary: [String]

    /// Bundle identifier of the app where text will be injected.
    public let appBundleIdentifier: String?

    /// Commands detected by the pre-processor (passed to AI provider).
    public var detectedCommands: [DetectedCommand]

    public init(
        text: String,
        language: String = "en-US",
        enabledStages: Set<EditingStage> = Set(EditingStage.allCases),
        toneProfile: String? = nil,
        customVocabulary: [String] = [],
        appBundleIdentifier: String? = nil,
        detectedCommands: [DetectedCommand] = []
    ) {
        self.text = text
        self.language = language
        self.enabledStages = enabledStages
        self.toneProfile = toneProfile
        self.customVocabulary = customVocabulary
        self.appBundleIdentifier = appBundleIdentifier
        self.detectedCommands = detectedCommands
    }
}

/// A command detected in the transcribed text by the pre-processor.
public struct DetectedCommand: Sendable, Equatable {
    /// The type of command detected.
    public let type: CommandType

    /// The range of the command phrase in the original text.
    public let range: Range<String.Index>

    /// The raw command phrase as spoken (e.g., "translate to French").
    public let phrase: String

    /// Optional argument extracted from the command (e.g., "French" for translate).
    public let argument: String?

    public init(type: CommandType, range: Range<String.Index>, phrase: String, argument: String? = nil) {
        self.type = type
        self.range = range
        self.phrase = phrase
        self.argument = argument
    }
}

/// Types of text editing commands.
public enum CommandType: String, Sendable, CaseIterable {
    case newLine
    case newParagraph
    case deleteThat
    case scratchThat
    case undo
    case capitalizeThat
    case allCaps
    case lowercase
    case makeFormal
    case makeCasual
    case bulletList
    case numberedList
    case fixGrammarOnly
    case translateTo
    case summarize
}
