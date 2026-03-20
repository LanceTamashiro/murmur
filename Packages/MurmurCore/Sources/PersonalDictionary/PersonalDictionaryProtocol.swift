import Foundation
import Models

@MainActor
public protocol PersonalDictionaryProtocol: AnyObject {
    func addEntry(_ entry: DictionaryEntry) throws
    func removeEntry(id: UUID) throws
    func allEntries() throws -> [DictionaryEntry]
    func search(query: String) throws -> [DictionaryEntry]
    func vocabularyWords() throws -> [String]
}
