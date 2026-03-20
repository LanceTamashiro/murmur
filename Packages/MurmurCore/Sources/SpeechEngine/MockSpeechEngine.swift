import Foundation

public final class MockSpeechEngine: SpeechEngineProtocol, @unchecked Sendable {
    private var _authorizationStatus: SpeechAuthorizationStatus = .notDetermined
    private var currentSessionID: UUID?
    private var eventContinuation: AsyncStream<TranscriptionEvent>.Continuation?
    private var amplitudeContinuation: AsyncStream<Float>.Continuation?

    private let _transcriptionEvents: AsyncStream<TranscriptionEvent>
    private let _amplitudeStream: AsyncStream<Float>

    public var authorizationStatus: SpeechAuthorizationStatus { _authorizationStatus }
    public var transcriptionEvents: AsyncStream<TranscriptionEvent> { _transcriptionEvents }
    public var amplitudeStream: AsyncStream<Float> { _amplitudeStream }

    public var mockAuthorizationResult: SpeechAuthorizationStatus = .authorized
    public var mockTranscriptionText: String = "Hello, this is a test transcription."
    public var mockMicrophonePermissionGranted: Bool = true
    public var startSessionCallCount: Int = 0
    public var stopSessionCallCount: Int = 0
    public var cancelSessionCallCount: Int = 0
    public var lastLocale: Locale?
    public var lastCustomVocabulary: [String]?

    public init() {
        var eventCont: AsyncStream<TranscriptionEvent>.Continuation?
        _transcriptionEvents = AsyncStream { eventCont = $0 }
        eventContinuation = eventCont

        var ampCont: AsyncStream<Float>.Continuation?
        _amplitudeStream = AsyncStream { ampCont = $0 }
        amplitudeContinuation = ampCont
    }

    public func requestAuthorization() async -> SpeechAuthorizationStatus {
        _authorizationStatus = mockAuthorizationResult
        return _authorizationStatus
    }

    public func startSession(locale: Locale?, customVocabulary: [String]) async throws -> UUID {
        startSessionCallCount += 1
        lastLocale = locale
        lastCustomVocabulary = customVocabulary

        guard _authorizationStatus == .authorized else {
            throw SpeechEngineError.notAuthorized
        }
        guard mockMicrophonePermissionGranted else {
            throw SpeechEngineError.microphoneNotAuthorized
        }
        let sessionID = UUID()
        currentSessionID = sessionID
        eventContinuation?.yield(.sessionStarted(sessionID: sessionID))
        return sessionID
    }

    public func stopSession() async {
        stopSessionCallCount += 1
        guard let sessionID = currentSessionID else { return }
        let result = TranscriptionResult(
            text: mockTranscriptionText,
            isFinal: true,
            sessionID: sessionID
        )
        eventContinuation?.yield(.final(result))
        eventContinuation?.yield(.sessionEnded(sessionID: sessionID, duration: 5.0))
        currentSessionID = nil
    }

    public func cancelSession() async {
        cancelSessionCallCount += 1
        guard let sessionID = currentSessionID else { return }
        eventContinuation?.yield(.sessionEnded(sessionID: sessionID, duration: 0))
        currentSessionID = nil
    }

    // Test helpers

    public func simulatePartialResult(_ text: String) {
        guard let sessionID = currentSessionID else { return }
        let result = TranscriptionResult(text: text, isFinal: false, sessionID: sessionID)
        eventContinuation?.yield(.partial(result))
    }

    public func simulateAmplitude(_ value: Float) {
        amplitudeContinuation?.yield(value)
    }
}
