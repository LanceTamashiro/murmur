import Foundation

/// Removes filler words and repeated words from transcribed text.
///
/// Runs as a pre-processing stage before the AI provider, reducing token cost
/// and improving output quality. Context-sensitive: preserves legitimate uses
/// of words like "like" ("I really like this") while removing discourse markers
/// ("it was, like, really good").
public struct FillerWordProcessor: Sendable {

    /// The list of standalone filler words to remove.
    public var standaloneFillers: [String]

    /// The list of phrase fillers to remove.
    public var phraseFillers: [String]

    public init(
        standaloneFillers: [String]? = nil,
        phraseFillers: [String]? = nil
    ) {
        self.standaloneFillers = standaloneFillers ?? Self.defaultStandaloneFillers
        self.phraseFillers = phraseFillers ?? Self.defaultPhraseFillers
    }

    public static let defaultStandaloneFillers = [
        "um", "uh", "er", "ah", "hmm", "mm", "mhm",
    ]

    public static let defaultPhraseFillers = [
        "you know", "I mean", "basically", "literally",
        "right", "anyway", "actually",
    ]

    /// Process text by removing filler words, phrase fillers, and repeated words.
    public func process(_ text: String) -> String {
        var result = text

        // 1. Remove phrase fillers (longer phrases first to avoid partial matches)
        result = removePhraseFillers(result)

        // 2. Remove "like" as a discourse marker (context-sensitive)
        result = removeDiscourseMarkerLike(result)

        // 3. Remove "so" as a sentence-opening filler
        result = removeSentenceOpeningSo(result)

        // 4. Remove standalone fillers
        result = removeStandaloneFillers(result)

        // 5. Collapse repeated words ("the the" → "the")
        result = collapseRepeatedWords(result)

        // 6. Clean up spacing and punctuation artifacts
        result = cleanupSpacing(result)

        return result
    }

    // MARK: - Private

    private func removePhraseFillers(_ text: String) -> String {
        var result = text
        for phrase in phraseFillers.sorted(by: { $0.count > $1.count }) {
            // Match phrase fillers surrounded by word boundaries, with optional
            // surrounding commas. Case-insensitive.
            let pattern = ",?\\s*\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b\\s*,?"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: " "
                )
            }
        }
        return result
    }

    /// Remove "like" when used as a discourse marker (filler), but preserve it
    /// as a verb ("I like this") or preposition ("like a boss").
    ///
    /// Heuristic: "like" preceded by a comma or at the start of a clause,
    /// followed by a comma, is likely a discourse marker.
    private func removeDiscourseMarkerLike(_ text: String) -> String {
        // Pattern: comma + like + comma (discourse marker position)
        let pattern = ",\\s*\\blike\\b\\s*,"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ","
        )
    }

    /// Remove "so" when it appears at the start of a sentence as a filler.
    private func removeSentenceOpeningSo(_ text: String) -> String {
        // "So" at the start of text or after sentence-ending punctuation
        let pattern = "(?:^|(?<=[.!?]))\\s*\\bso\\b\\s*,?\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        // Replace but preserve the sentence boundary
        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let prefix = result[result.startIndex..<range.lowerBound]
            let replacement = prefix.isEmpty ? "" : " "
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    private func removeStandaloneFillers(_ text: String) -> String {
        var result = text
        for filler in standaloneFillers {
            // Match standalone fillers at word boundaries, with optional commas
            let pattern = ",?\\s*\\b\(NSRegularExpression.escapedPattern(for: filler))\\b\\s*,?"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: " "
                )
            }
        }
        return result
    }

    /// Collapse repeated consecutive words ("the the" → "the").
    private func collapseRepeatedWords(_ text: String) -> String {
        let pattern = "\\b(\\w+)\\b\\s+\\b\\1\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "$1"
        )
    }

    /// Clean up multiple spaces and space-before-punctuation artifacts.
    private func cleanupSpacing(_ text: String) -> String {
        var result = text

        // Collapse multiple spaces
        if let multiSpace = try? NSRegularExpression(pattern: "\\s{2,}") {
            result = multiSpace.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }

        // Remove space before punctuation
        if let spacePunct = try? NSRegularExpression(pattern: "\\s+([,.!?;:])") {
            result = spacePunct.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Ensure space after punctuation (except end of string)
        if let punctNoSpace = try? NSRegularExpression(pattern: "([,.!?;:])(?=[A-Za-z])") {
            result = punctNoSpace.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1 "
            )
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}
