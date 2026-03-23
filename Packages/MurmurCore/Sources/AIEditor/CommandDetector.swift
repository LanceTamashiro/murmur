import Foundation

/// Detects text editing commands embedded in transcribed text.
///
/// Scans for command phrases ("new line", "delete that", "capitalize that", etc.)
/// and returns detected commands with their positions. Local commands are executed
/// directly; AI-delegated commands are passed to the AI provider.
public struct CommandDetector: Sendable {

    /// Command patterns: (command type, regex pattern, extracts argument?)
    private static let patterns: [(CommandType, String, Bool)] = [
        // Order matters: longer/more specific patterns first
        (.newParagraph, "\\bnew paragraph\\b", false),
        (.newLine, "\\bnew line\\b", false),
        (.scratchThat, "\\bscratch that\\b", false),
        (.deleteThat, "\\bdelete that\\b", false),
        (.undo, "\\bundo that\\b", false),
        (.undo, "\\bundo\\b", false),
        (.allCaps, "\\ball caps\\b", false),
        (.capitalizeThat, "\\bcapitalize that\\b", false),
        (.lowercase, "\\blowercase\\b", false),
        (.makeFormal, "\\bmake (?:this |it )?formal\\b", false),
        (.makeCasual, "\\bmake (?:this |it )?casual\\b", false),
        (.numberedList, "\\b(?:make (?:this |it )?a )?numbered list\\b", false),
        (.bulletList, "\\bbullet ?point (?:this|list)\\b", false),
        (.fixGrammarOnly, "\\bfix (?:the )?grammar only\\b", false),
        (.translateTo, "\\btranslate (?:this )?to (\\w+)\\b", true),
        (.summarize, "\\bsummarize (?:this)?\\b", false),
    ]

    public init() {}

    /// Detect commands in the given text.
    /// Returns detected commands sorted by position (earliest first).
    public func detect(in text: String) -> [DetectedCommand] {
        var commands: [DetectedCommand] = []

        for (type, pattern, extractsArg) in Self.patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }

            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }

                // Check if this range overlaps with an already-detected command
                let overlaps = commands.contains { existing in
                    existing.range.overlaps(range)
                }
                if overlaps { continue }

                let phrase = String(text[range])
                var argument: String? = nil

                if extractsArg, match.numberOfRanges > 1,
                   let argRange = Range(match.range(at: 1), in: text) {
                    argument = String(text[argRange])
                }

                commands.append(DetectedCommand(
                    type: type,
                    range: range,
                    phrase: phrase,
                    argument: argument
                ))
            }
        }

        // Sort by position
        return commands.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
}
