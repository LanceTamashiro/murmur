import Testing
@testable import AIEditor

@Suite("Backtrack Processor")
struct BacktrackTests {

    let processor = BacktrackProcessor()

    // MARK: - Replacement (trigger followed by new content)

    @Test("'no wait' with replacement deletes back to sentence boundary")
    func noWaitWithReplacement() {
        // No sentence boundary → delete everything before trigger, insert replacement
        let result = processor.process("I'll send it Thursday, no wait Friday")
        #expect(result == "Friday")
    }

    @Test("'scratch that' with replacement after sentence boundary")
    func scratchThatWithReplacementAfterSentence() {
        let result = processor.process("Context here. The meeting is at two, scratch that three o'clock")
        #expect(result == "Context here. three o'clock")
    }

    @Test("'I meant to say' with replacement")
    func iMeantToSayWithReplacement() {
        let result = processor.process("call John, I meant to say James about the project")
        #expect(result == "James about the project")
    }

    // MARK: - Terminal Deletion (trigger at end, no replacement)

    @Test("'scratch that' at end deletes back to sentence boundary")
    func scratchThatTerminal() {
        let result = processor.process("send the report. Delete the second page, scratch that")
        #expect(result == "send the report.")
    }

    @Test("'delete that' at end deletes everything when no sentence boundary")
    func deleteThatTerminal() {
        let result = processor.process("I want to add a note about costs, delete that")
        #expect(result == "")
    }

    @Test("'never mind' at end deletes back to sentence boundary")
    func neverMindTerminal() {
        let result = processor.process("Let's discuss the budget. Also the timeline, never mind")
        #expect(result == "Let's discuss the budget.")
    }

    // MARK: - Clause Boundary Detection

    @Test("Sentence boundary at period preserves prior sentence")
    func clauseBoundaryPeriod() {
        let result = processor.process("First point done. Second point is wrong, scratch that")
        #expect(result == "First point done.")
    }

    @Test("Sentence boundary at exclamation mark")
    func clauseBoundaryExclamation() {
        let result = processor.process("Great job! But not really, scratch that")
        #expect(result == "Great job!")
    }

    @Test("Sentence boundary at question mark")
    func clauseBoundaryQuestion() {
        let result = processor.process("Is that right? Actually no, delete that")
        #expect(result == "Is that right?")
    }

    @Test("No sentence boundary deletes everything before trigger")
    func noClauseBoundary() {
        let result = processor.process("send this to Bob no wait to Alice")
        #expect(result == "to Alice")
    }

    // MARK: - Multiple Backtracks

    @Test("Multiple backtracks in one utterance")
    func multipleBacktracks() {
        let result = processor.process("Monday, no wait Tuesday, no wait Wednesday")
        #expect(result == "Wednesday")
    }

    // MARK: - Case Insensitivity

    @Test("Case-insensitive trigger detection")
    func caseInsensitive() {
        let result = processor.process("the price is fifty, Scratch That sixty dollars")
        #expect(result == "sixty dollars")
    }

    // MARK: - Edge Cases

    @Test("Empty input")
    func emptyInput() {
        #expect(processor.process("") == "")
    }

    @Test("No trigger phrases returns text unchanged")
    func noTrigger() {
        let input = "The meeting is at three PM tomorrow."
        #expect(processor.process(input) == "The meeting is at three PM tomorrow.")
    }

    @Test("Trigger at very start of text with replacement")
    func triggerAtStart() {
        let result = processor.process("no wait actually five PM")
        #expect(result == "actually five PM")
    }

    @Test("'correction' trigger replaces clause")
    func correctionTrigger() {
        let result = processor.process("the total is a hundred, correction two hundred dollars")
        #expect(result == "two hundred dollars")
    }

    @Test("'let me rephrase' trigger with replacement")
    func letMeRephrase() {
        let result = processor.process("it's not great, let me rephrase it needs improvement")
        #expect(result == "it needs improvement")
    }

    @Test("'correction' after sentence boundary preserves prior sentence")
    func correctionAfterSentence() {
        let result = processor.process("Base price is set. The total is a hundred, correction two hundred dollars")
        #expect(result == "Base price is set. two hundred dollars")
    }

    @Test("Custom trigger phrases")
    func customTriggers() {
        let custom = BacktrackProcessor(triggerPhrases: ["oops"])
        let result = custom.process("send to Bob, oops to Alice")
        #expect(result == "to Alice")
    }
}
