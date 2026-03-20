import Foundation
import SwiftData
import Models

@MainActor
public final class PersonalDictionaryService: PersonalDictionaryProtocol {
    private let modelContext: ModelContext

    public init(modelContainer: ModelContainer) {
        self.modelContext = modelContainer.mainContext
    }

    public func addEntry(_ entry: DictionaryEntry) throws {
        modelContext.insert(entry)
        try modelContext.save()
    }

    public func removeEntry(id: UUID) throws {
        let predicate = #Predicate<DictionaryEntry> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let entry = try modelContext.fetch(descriptor).first {
            modelContext.delete(entry)
            try modelContext.save()
        }
    }

    public func allEntries() throws -> [DictionaryEntry] {
        let descriptor = FetchDescriptor<DictionaryEntry>(
            sortBy: [SortDescriptor(\DictionaryEntry.canonicalForm)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func search(query: String) throws -> [DictionaryEntry] {
        let predicate = #Predicate<DictionaryEntry> {
            $0.canonicalForm.localizedStandardContains(query)
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\DictionaryEntry.canonicalForm)])
        return try modelContext.fetch(descriptor)
    }

    public func vocabularyWords() throws -> [String] {
        let entries = try allEntries()
        return entries.filter { !$0.isSuppressed }.map(\.canonicalForm)
    }
}
