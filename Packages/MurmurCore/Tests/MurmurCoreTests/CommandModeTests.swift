import Testing
@testable import AIEditor

@Suite("Command Mode")
struct CommandModeTests {

    let detector = CommandDetector()
    let executor = CommandExecutor()

    // MARK: - Command Detection

    @Test("Detects 'new line' command")
    func detectNewLine() {
        let commands = detector.detect(in: "end of sentence new line next point is")
        #expect(commands.count == 1)
        #expect(commands[0].type == .newLine)
    }

    @Test("Detects 'new paragraph' command")
    func detectNewParagraph() {
        let commands = detector.detect(in: "end of section new paragraph next section")
        #expect(commands.count == 1)
        #expect(commands[0].type == .newParagraph)
    }

    @Test("Detects 'delete that' command")
    func detectDeleteThat() {
        let commands = detector.detect(in: "wrong text delete that")
        #expect(commands.count == 1)
        #expect(commands[0].type == .deleteThat)
    }

    @Test("Detects 'capitalize that' command")
    func detectCapitalizeThat() {
        let commands = detector.detect(in: "john capitalize that")
        #expect(commands.count == 1)
        #expect(commands[0].type == .capitalizeThat)
    }

    @Test("Detects 'all caps' command")
    func detectAllCaps() {
        let commands = detector.detect(in: "urgent all caps")
        #expect(commands.count == 1)
        #expect(commands[0].type == .allCaps)
    }

    @Test("Detects 'translate to' with language argument")
    func detectTranslateTo() {
        let commands = detector.detect(in: "hello world translate to French")
        #expect(commands.count == 1)
        #expect(commands[0].type == .translateTo)
        #expect(commands[0].argument == "French")
    }

    @Test("Detects 'summarize this' command")
    func detectSummarize() {
        let commands = detector.detect(in: "long text here summarize this")
        #expect(commands.count == 1)
        #expect(commands[0].type == .summarize)
    }

    @Test("Detects 'make this formal' command")
    func detectMakeFormal() {
        let commands = detector.detect(in: "hey whats up make this formal")
        #expect(commands.count == 1)
        #expect(commands[0].type == .makeFormal)
    }

    @Test("Detects multiple commands")
    func detectMultiple() {
        let commands = detector.detect(in: "hello new line world new paragraph end")
        #expect(commands.count == 2)
        #expect(commands[0].type == .newLine)
        #expect(commands[1].type == .newParagraph)
    }

    @Test("No false positive for normal text")
    func noFalsePositive() {
        let commands = detector.detect(in: "The meeting is at three PM tomorrow")
        #expect(commands.isEmpty)
    }

    @Test("Case-insensitive detection")
    func caseInsensitive() {
        let commands = detector.detect(in: "hello New Line world")
        #expect(commands.count == 1)
        #expect(commands[0].type == .newLine)
    }

    // MARK: - Command Execution

    @Test("Executes 'new line' — inserts line break")
    func executeNewLine() {
        let text = "end of sentence new line next point"
        let commands = detector.detect(in: text)
        let (result, executed) = executor.execute(text: text, commands: commands)
        #expect(result == "end of sentence\nnext point")
        #expect(executed.contains(.newLine))
    }

    @Test("Executes 'new paragraph' — inserts double line break")
    func executeNewParagraph() {
        let text = "end of section new paragraph next section"
        let commands = detector.detect(in: text)
        let (result, executed) = executor.execute(text: text, commands: commands)
        #expect(result == "end of section\n\nnext section")
        #expect(executed.contains(.newParagraph))
    }

    @Test("Executes 'capitalize that' — capitalizes preceding word")
    func executeCapitalize() {
        let text = "hello john capitalize that is here"
        let commands = detector.detect(in: text)
        let (result, _) = executor.execute(text: text, commands: commands)
        #expect(result == "hello John is here")
    }

    @Test("Executes 'all caps' — uppercases preceding word")
    func executeAllCaps() {
        let text = "mark this urgent all caps please"
        let commands = detector.detect(in: text)
        let (result, _) = executor.execute(text: text, commands: commands)
        #expect(result == "mark this URGENT please")
    }

    @Test("Executes 'lowercase' — lowercases preceding word")
    func executeLowercase() {
        let text = "the name is JOHN lowercase okay"
        let commands = detector.detect(in: text)
        let (result, _) = executor.execute(text: text, commands: commands)
        #expect(result == "the name is john okay")
    }

    @Test("Executes 'delete that' — deletes preceding clause")
    func executeDeleteThat() {
        let text = "First sentence. bad text delete that"
        let commands = detector.detect(in: text)
        let (result, _) = executor.execute(text: text, commands: commands)
        #expect(result == "First sentence.")
    }

    @Test("AI command stripped but not executed locally")
    func aiCommandStripped() {
        let text = "hello world translate to French"
        let commands = detector.detect(in: text)
        let (result, executed) = executor.execute(text: text, commands: commands)
        // Command phrase stripped, text preserved
        #expect(result == "hello world")
        // translateTo is NOT in executed (it's an AI command)
        #expect(!executed.contains(.translateTo))
    }

    @Test("Summarize command stripped from text")
    func summarizeStripped() {
        let text = "a long passage of text summarize this"
        let commands = detector.detect(in: text)
        let (result, _) = executor.execute(text: text, commands: commands)
        #expect(result == "a long passage of text")
    }

    @Test("No commands returns text unchanged")
    func noCommands() {
        let (result, executed) = executor.execute(text: "hello world", commands: [])
        #expect(result == "hello world")
        #expect(executed.isEmpty)
    }
}
