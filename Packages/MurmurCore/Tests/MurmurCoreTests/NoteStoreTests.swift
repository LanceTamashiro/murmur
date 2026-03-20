import Testing
import Foundation
import SwiftData
@testable import Models
@testable import NoteStore

@MainActor
@Suite("NoteStoreService Tests")
struct NoteStoreTests {
    let container: ModelContainer
    let store: NoteStoreService

    init() throws {
        let schema = Schema([Note.self, DictionaryEntry.self, DictationSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        store = NoteStoreService(modelContainer: container)
    }

    // MARK: - Create

    @Test func createNote() throws {
        let note = try store.createNote(bodyMarkdown: "Hello world", sourceApp: nil, language: nil)
        #expect(note.bodyMarkdown == "Hello world")
        #expect(note.title == "Hello world")
        #expect(note.wordCount == 2)
        #expect(note.isPinned == false)
        #expect(note.isTrashed == false)
    }

    @Test func createNoteWithSourceApp() throws {
        let note = try store.createNote(bodyMarkdown: "Dictated text", sourceApp: "com.apple.Safari", language: "en-US")
        #expect(note.sourceApp == "com.apple.Safari")
        #expect(note.language == "en-US")
    }

    @Test func createNoteWithEmptyBody() throws {
        let note = try store.createNote(bodyMarkdown: "", sourceApp: nil, language: nil)
        #expect(note.bodyMarkdown == "")
        #expect(note.title == "")
        #expect(note.wordCount == 0)
    }

    @Test func titleTruncatedForLongBody() throws {
        let longBody = "This is a very long transcription that definitely exceeds fifty characters in total length"
        let note = try store.createNote(bodyMarkdown: longBody, sourceApp: nil, language: nil)
        #expect(note.title.count == 50)
        #expect(note.title == String(longBody.prefix(50)))
    }

    // MARK: - Read

    @Test func fetchNoteByID() throws {
        let created = try store.createNote(bodyMarkdown: "Fetch Me", sourceApp: nil, language: nil)
        let fetched = try store.note(for: created.id)
        #expect(fetched?.bodyMarkdown == "Fetch Me")
    }

    @Test func fetchNonExistentNote() throws {
        let result = try store.note(for: UUID())
        #expect(result == nil)
    }

    // MARK: - Update

    @Test func titleAutoSyncsOnBodyUpdate() throws {
        let note = try store.createNote(bodyMarkdown: "Original body", sourceApp: nil, language: nil)
        #expect(note.title == "Original body")
        try store.updateNote(note.id, bodyMarkdown: "New body content", isPinned: nil)
        let updated = try store.note(for: note.id)
        #expect(updated?.title == "New body content")
    }

    @Test func updateNoteBody() throws {
        let note = try store.createNote(bodyMarkdown: "one two", sourceApp: nil, language: nil)
        try store.updateNote(note.id, bodyMarkdown: "one two three four", isPinned: nil)
        let updated = try store.note(for: note.id)
        #expect(updated?.bodyMarkdown == "one two three four")
        #expect(updated?.wordCount == 4)
    }

    @Test func pinNote() throws {
        let note = try store.createNote(bodyMarkdown: "Pin Me", sourceApp: nil, language: nil)
        try store.updateNote(note.id, bodyMarkdown: nil, isPinned: true)
        let updated = try store.note(for: note.id)
        #expect(updated?.isPinned == true)
    }

    // MARK: - Trash / Restore / Delete

    @Test func trashNote() throws {
        let note = try store.createNote(bodyMarkdown: "Trash Me", sourceApp: nil, language: nil)
        try store.trashNote(note.id)
        let trashed = try store.note(for: note.id)
        #expect(trashed?.isTrashed == true)
        #expect(trashed?.trashedAt != nil)
    }

    @Test func trashedNotesExcludedByDefault() throws {
        try store.createNote(bodyMarkdown: "Visible", sourceApp: nil, language: nil)
        let trashMe = try store.createNote(bodyMarkdown: "Hidden", sourceApp: nil, language: nil)
        try store.trashNote(trashMe.id)

        let notes = try store.notes(filter: .default, sortOrder: .updatedAtDescending, limit: 50, offset: 0)
        #expect(notes.count == 1)
        #expect(notes.first?.bodyMarkdown == "Visible")
    }

    @Test func includeTrashedNotes() throws {
        try store.createNote(bodyMarkdown: "Visible", sourceApp: nil, language: nil)
        let trashMe = try store.createNote(bodyMarkdown: "Hidden", sourceApp: nil, language: nil)
        try store.trashNote(trashMe.id)

        let filter = NoteFilter(includeTrashed: true)
        let notes = try store.notes(filter: filter, sortOrder: .updatedAtDescending, limit: 50, offset: 0)
        #expect(notes.count == 2)
    }

    @Test func restoreNote() throws {
        let note = try store.createNote(bodyMarkdown: "Restore Me", sourceApp: nil, language: nil)
        try store.trashNote(note.id)
        try store.restoreNote(note.id)
        let restored = try store.note(for: note.id)
        #expect(restored?.isTrashed == false)
        #expect(restored?.trashedAt == nil)
    }

    @Test func permanentlyDeleteNote() throws {
        let note = try store.createNote(bodyMarkdown: "Delete Me", sourceApp: nil, language: nil)
        try store.deleteNote(note.id)
        let result = try store.note(for: note.id)
        #expect(result == nil)
    }

    @Test func emptyTrash() throws {
        let n1 = try store.createNote(bodyMarkdown: "Trash 1", sourceApp: nil, language: nil)
        let n2 = try store.createNote(bodyMarkdown: "Trash 2", sourceApp: nil, language: nil)
        try store.createNote(bodyMarkdown: "Keep", sourceApp: nil, language: nil)
        try store.trashNote(n1.id)
        try store.trashNote(n2.id)
        try store.emptyTrash()

        let filter = NoteFilter(includeTrashed: true)
        let count = try store.noteCount(filter: filter)
        #expect(count == 1)
    }

    // MARK: - Query & Sort

    @Test func notesSortedByTitle() throws {
        try store.createNote(bodyMarkdown: "Banana", sourceApp: nil, language: nil)
        try store.createNote(bodyMarkdown: "Apple", sourceApp: nil, language: nil)
        try store.createNote(bodyMarkdown: "Cherry", sourceApp: nil, language: nil)

        let notes = try store.notes(filter: .default, sortOrder: .titleAscending, limit: 50, offset: 0)
        #expect(notes.map(\.bodyMarkdown) == ["Apple", "Banana", "Cherry"])
    }

    @Test func pinnedNotesFilter() throws {
        let pinned = try store.createNote(bodyMarkdown: "Pinned", sourceApp: nil, language: nil)
        try store.updateNote(pinned.id, bodyMarkdown: nil, isPinned: true)
        try store.createNote(bodyMarkdown: "Not Pinned", sourceApp: nil, language: nil)

        let filter = NoteFilter(pinnedOnly: true)
        let notes = try store.notes(filter: filter, sortOrder: .updatedAtDescending, limit: 50, offset: 0)
        #expect(notes.count == 1)
        #expect(notes.first?.bodyMarkdown == "Pinned")
    }

    @Test func noteCount() throws {
        try store.createNote(bodyMarkdown: "A", sourceApp: nil, language: nil)
        try store.createNote(bodyMarkdown: "B", sourceApp: nil, language: nil)
        try store.createNote(bodyMarkdown: "C", sourceApp: nil, language: nil)

        let count = try store.noteCount(filter: .default)
        #expect(count == 3)
    }

    @Test func paginationWithOffset() throws {
        for i in 1...5 {
            try store.createNote(bodyMarkdown: "Note \(i)", sourceApp: nil, language: nil)
        }

        let page = try store.notes(filter: .default, sortOrder: .titleAscending, limit: 2, offset: 2)
        #expect(page.count == 2)
        #expect(page.first?.bodyMarkdown == "Note 3")
    }

    // MARK: - Search

    @Test func searchByBody() throws {
        try store.createNote(bodyMarkdown: "The quick brown fox", sourceApp: nil, language: nil)
        try store.createNote(bodyMarkdown: "A lazy dog", sourceApp: nil, language: nil)

        let results = try store.search(query: "fox", limit: 50)
        #expect(results.count == 1)
        #expect(results.first?.bodyMarkdown == "The quick brown fox")
    }

    @Test func searchExcludesTrashed() throws {
        let note = try store.createNote(bodyMarkdown: "Findable before trash", sourceApp: nil, language: nil)
        try store.trashNote(note.id)

        let results = try store.search(query: "Findable", limit: 50)
        #expect(results.isEmpty)
    }
}
