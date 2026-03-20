import Testing
import Foundation
import SwiftData
@testable import Models
@testable import PersonalDictionary

@MainActor
@Suite("PersonalDictionaryService Tests")
struct PersonalDictionaryTests {
    let container: ModelContainer
    let service: PersonalDictionaryService

    init() throws {
        let schema = Schema([Note.self, DictionaryEntry.self, DictationSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        service = PersonalDictionaryService(modelContainer: container)
    }

    @Test func addEntry() throws {
        let entry = DictionaryEntry(canonicalForm: "Unconventional", phoneticForm: "un-con-ven-shun-al")
        try service.addEntry(entry)
        let entries = try service.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.canonicalForm == "Unconventional")
    }

    @Test func removeEntry() throws {
        let entry = DictionaryEntry(canonicalForm: "TestWord")
        try service.addEntry(entry)
        try service.removeEntry(id: entry.id)
        let entries = try service.allEntries()
        #expect(entries.isEmpty)
    }

    @Test func searchEntries() throws {
        try service.addEntry(DictionaryEntry(canonicalForm: "Psychotherapy"))
        try service.addEntry(DictionaryEntry(canonicalForm: "Psychology"))
        try service.addEntry(DictionaryEntry(canonicalForm: "Unrelated"))

        let results = try service.search(query: "Psych")
        #expect(results.count == 2)
    }

    @Test func vocabularyWordsExcludesSuppressed() throws {
        try service.addEntry(DictionaryEntry(canonicalForm: "Included"))
        try service.addEntry(DictionaryEntry(canonicalForm: "Suppressed", isSuppressed: true))

        let words = try service.vocabularyWords()
        #expect(words == ["Included"])
    }

    @Test func entriesSortedAlphabetically() throws {
        try service.addEntry(DictionaryEntry(canonicalForm: "Zebra"))
        try service.addEntry(DictionaryEntry(canonicalForm: "Apple"))
        try service.addEntry(DictionaryEntry(canonicalForm: "Mango"))

        let entries = try service.allEntries()
        #expect(entries.map(\.canonicalForm) == ["Apple", "Mango", "Zebra"])
    }
}
