import Foundation

/// Executes detected text editing commands on the transcribed text.
///
/// Local commands (new line, delete, capitalize) are applied directly.
/// AI-delegated commands (translate, summarize, tone changes) are flagged
/// for the AI provider to handle.
public struct CommandExecutor: Sendable {

    public init() {}

    /// Commands that can be fully executed locally without AI.
    public static let localCommands: Set<CommandType> = [
        .newLine, .newParagraph, .deleteThat, .scratchThat,
        .capitalizeThat, .allCaps, .lowercase,
    ]

    /// Commands that require an AI provider.
    public static let aiCommands: Set<CommandType> = [
        .makeFormal, .makeCasual, .bulletList, .numberedList,
        .fixGrammarOnly, .translateTo, .summarize, .undo,
    ]

    /// Execute local commands on the text, stripping command phrases.
    /// Returns the modified text and a list of executed command types.
    ///
    /// AI-delegated commands are stripped from the text but NOT executed;
    /// they should be passed to the AI provider via `EditingRequest.detectedCommands`.
    public func execute(text: String, commands: [DetectedCommand]) -> (text: String, executed: [CommandType]) {
        guard !commands.isEmpty else { return (text, []) }

        var result = text
        var executed: [CommandType] = []

        // Process commands in reverse order (to preserve string indices)
        for command in commands.reversed() {
            // Verify the range is still valid
            guard command.range.lowerBound >= result.startIndex,
                  command.range.upperBound <= result.endIndex else {
                continue
            }

            switch command.type {
            case .newLine:
                let expanded = expandRangeOverWhitespace(in: result, range: command.range)
                result.replaceSubrange(expanded, with: "\n")
                executed.append(.newLine)

            case .newParagraph:
                let expanded = expandRangeOverWhitespace(in: result, range: command.range)
                result.replaceSubrange(expanded, with: "\n\n")
                executed.append(.newParagraph)

            case .deleteThat, .scratchThat:
                // Delete the command phrase and the preceding clause
                let beforeCommand = String(result[result.startIndex..<command.range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let afterCommand = String(result[command.range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)

                // Find clause boundary (last .!? before the command)
                let keepText = textUpToLastSentenceBoundary(in: beforeCommand)
                let separator = keepText.isEmpty && afterCommand.isEmpty ? "" :
                                keepText.isEmpty ? "" :
                                afterCommand.isEmpty ? "" : " "
                result = keepText + separator + afterCommand
                executed.append(command.type)

            case .capitalizeThat:
                let beforeCommand = result[result.startIndex..<command.range.lowerBound]
                let afterCommand = result[command.range.upperBound...]
                // Capitalize the last word before the command
                let words = beforeCommand.split(separator: " ", omittingEmptySubsequences: true)
                if let lastWord = words.last {
                    let capitalized = lastWord.prefix(1).uppercased() + lastWord.dropFirst()
                    let prefix = words.dropLast().joined(separator: " ")
                    let sep = prefix.isEmpty ? "" : " "
                    result = prefix + sep + capitalized + String(afterCommand)
                } else {
                    // No word to capitalize — just strip the command
                    result = String(beforeCommand) + String(afterCommand)
                }
                executed.append(.capitalizeThat)

            case .allCaps:
                let beforeCommand = result[result.startIndex..<command.range.lowerBound]
                let afterCommand = result[command.range.upperBound...]
                let words = beforeCommand.split(separator: " ", omittingEmptySubsequences: true)
                if let lastWord = words.last {
                    let prefix = words.dropLast().joined(separator: " ")
                    let sep = prefix.isEmpty ? "" : " "
                    result = prefix + sep + lastWord.uppercased() + String(afterCommand)
                } else {
                    result = String(beforeCommand) + String(afterCommand)
                }
                executed.append(.allCaps)

            case .lowercase:
                let beforeCommand = result[result.startIndex..<command.range.lowerBound]
                let afterCommand = result[command.range.upperBound...]
                let words = beforeCommand.split(separator: " ", omittingEmptySubsequences: true)
                if let lastWord = words.last {
                    let prefix = words.dropLast().joined(separator: " ")
                    let sep = prefix.isEmpty ? "" : " "
                    result = prefix + sep + lastWord.lowercased() + String(afterCommand)
                } else {
                    result = String(beforeCommand) + String(afterCommand)
                }
                executed.append(.lowercase)

            default:
                // AI-delegated command — strip the command phrase only
                let before = String(result[result.startIndex..<command.range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let after = String(result[command.range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                let sep = before.isEmpty || after.isEmpty ? "" : " "
                result = before + sep + after
            }
        }

        return (result.trimmingCharacters(in: .whitespaces), executed)
    }

    /// Expands a range to consume surrounding whitespace.
    private func expandRangeOverWhitespace(in text: String, range: Range<String.Index>) -> Range<String.Index> {
        var start = range.lowerBound
        while start > text.startIndex {
            let prev = text.index(before: start)
            if text[prev] == " " { start = prev } else { break }
        }
        var end = range.upperBound
        while end < text.endIndex {
            if text[end] == " " { end = text.index(after: end) } else { break }
        }
        return start..<end
    }

    /// Returns text up to and including the last sentence-ending punctuation.
    private func textUpToLastSentenceBoundary(in text: String) -> String {
        let sentenceEnders: Set<Character> = [".", "!", "?"]
        var i = text.endIndex
        while i > text.startIndex {
            let prev = text.index(before: i)
            if sentenceEnders.contains(text[prev]) {
                return String(text[text.startIndex...prev]).trimmingCharacters(in: .whitespaces)
            }
            i = prev
        }
        return ""
    }
}
