import Foundation
import SwiftData

@Model
public final class DictationSession {
    @Attribute(.unique) public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var durationSeconds: Double
    public var wordCount: Int
    public var characterCount: Int
    public var rawTranscription: String
    public var finalTranscription: String
    public var language: String
    public var sourceAppBundleID: String?
    public var injectionSucceeded: Bool?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        durationSeconds: Double = 0,
        wordCount: Int = 0,
        characterCount: Int = 0,
        rawTranscription: String = "",
        finalTranscription: String = "",
        language: String = "en-US",
        sourceAppBundleID: String? = nil,
        injectionSucceeded: Bool? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.rawTranscription = rawTranscription
        self.finalTranscription = finalTranscription
        self.language = language
        self.sourceAppBundleID = sourceAppBundleID
        self.injectionSucceeded = injectionSucceeded
        self.createdAt = Date()
    }
}
