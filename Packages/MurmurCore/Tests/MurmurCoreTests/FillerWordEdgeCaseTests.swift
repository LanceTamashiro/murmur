import Testing
@testable import AIEditor

@Suite("Filler Word Edge Cases")
struct FillerWordEdgeCaseTests {

    let processor = FillerWordProcessor()

    // MARK: - Word Boundary Safety

    @Test("Does not strip 'um' from 'umbilical'")
    func preservesUmbilical() {
        #expect(processor.process("umbilical cord") == "umbilical cord")
    }

    @Test("Does not strip 'um' from 'human'")
    func preservesHuman() {
        #expect(processor.process("a human being") == "a human being")
    }

    @Test("Does not strip 'uh' from 'uhlan'")
    func preservesUhlan() {
        #expect(processor.process("an uhlan rode by") == "an uhlan rode by")
    }

    @Test("Does not strip 'er' from 'erase'")
    func preservesErase() {
        #expect(processor.process("please erase that") == "please erase that")
    }

    @Test("Does not strip 'er' from 'errand'")
    func preservesErrand() {
        #expect(processor.process("run an errand") == "run an errand")
    }

    @Test("Does not strip 'er' from 'better'")
    func preservesBetter() {
        #expect(processor.process("this is better") == "this is better")
    }

    // MARK: - Consecutive Fillers

    @Test("All fillers with no real words produces empty or whitespace")
    func allFillers() {
        let result = processor.process("um uh er")
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.isEmpty)
    }

    @Test("Multiple fillers in a row")
    func multipleConsecutive() {
        let result = processor.process("um um uh hello")
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        #expect(trimmed.contains("hello"))
        #expect(!trimmed.hasPrefix("um"))
    }

    // MARK: - Punctuation Attached to Fillers

    @Test("Filler with comma before")
    func fillerWithCommaBefore() {
        let result = processor.process("I, um, think so")
        #expect(result.contains("think so"))
        #expect(!result.contains("um"))
    }

    @Test("Filler at end of sentence")
    func fillerAtEnd() {
        let result = processor.process("I think so um")
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        #expect(!trimmed.hasSuffix("um"))
    }

    @Test("Filler at start of text")
    func fillerAtStart() {
        let result = processor.process("um I think so")
        #expect(result.trimmingCharacters(in: .whitespaces).hasPrefix("I"))
    }

    // MARK: - Unicode Mixed with Fillers

    @Test("Unicode text preserved when fillers removed")
    func unicodeMixed() {
        let result = processor.process("um I want café")
        #expect(result.contains("café"))
        #expect(!result.contains("um"))
    }

    @Test("Emoji text preserved when fillers removed")
    func emojiPreserved() {
        let result = processor.process("uh I love this 🎉")
        #expect(result.contains("🎉"))
    }

    // MARK: - Whitespace Handling

    @Test("Multiple spaces between words after filler removal")
    func multipleSpacesCollapsed() {
        let result = processor.process("I um think")
        // Should not produce double spaces
        #expect(!result.contains("  ") || result.trimmingCharacters(in: .whitespaces) == "I think")
    }
}
