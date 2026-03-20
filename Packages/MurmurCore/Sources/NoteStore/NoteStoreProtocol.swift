import Foundation
import Models

@MainActor
public protocol NoteStoreProtocol: AnyObject {
    @discardableResult
    func createNote(bodyMarkdown: String, sourceApp: String?, language: String?) throws -> Note
    func note(for id: UUID) throws -> Note?
    func updateNote(_ id: UUID, bodyMarkdown: String?, isPinned: Bool?) throws
    func trashNote(_ id: UUID) throws
    func restoreNote(_ id: UUID) throws
    func deleteNote(_ id: UUID) throws
    func emptyTrash() throws

    func notes(filter: NoteFilter, sortOrder: NoteSortOrder, limit: Int, offset: Int) throws -> [Note]
    func noteCount(filter: NoteFilter) throws -> Int
    func search(query: String, limit: Int) throws -> [Note]
}
