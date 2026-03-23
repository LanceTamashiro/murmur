import Testing
import Foundation
@testable import Murmur

@Suite("KeychainService Edge Cases", .serialized)
struct KeychainEdgeCaseTests {

    let service = KeychainService(servicePrefix: "murmur.test.edge.\(UUID().uuidString.prefix(8))")

    // MARK: - Empty and Boundary Values

    @Test("Empty provider ID still works")
    func emptyProviderID() throws {
        try service.save(apiKey: "sk-test", for: "")
        let loaded = service.load(for: "")
        #expect(loaded == "sk-test")
        service.delete(for: "")
    }

    @Test("Very long provider ID works")
    func longProviderID() throws {
        let longID = String(repeating: "a", count: 500)
        try service.save(apiKey: "sk-test", for: longID)
        let loaded = service.load(for: longID)
        #expect(loaded == "sk-test")
        service.delete(for: longID)
    }

    @Test("Empty API key saves and loads")
    func emptyAPIKey() throws {
        try service.save(apiKey: "", for: "empty-key-test")
        let loaded = service.load(for: "empty-key-test")
        #expect(loaded == "")
        service.delete(for: "empty-key-test")
    }

    @Test("Very long API key works")
    func longAPIKey() throws {
        let longKey = String(repeating: "k", count: 5000)
        try service.save(apiKey: longKey, for: "long-key-test")
        let loaded = service.load(for: "long-key-test")
        #expect(loaded == longKey)
        service.delete(for: "long-key-test")
    }

    // MARK: - Special Characters

    @Test("Provider ID with special characters")
    func specialCharProviderID() throws {
        let specialID = "provider/with.special-chars_and spaces!@#"
        try service.save(apiKey: "sk-test", for: specialID)
        let loaded = service.load(for: specialID)
        #expect(loaded == "sk-test")
        service.delete(for: specialID)
    }

    @Test("API key with unicode characters")
    func unicodeAPIKey() throws {
        let unicodeKey = "sk-tëst-café-résumé-naïve"
        try service.save(apiKey: unicodeKey, for: "unicode-test")
        let loaded = service.load(for: "unicode-test")
        #expect(loaded == unicodeKey)
        service.delete(for: "unicode-test")
    }

    @Test("API key with newlines and whitespace")
    func whitespaceAPIKey() throws {
        let key = "sk-test\n\twith\r\nwhitespace"
        try service.save(apiKey: key, for: "whitespace-test")
        let loaded = service.load(for: "whitespace-test")
        #expect(loaded == key)
        service.delete(for: "whitespace-test")
    }

    // MARK: - Rapid Operations

    @Test("Rapid save-delete-save cycle")
    func rapidCycle() throws {
        let id = "rapid-cycle"
        try service.save(apiKey: "first", for: id)
        service.delete(for: id)
        try service.save(apiKey: "second", for: id)
        let loaded = service.load(for: id)
        #expect(loaded == "second")
        service.delete(for: id)
    }

    @Test("Multiple deletes of same key are safe")
    func multipleDeletes() {
        let id = "multi-delete"
        let r1 = service.delete(for: id)
        let r2 = service.delete(for: id)
        #expect(r1)
        #expect(r2)
    }
}
