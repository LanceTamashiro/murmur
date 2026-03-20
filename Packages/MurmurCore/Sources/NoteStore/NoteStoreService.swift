import Foundation
import SwiftData
import Models

@MainActor
public final class NoteStoreService: NoteStoreProtocol {
    private let modelContext: ModelContext

    public init(modelContainer: ModelContainer) {
        self.modelContext = modelContainer.mainContext
    }

    @discardableResult
    public func createNote(bodyMarkdown: String, sourceApp: String? = nil, language: String? = nil) throws -> Note {
        let note = Note(bodyMarkdown: bodyMarkdown, sourceApp: sourceApp, language: language)
        modelContext.insert(note)
        try modelContext.save()
        return note
    }

    public func note(for id: UUID) throws -> Note? {
        let predicate = #Predicate<Note> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func updateNote(_ id: UUID, bodyMarkdown: String? = nil, isPinned: Bool? = nil) throws {
        guard let note = try note(for: id) else { return }
        if let bodyMarkdown {
            note.bodyMarkdown = bodyMarkdown
            note.updateWordCount()
        }
        if let isPinned { note.isPinned = isPinned }
        note.updatedAt = Date()
        try modelContext.save()
    }

    public func trashNote(_ id: UUID) throws {
        guard let note = try note(for: id) else { return }
        note.isTrashed = true
        note.trashedAt = Date()
        note.updatedAt = Date()
        try modelContext.save()
    }

    public func restoreNote(_ id: UUID) throws {
        guard let note = try note(for: id) else { return }
        note.isTrashed = false
        note.trashedAt = nil
        note.updatedAt = Date()
        try modelContext.save()
    }

    public func deleteNote(_ id: UUID) throws {
        guard let note = try note(for: id) else { return }
        modelContext.delete(note)
        try modelContext.save()
    }

    public func emptyTrash() throws {
        let predicate = #Predicate<Note> { $0.isTrashed == true }
        let descriptor = FetchDescriptor(predicate: predicate)
        let trashedNotes = try modelContext.fetch(descriptor)
        for note in trashedNotes {
            modelContext.delete(note)
        }
        try modelContext.save()
    }

    public func notes(filter: NoteFilter, sortOrder: NoteSortOrder, limit: Int = 50, offset: Int = 0) throws -> [Note] {
        let includeTrashed = filter.includeTrashed
        let pinnedOnly = filter.pinnedOnly

        let predicate: Predicate<Note>
        if pinnedOnly {
            predicate = #Predicate<Note> {
                (includeTrashed || $0.isTrashed == false) && $0.isPinned == true
            }
        } else {
            predicate = #Predicate<Note> {
                includeTrashed || $0.isTrashed == false
            }
        }

        var descriptor = FetchDescriptor(predicate: predicate, sortBy: sortDescriptors(for: sortOrder))
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try modelContext.fetch(descriptor)
    }

    public func noteCount(filter: NoteFilter) throws -> Int {
        let includeTrashed = filter.includeTrashed
        let predicate = #Predicate<Note> {
            includeTrashed || $0.isTrashed == false
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try modelContext.fetchCount(descriptor)
    }

    public func search(query: String, limit: Int = 50) throws -> [Note] {
        let predicate = #Predicate<Note> {
            $0.isTrashed == false &&
                $0.bodyMarkdown.localizedStandardContains(query)
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\Note.updatedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    private func sortDescriptors(for sortOrder: NoteSortOrder) -> [SortDescriptor<Note>] {
        switch sortOrder {
        case .updatedAtDescending:
            [SortDescriptor(\Note.updatedAt, order: .reverse)]
        case .updatedAtAscending:
            [SortDescriptor(\Note.updatedAt, order: .forward)]
        case .createdAtDescending:
            [SortDescriptor(\Note.createdAt, order: .reverse)]
        case .createdAtAscending:
            [SortDescriptor(\Note.createdAt, order: .forward)]
        case .titleAscending:
            [SortDescriptor(\Note.title, order: .forward)]
        case .titleDescending:
            [SortDescriptor(\Note.title, order: .reverse)]
        case .wordCountDescending:
            [SortDescriptor(\Note.wordCount, order: .reverse)]
        }
    }
}
