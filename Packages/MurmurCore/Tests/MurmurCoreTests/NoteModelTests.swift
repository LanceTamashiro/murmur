import Testing
import Foundation
@testable import Models

@Test func noteInitialization() {
    let note = Note(title: "Test Note", bodyMarkdown: "Hello world")
    #expect(note.title == "Test Note")
    #expect(note.bodyMarkdown == "Hello world")
    #expect(note.isPinned == false)
    #expect(note.isTrashed == false)
    #expect(note.wordCount == 2)
    #expect(note.characterCount == 11)
}

@Test func noteWordCountUpdate() {
    let note = Note(title: "Test", bodyMarkdown: "one two three")
    note.bodyMarkdown = "just one"
    note.updateWordCount()
    #expect(note.wordCount == 2)
    #expect(note.characterCount == 8)
}
