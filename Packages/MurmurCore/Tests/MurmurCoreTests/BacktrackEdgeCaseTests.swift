import Testing
@testable import AIEditor

@Suite("Backtrack Edge Cases")
struct BacktrackEdgeCaseTests {

    let processor = BacktrackProcessor()

    // MARK: - Triple Backtrack

    @Test("Three consecutive backtracks")
    func tripleBacktrack() {
        let result = processor.process("A, no wait B, no wait C, no wait D")
        #expect(result == "D")
    }

    // MARK: - Backtrack at Document Start

    @Test("Backtrack at very start with only trigger")
    func onlyTrigger() {
        let result = processor.process("scratch that")
        #expect(result == "")
    }

    @Test("Trigger phrase alone with trailing space")
    func triggerAloneTrailingSpace() {
        let result = processor.process("scratch that ")
        #expect(result.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Unicode Content

    @Test("Backtrack with unicode text")
    func unicodeBacktrack() {
        let result = processor.process("café latte, correction espresso")
        #expect(result == "espresso")
    }

    @Test("Backtrack with emoji")
    func emojiBacktrack() {
        let result = processor.process("🎉 party, no wait 🎊 celebration")
        #expect(result == "🎊 celebration")
    }

    // MARK: - Whitespace Edge Cases

    @Test("Backtrack with extra whitespace")
    func extraWhitespace() {
        let result = processor.process("hello world ,  scratch that  goodbye")
        #expect(result.contains("goodbye"))
    }

    @Test("Backtrack preserves sentence with period")
    func preservesPriorSentence() {
        let result = processor.process("First. Second, no wait Third")
        #expect(result == "First. Third")
    }

    // MARK: - Mixed Triggers

    @Test("Different trigger phrases in sequence")
    func mixedTriggers() {
        let result = processor.process("A, scratch that B, correction C")
        #expect(result == "C")
    }
}
