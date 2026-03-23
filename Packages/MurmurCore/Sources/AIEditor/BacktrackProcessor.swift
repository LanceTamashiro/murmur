import Foundation

/// Detects and resolves backtrack phrases in transcribed text.
///
/// When a user says "no wait" or "scratch that", the preceding clause is removed.
/// If corrective content follows the trigger, it replaces the deleted clause.
///
/// The pre-processor uses sentence boundaries (.!?) for clause detection. More
/// nuanced clause-level backtrack resolution is delegated to the AI provider.
public struct BacktrackProcessor: Sendable {

    /// Trigger phrases that indicate the user wants to retract the preceding clause.
    public var triggerPhrases: [String]

    public init(triggerPhrases: [String]? = nil) {
        self.triggerPhrases = triggerPhrases ?? Self.defaultTriggerPhrases
    }

    public static let defaultTriggerPhrases = [
        "no wait",
        "scratch that",
        "delete that",
        "never mind",
        "let me rephrase",
        "correction",
        "I meant to say",
    ]

    /// Process text by detecting backtrack triggers and removing/replacing preceding clauses.
    public func process(_ text: String) -> String {
        var result = text

        // Sort triggers longest-first to avoid partial matches
        let sorted = triggerPhrases.sorted { $0.count > $1.count }

        // Iterate: find and resolve backtracks until none remain
        var safetyLimit = 20
        while safetyLimit > 0 {
            safetyLimit -= 1
            guard let resolution = findAndResolve(in: result, triggers: sorted) else {
                break
            }
            result = resolution
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private

    /// Find the first backtrack trigger in the text and resolve it.
    private func findAndResolve(in text: String, triggers: [String]) -> String? {
        for trigger in triggers {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: trigger))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let matchRange = Range(match.range, in: text) else {
                continue
            }

            let beforeTrigger = String(text[text.startIndex..<matchRange.lowerBound])
            let afterTrigger = String(text[matchRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            // Strip trailing comma/semicolon and whitespace from before the trigger
            let cleanedBefore = beforeTrigger
                .replacingOccurrences(of: "\\s*[,;]\\s*$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            // Find the last sentence boundary (.!?) in the cleaned text
            let keepText = textUpToLastSentenceBoundary(in: cleanedBefore)

            if afterTrigger.isEmpty {
                return keepText
            } else {
                let separator = keepText.isEmpty ? "" : " "
                return keepText + separator + afterTrigger
            }
        }
        return nil
    }

    /// Returns the text up to and including the last sentence-ending punctuation (.!?).
    /// If no sentence boundary exists, returns empty string (the entire text is the clause).
    private func textUpToLastSentenceBoundary(in text: String) -> String {
        let sentenceEnders: Set<Character> = [".", "!", "?"]

        // Walk backward to find the last sentence-ending punctuation
        var i = text.endIndex
        while i > text.startIndex {
            let prev = text.index(before: i)
            if sentenceEnders.contains(text[prev]) {
                // Return everything up to and including this punctuation
                return String(text[text.startIndex...prev]).trimmingCharacters(in: .whitespaces)
            }
            i = prev
        }

        // No sentence boundary found — entire text is one clause, delete it all
        return ""
    }
}
