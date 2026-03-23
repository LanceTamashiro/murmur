import Testing
@testable import AIEditor

@Suite("Filler Word Processor")
struct FillerWordTests {

    let processor = FillerWordProcessor()

    // MARK: - Standalone Fillers

    @Test("Removes standalone filler 'um'")
    func removesUm() {
        #expect(processor.process("I um want to go") == "I want to go")
    }

    @Test("Removes standalone filler 'uh'")
    func removesUh() {
        #expect(processor.process("uh I think so") == "I think so")
    }

    @Test("Removes multiple standalone fillers")
    func removesMultipleFillers() {
        #expect(processor.process("um I uh think er maybe") == "I think maybe")
    }

    @Test("Removes fillers with commas")
    func removesWithCommas() {
        #expect(processor.process("I, um, want to go") == "I want to go")
    }

    @Test("Case-insensitive filler removal")
    func caseInsensitive() {
        #expect(processor.process("UM I think UH so") == "I think so")
    }

    // MARK: - Phrase Fillers

    @Test("Removes 'you know'")
    func removesYouKnow() {
        #expect(processor.process("it was, you know, really good") == "it was really good")
    }

    @Test("Removes 'I mean'")
    func removesIMean() {
        #expect(processor.process("I mean the project is done") == "the project is done")
    }

    @Test("Removes 'basically'")
    func removesBasically() {
        #expect(processor.process("it basically works fine") == "it works fine")
    }

    // MARK: - Context-Sensitive "like"

    @Test("Preserves 'like' as a verb")
    func preservesLikeAsVerb() {
        let input = "I really like this project"
        #expect(processor.process(input) == "I really like this project")
    }

    @Test("Removes 'like' as a discourse marker")
    func removesLikeAsDiscourseMarker() {
        let input = "it was, like, really good"
        #expect(processor.process(input) == "it was, really good")
    }

    // MARK: - Sentence-opening "so"

    @Test("Removes 'so' at the start of text")
    func removesSoAtStart() {
        #expect(processor.process("So I went to the store") == "I went to the store")
    }

    @Test("Removes 'so' after sentence boundary")
    func removesSoAfterSentence() {
        let result = processor.process("That's done. So the next step is clear.")
        #expect(result == "That's done. the next step is clear.")
    }

    @Test("Preserves 'so' in middle of sentence")
    func preservesSoInMiddle() {
        let input = "I was so tired"
        #expect(processor.process(input) == "I was so tired")
    }

    // MARK: - Repeated Words

    @Test("Collapses repeated word")
    func collapsesRepeatedWord() {
        #expect(processor.process("the the cat sat") == "the cat sat")
    }

    @Test("Collapses repeated word case-insensitive")
    func collapsesRepeatedWordCaseInsensitive() {
        // NSRegularExpression replaces with the first capture group, preserving original case
        let result = processor.process("The the cat")
        #expect(result == "The cat")
    }

    @Test("Does not collapse different words")
    func doesNotCollapseDifferentWords() {
        #expect(processor.process("the cat sat") == "the cat sat")
    }

    // MARK: - Edge Cases

    @Test("Empty input returns empty")
    func emptyInput() {
        #expect(processor.process("") == "")
    }

    @Test("Text with no fillers passes through")
    func noFillers() {
        let input = "The meeting is at three PM tomorrow."
        #expect(processor.process(input) == "The meeting is at three PM tomorrow.")
    }

    @Test("Custom filler list")
    func customFillerList() {
        let custom = FillerWordProcessor(
            standaloneFillers: ["blah"],
            phraseFillers: ["sort of"]
        )
        #expect(custom.process("it sort of blah works") == "it works")
    }

    @Test("Multiple fillers in sequence")
    func multipleFillerSequence() {
        let result = processor.process("um uh er I think so")
        #expect(result == "I think so")
    }
}
