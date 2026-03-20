import Foundation
import SwiftData

@Model
public final class Note {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var bodyMarkdown: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    public var isTrashed: Bool
    public var trashedAt: Date?
    public var wordCount: Int
    public var characterCount: Int
    public var sourceApp: String?
    public var language: String?

    public init(
        id: UUID = UUID(),
        title: String,
        bodyMarkdown: String = "",
        sourceApp: String? = nil,
        language: String? = nil
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.isTrashed = false
        self.trashedAt = nil
        self.wordCount = bodyMarkdown.split(separator: " ").count
        self.characterCount = bodyMarkdown.count
        self.sourceApp = sourceApp
        self.language = language
    }

    public func updateWordCount() {
        let stripped = bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        wordCount = stripped.isEmpty ? 0 : stripped.split(separator: " ").count
        characterCount = bodyMarkdown.count
    }
}
