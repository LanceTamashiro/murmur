import Testing
import Foundation
@testable import Murmur

@Suite("KeychainService", .serialized)
struct KeychainServiceTests {

    // Use a unique prefix per test run to avoid polluting the real keychain
    let service = KeychainService(servicePrefix: "murmur.test.apikey.\(UUID().uuidString.prefix(8))")

    @Test("Save and load API key")
    func saveAndLoad() throws {
        let providerID = "test-provider"
        try service.save(apiKey: "sk-test-123", for: providerID)
        let loaded = service.load(for: providerID)
        #expect(loaded == "sk-test-123")

        // Cleanup
        service.delete(for: providerID)
    }

    @Test("Load returns nil when no key saved")
    func loadMissing() {
        let loaded = service.load(for: "nonexistent-provider")
        #expect(loaded == nil)
    }

    @Test("Delete removes saved key")
    func deleteKey() throws {
        let providerID = "delete-test"
        try service.save(apiKey: "sk-delete-me", for: providerID)
        #expect(service.load(for: providerID) != nil)

        let deleted = service.delete(for: providerID)
        #expect(deleted)
        #expect(service.load(for: providerID) == nil)
    }

    @Test("Save overwrites existing key")
    func overwrite() throws {
        let providerID = "overwrite-test"
        try service.save(apiKey: "sk-old", for: providerID)
        try service.save(apiKey: "sk-new", for: providerID)
        let loaded = service.load(for: providerID)
        #expect(loaded == "sk-new")

        // Cleanup
        service.delete(for: providerID)
    }

    @Test("Delete nonexistent key returns true")
    func deleteNonexistent() {
        let deleted = service.delete(for: "never-saved")
        #expect(deleted)
    }

    @Test("Different providers have independent keys")
    func independentProviders() throws {
        try service.save(apiKey: "sk-openai", for: "openai")
        try service.save(apiKey: "sk-claude", for: "claude")

        #expect(service.load(for: "openai") == "sk-openai")
        #expect(service.load(for: "claude") == "sk-claude")

        service.delete(for: "openai")
        #expect(service.load(for: "openai") == nil)
        #expect(service.load(for: "claude") == "sk-claude")

        // Cleanup
        service.delete(for: "claude")
    }
}
