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
        let note = try store.createNote(title: "Test", bodyMarkdown: "Hello world", sourceApp: nil, language: nil)
        #expect(note.title == "Test")
        #expect(note.bodyMarkdown == "Hello world")
        #expect(note.wordCount == 2)
        #expect(note.isPinned == false)
        #expect(note.isTrashed == false)
    }

    @Test func createNoteWithSourceApp() throws {
        let note = try store.createNote(title: "From Safari", bodyMarkdown: "Dictated text", sourceApp: "com.apple.Safari", language: "en-US")
        #expect(note.sourceApp == "com.apple.Safari")
        #expect(note.language == "en-US")
    }

    // MARK: - Read

    @Test func fetchNoteByID() throws {
        let created = try store.createNote(title: "Fetch Me", bodyMarkdown: "", sourceApp: nil, language: nil)
        let fetched = try store.note(for: created.id)
        #expect(fetched?.title == "Fetch Me")
    }

    @Test func fetchNonExistentNote() throws {
        let result = try store.note(for: UUID())
        #expect(result == nil)
    }

    // MARK: - Update

    @Test func updateNoteTitle() throws {
        let note = try store.createNote(title: "Old Title", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.updateNote(note.id, title: "New Title", bodyMarkdown: nil, isPinned: nil)
        let updated = try store.note(for: note.id)
        #expect(updated?.title == "New Title")
    }

    @Test func updateNoteBody() throws {
        let note = try store.createNote(title: "Test", bodyMarkdown: "one two", sourceApp: nil, language: nil)
        try store.updateNote(note.id, title: nil, bodyMarkdown: "one two three four", isPinned: nil)
        let updated = try store.note(for: note.id)
        #expect(updated?.bodyMarkdown == "one two three four")
        #expect(updated?.wordCount == 4)
    }

    @Test func pinNote() throws {
        let note = try store.createNote(title: "Pin Me", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.updateNote(note.id, title: nil, bodyMarkdown: nil, isPinned: true)
        let updated = try store.note(for: note.id)
        #expect(updated?.isPinned == true)
    }

    // MARK: - Trash / Restore / Delete

    @Test func trashNote() throws {
        let note = try store.createNote(title: "Trash Me", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.trashNote(note.id)
        let trashed = try store.note(for: note.id)
        #expect(trashed?.isTrashed == true)
        #expect(trashed?.trashedAt != nil)
    }

    @Test func trashedNotesExcludedByDefault() throws {
        try store.createNote(title: "Visible", bodyMarkdown: "", sourceApp: nil, language: nil)
        let trashMe = try store.createNote(title: "Hidden", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.trashNote(trashMe.id)

        let notes = try store.notes(filter: .default, sortOrder: .updatedAtDescending, limit: 50, offset: 0)
        #expect(notes.count == 1)
        #expect(notes.first?.title == "Visible")
    }

    @Test func includeTrashedNotes() throws {
        try store.createNote(title: "Visible", bodyMarkdown: "", sourceApp: nil, language: nil)
        let trashMe = try store.createNote(title: "Hidden", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.trashNote(trashMe.id)

        let filter = NoteFilter(includeTrashed: true)
        let notes = try store.notes(filter: filter, sortOrder: .updatedAtDescending, limit: 50, offset: 0)
        #expect(notes.count == 2)
    }

    @Test func restoreNote() throws {
        let note = try store.createNote(title: "Restore Me", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.trashNote(note.id)
        try store.restoreNote(note.id)
        let restored = try store.note(for: note.id)
        #expect(restored?.isTrashed == false)
        #expect(restored?.trashedAt == nil)
    }

    @Test func permanentlyDeleteNote() throws {
        let note = try store.createNote(title: "Delete Me", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.deleteNote(note.id)
        let result = try store.note(for: note.id)
        #expect(result == nil)
    }

    @Test func emptyTrash() throws {
        let n1 = try store.createNote(title: "Trash 1", bodyMarkdown: "", sourceApp: nil, language: nil)
        let n2 = try store.createNote(title: "Trash 2", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.createNote(title: "Keep", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.trashNote(n1.id)
        try store.trashNote(n2.id)
        try store.emptyTrash()

        let filter = NoteFilter(includeTrashed: true)
        let count = try store.noteCount(filter: filter)
        #expect(count == 1)
    }

    // MARK: - Query & Sort

    @Test func notesSortedByTitle() throws {
        try store.createNote(title: "Banana", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.createNote(title: "Apple", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.createNote(title: "Cherry", bodyMarkdown: "", sourceApp: nil, language: nil)

        let notes = try store.notes(filter: .default, sortOrder: .titleAscending, limit: 50, offset: 0)
        #expect(notes.map(\.title) == ["Apple", "Banana", "Cherry"])
    }

    @Test func pinnedNotesFilter() throws {
        let pinned = try store.createNote(title: "Pinned", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.updateNote(pinned.id, title: nil, bodyMarkdown: nil, isPinned: true)
        try store.createNote(title: "Not Pinned", bodyMarkdown: "", sourceApp: nil, language: nil)

        let filter = NoteFilter(pinnedOnly: true)
        let notes = try store.notes(filter: filter, sortOrder: .updatedAtDescending, limit: 50, offset: 0)
        #expect(notes.count == 1)
        #expect(notes.first?.title == "Pinned")
    }

    @Test func noteCount() throws {
        try store.createNote(title: "A", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.createNote(title: "B", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.createNote(title: "C", bodyMarkdown: "", sourceApp: nil, language: nil)

        let count = try store.noteCount(filter: .default)
        #expect(count == 3)
    }

    @Test func paginationWithOffset() throws {
        for i in 1...5 {
            try store.createNote(title: "Note \(i)", bodyMarkdown: "", sourceApp: nil, language: nil)
        }

        let page = try store.notes(filter: .default, sortOrder: .titleAscending, limit: 2, offset: 2)
        #expect(page.count == 2)
        #expect(page.first?.title == "Note 3")
    }

    // MARK: - Search

    @Test func searchByTitle() throws {
        try store.createNote(title: "Meeting with Alice", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.createNote(title: "Grocery List", bodyMarkdown: "", sourceApp: nil, language: nil)

        let results = try store.search(query: "Alice", limit: 50)
        #expect(results.count == 1)
        #expect(results.first?.title == "Meeting with Alice")
    }

    @Test func searchByBody() throws {
        try store.createNote(title: "Note 1", bodyMarkdown: "The quick brown fox", sourceApp: nil, language: nil)
        try store.createNote(title: "Note 2", bodyMarkdown: "A lazy dog", sourceApp: nil, language: nil)

        let results = try store.search(query: "fox", limit: 50)
        #expect(results.count == 1)
        #expect(results.first?.title == "Note 1")
    }

    @Test func searchExcludesTrashed() throws {
        let note = try store.createNote(title: "Findable before trash", bodyMarkdown: "", sourceApp: nil, language: nil)
        try store.trashNote(note.id)

        let results = try store.search(query: "Findable", limit: 50)
        #expect(results.isEmpty)
    }
}
