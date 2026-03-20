import Foundation

// MARK: - Transcription Types

public struct TranscriptionWord: Sendable {
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Float

    public init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Float) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

public struct TranscriptionResult: Sendable {
    public let text: String
    public let words: [TranscriptionWord]
    public let isFinal: Bool
    public let confidence: Float
    public let language: String
    public let sessionID: UUID

    public init(text: String, words: [TranscriptionWord] = [], isFinal: Bool, confidence: Float = 1.0, language: String = "en-US", sessionID: UUID) {
        self.text = text
        self.words = words
        self.isFinal = isFinal
        self.confidence = confidence
        self.language = language
        self.sessionID = sessionID
    }
}

public enum TranscriptionEvent: Sendable {
    case partial(TranscriptionResult)
    case final(TranscriptionResult)
    case error(SpeechEngineError)
    case sessionStarted(sessionID: UUID)
    case sessionEnded(sessionID: UUID, duration: TimeInterval)
}

public enum VoiceActivityState: Sendable {
    case speech(amplitude: Float)
    case silence
    case uncertain
}

public enum SpeechAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public enum SpeechEngineError: Error, Sendable {
    case notAuthorized
    case authorizationDenied
    case microphoneNotAuthorized
    case engineNotAvailable
    case audioSessionFailed(underlying: any Error)
    case recognizerUnavailableForLocale(String)
    case sessionExpired
    case unknownError(underlying: any Error)
}

// MARK: - Protocol

public protocol SpeechEngineProtocol: AnyObject, Sendable {
    func requestAuthorization() async -> SpeechAuthorizationStatus
    var authorizationStatus: SpeechAuthorizationStatus { get }

    func startSession(locale: Locale?, customVocabulary: [String]) async throws -> UUID
    func stopSession() async
    func cancelSession() async

    var transcriptionEvents: AsyncStream<TranscriptionEvent> { get }
    var amplitudeStream: AsyncStream<Float> { get }
}
