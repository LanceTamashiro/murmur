import Foundation
import SwiftData

@Model
public final class DictionaryEntry {
    @Attribute(.unique) public var id: UUID
    public var canonicalForm: String
    public var phoneticForm: String?
    public var alternativeForms: [String]
    public var isSuppressed: Bool
    public var language: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        canonicalForm: String,
        phoneticForm: String? = nil,
        alternativeForms: [String] = [],
        isSuppressed: Bool = false,
        language: String? = nil
    ) {
        self.id = id
        self.canonicalForm = canonicalForm
        self.phoneticForm = phoneticForm
        self.alternativeForms = alternativeForms
        self.isSuppressed = isSuppressed
        self.language = language
        self.createdAt = Date()
    }
}
