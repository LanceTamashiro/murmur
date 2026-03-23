import Foundation

/// Builds system prompts for AI editing providers based on the editing request configuration.
///
/// All providers share the same prompt structure to ensure consistent behavior.
public struct ProviderSystemPrompt: Sendable {

    public init() {}

    /// Build a system prompt for the given editing request.
    public func build(for request: EditingRequest) -> String {
        var parts: [String] = []

        parts.append(baseInstruction)

        if request.enabledStages.contains(.grammarCorrection) {
            parts.append("- Fix grammar, spelling, and punctuation errors.")
        }

        if request.enabledStages.contains(.toneAdaptation) {
            if let tone = request.toneProfile {
                parts.append("- Adjust the tone to be \(tone).")
            }
        }

        if !request.customVocabulary.isEmpty {
            let words = request.customVocabulary.joined(separator: ", ")
            parts.append("- Preserve these custom vocabulary words exactly as spelled: \(words).")
        }

        if let lang = languageName(from: request.language), lang != "English" {
            parts.append("- The text is in \(lang). Preserve the language unless a translation command is given.")
        }

        // AI-delegated commands
        for command in request.detectedCommands {
            switch command.type {
            case .makeFormal:
                parts.append("- Rewrite the text in a formal, professional tone.")
            case .makeCasual:
                parts.append("- Rewrite the text in a casual, conversational tone.")
            case .bulletList:
                parts.append("- Reformat the text as a bullet-point list.")
            case .numberedList:
                parts.append("- Reformat the text as a numbered list.")
            case .fixGrammarOnly:
                parts.append("- ONLY fix grammar errors. Do not change wording, tone, or style.")
            case .translateTo:
                if let lang = command.argument {
                    parts.append("- Translate the text to \(lang).")
                }
            case .summarize:
                parts.append("- Summarize the text concisely while preserving key information.")
            default:
                break
            }
        }

        parts.append(outputInstruction)

        return parts.joined(separator: "\n")
    }

    // MARK: - Private

    private var baseInstruction: String {
        """
        You are a text editing assistant for a voice dictation app. \
        The user has dictated text that needs to be cleaned up and polished. \
        Return ONLY the edited text with no explanations, commentary, or markdown formatting.
        """
    }

    private var outputInstruction: String {
        "- Do not add any text that wasn't in the original. Do not wrap in quotes or code blocks."
    }

    private func languageName(from code: String) -> String? {
        let locale = Locale(identifier: "en_US")
        let langCode = code.components(separatedBy: "-").first ?? code
        return locale.localizedString(forLanguageCode: langCode)
    }
}
