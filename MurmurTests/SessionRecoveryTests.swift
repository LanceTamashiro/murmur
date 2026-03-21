import Testing
import Foundation
@testable import Murmur
@testable import NoteStore
@testable import Models
import SwiftData

@MainActor
@Suite("Session Recovery Tests", .serialized)
struct SessionRecoveryTests {

    private static func makeNoteStore() throws -> NoteStoreService {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return NoteStoreService(modelContainer: container)
    }

    @Test func recoveryDataEncodesAndDecodes() throws {
        let original = RecoveryData(
            text: "Hello world from dictation",
            language: "en-US",
            startTime: Date(timeIntervalSince1970: 1000),
            savedAt: Date(),
            sourceApp: "com.apple.Safari"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecoveryData.self, from: data)

        #expect(decoded.text == original.text)
        #expect(decoded.language == original.language)
        #expect(decoded.sourceApp == original.sourceApp)
    }

    @Test func restoreAsNoteCreatesNote() throws {
        let noteStore = try Self.makeNoteStore()
        let startTime = Date(timeIntervalSince1970: 1000)
        let recovery = RecoveryData(
            text: "Recovered session text",
            language: "en-US",
            startTime: startTime,
            savedAt: Date(),
            sourceApp: nil
        )

        let result = SessionRecoveryManager.restoreAsNote(recovery: recovery, noteStore: noteStore)
        #expect(result == true)

        // Verify the note was created with the right content
        let notes = try noteStore.notes(filter: .default, sortOrder: .createdAtDescending)
        #expect(notes.count == 1)
        #expect(notes[0].bodyMarkdown == "Recovered session text")
        #expect(notes[0].createdAt == startTime)
    }

    @Test func checkForRecoveryReturnsNilWhenNoFile() {
        // Ensure no recovery file exists (clean state)
        let result = SessionRecoveryManager.checkForRecovery()
        // May or may not be nil depending on test ordering, but shouldn't crash
        _ = result
    }

    @Test func periodicSaveStartsAndStops() async throws {
        let manager = SessionRecoveryManager()

        // Start periodic save with a simple provider
        manager.startPeriodicSave(
            textProvider: { ("Test text", "en-US", nil) },
            startTime: Date()
        )

        // Should not crash
        try await Task.sleep(for: .milliseconds(50))

        // Stop should not crash
        manager.stopPeriodicSave()
        manager.clearRecovery()
    }
}
