import Testing
import Foundation
@testable import SpeechEngine

/// Thread-safe collector for async stream values
private actor EventCollector {
    var events: [TranscriptionEvent] = []

    func append(_ event: TranscriptionEvent) {
        events.append(event)
    }

    var count: Int { events.count }

    func event(at index: Int) -> TranscriptionEvent { events[index] }
}

private actor AmplitudeCollector {
    var values: [Float] = []

    func append(_ value: Float) {
        values.append(value)
    }

    var count: Int { values.count }

    func allValues() -> [Float] { values }
}

@Suite("MockSpeechEngine Tests")
struct MockSpeechEngineTests {

    // MARK: - Authorization

    @Test func initialAuthorizationIsNotDetermined() {
        let engine = MockSpeechEngine()
        #expect(engine.authorizationStatus == .notDetermined)
    }

    @Test func requestAuthorizationGranted() async {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        let status = await engine.requestAuthorization()
        #expect(status == .authorized)
        #expect(engine.authorizationStatus == .authorized)
    }

    @Test func requestAuthorizationDenied() async {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .denied
        let status = await engine.requestAuthorization()
        #expect(status == .denied)
        #expect(engine.authorizationStatus == .denied)
    }

    @Test func requestAuthorizationRestricted() async {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .restricted
        let status = await engine.requestAuthorization()
        #expect(status == .restricted)
        #expect(engine.authorizationStatus == .restricted)
    }

    // MARK: - Session Lifecycle

    @Test func startSessionRequiresAuthorization() async {
        let engine = MockSpeechEngine()
        await #expect(throws: SpeechEngineError.self) {
            _ = try await engine.startSession(locale: nil, customVocabulary: [])
        }
    }

    @Test func startSessionThrowsNotAuthorizedWhenDenied() async {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .denied
        _ = await engine.requestAuthorization()
        do {
            _ = try await engine.startSession(locale: nil, customVocabulary: [])
            Issue.record("Expected notAuthorized error")
        } catch let error as SpeechEngineError {
            if case .notAuthorized = error {
                // Expected
            } else {
                Issue.record("Expected .notAuthorized, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func startSessionThrowsMicNotAuthorized() async {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()
        engine.mockMicrophonePermissionGranted = false

        do {
            _ = try await engine.startSession(locale: nil, customVocabulary: [])
            Issue.record("Expected microphoneNotAuthorized error")
        } catch let error as SpeechEngineError {
            if case .microphoneNotAuthorized = error {
                // Expected
            } else {
                Issue.record("Expected .microphoneNotAuthorized, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func startAndStopSession() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()

        let sessionID = try await engine.startSession(locale: nil, customVocabulary: [])
        #expect(sessionID != UUID())
        #expect(engine.startSessionCallCount == 1)

        await engine.stopSession()
        #expect(engine.stopSessionCallCount == 1)
    }

    @Test func cancelSession() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()

        _ = try await engine.startSession(locale: nil, customVocabulary: [])
        await engine.cancelSession()
        #expect(engine.cancelSessionCallCount == 1)
    }

    @Test func startSessionPassesLocaleAndVocabulary() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()

        let locale = Locale(identifier: "en-US")
        let vocab = ["HIPAA", "telehealth", "CBT"]
        _ = try await engine.startSession(locale: locale, customVocabulary: vocab)

        #expect(engine.lastLocale == locale)
        #expect(engine.lastCustomVocabulary == vocab)
    }

    @Test func multipleStartStopCycles() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()

        _ = try await engine.startSession(locale: nil, customVocabulary: [])
        await engine.stopSession()

        _ = try await engine.startSession(locale: nil, customVocabulary: [])
        await engine.stopSession()

        _ = try await engine.startSession(locale: nil, customVocabulary: [])
        await engine.cancelSession()

        #expect(engine.startSessionCallCount == 3)
        #expect(engine.stopSessionCallCount == 2)
        #expect(engine.cancelSessionCallCount == 1)
    }

    // MARK: - Transcription Events

    @Test func stopSessionEmitsFinalTranscription() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        engine.mockTranscriptionText = "Patient reports improvement"
        _ = await engine.requestAuthorization()

        _ = try await engine.startSession(locale: nil, customVocabulary: [])

        let collector = EventCollector()
        let collectTask = Task {
            for await event in engine.transcriptionEvents {
                await collector.append(event)
                if case .sessionEnded = event { break }
            }
        }

        await engine.stopSession()
        await collectTask.value

        let count = await collector.count
        #expect(count == 3)

        let event0 = await collector.event(at: 0)
        if case .sessionStarted = event0 {
            // good
        } else {
            Issue.record("Expected sessionStarted, got \(event0)")
        }

        let event1 = await collector.event(at: 1)
        if case .final(let result) = event1 {
            #expect(result.text == "Patient reports improvement")
            #expect(result.isFinal == true)
        } else {
            Issue.record("Expected final result, got \(event1)")
        }

        let event2 = await collector.event(at: 2)
        if case .sessionEnded(_, let duration) = event2 {
            #expect(duration == 5.0)
        } else {
            Issue.record("Expected sessionEnded, got \(event2)")
        }
    }

    @Test func simulatePartialResult() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()

        _ = try await engine.startSession(locale: nil, customVocabulary: [])

        let collector = EventCollector()
        let collectTask = Task {
            var count = 0
            for await event in engine.transcriptionEvents {
                await collector.append(event)
                count += 1
                if count >= 3 { break }
            }
        }

        engine.simulatePartialResult("Hello")
        engine.simulatePartialResult("Hello world")

        await collectTask.value

        let count = await collector.count
        #expect(count == 3)

        let event1 = await collector.event(at: 1)
        if case .partial(let result) = event1 {
            #expect(result.text == "Hello")
            #expect(result.isFinal == false)
        }

        let event2 = await collector.event(at: 2)
        if case .partial(let result) = event2 {
            #expect(result.text == "Hello world")
        }
    }

    @Test func simulateAmplitude() async throws {
        let engine = MockSpeechEngine()

        let collector = AmplitudeCollector()
        let collectTask = Task {
            var count = 0
            for await amp in engine.amplitudeStream {
                await collector.append(amp)
                count += 1
                if count >= 3 { break }
            }
        }

        engine.simulateAmplitude(0.1)
        engine.simulateAmplitude(0.5)
        engine.simulateAmplitude(0.9)

        await collectTask.value

        let values = await collector.allValues()
        #expect(values == [0.1, 0.5, 0.9])
    }

    @Test func cancelSessionEmitsZeroDuration() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()

        _ = try await engine.startSession(locale: nil, customVocabulary: [])

        let collector = EventCollector()
        let collectTask = Task {
            for await event in engine.transcriptionEvents {
                await collector.append(event)
                if case .sessionEnded = event { break }
            }
        }

        await engine.cancelSession()
        await collectTask.value

        let count = await collector.count
        #expect(count == 2)

        let event1 = await collector.event(at: 1)
        if case .sessionEnded(_, let duration) = event1 {
            #expect(duration == 0)
        }
    }

    // MARK: - Permission Flow Order

    @Test func authorizationMustPrecedeSession() async {
        let engine = MockSpeechEngine()
        do {
            _ = try await engine.startSession(locale: nil, customVocabulary: [])
            Issue.record("Should have thrown notAuthorized")
        } catch let error as SpeechEngineError {
            if case .notAuthorized = error {
                // Expected
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // Now authorize and retry
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()
        let sessionID = try? await engine.startSession(locale: nil, customVocabulary: [])
        #expect(sessionID != nil)
    }

    @Test func micPermissionCheckBeforeAudioAccess() async {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()

        engine.mockMicrophonePermissionGranted = false
        do {
            _ = try await engine.startSession(locale: nil, customVocabulary: [])
            Issue.record("Should have thrown microphoneNotAuthorized")
        } catch let error as SpeechEngineError {
            if case .microphoneNotAuthorized = error {
                // Expected
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // Grant mic and retry
        engine.mockMicrophonePermissionGranted = true
        let sessionID = try? await engine.startSession(locale: nil, customVocabulary: [])
        #expect(sessionID != nil)
        #expect(engine.startSessionCallCount == 2)
    }

    // MARK: - Error Types

    @Test func speechEngineErrorCases() {
        let errors: [SpeechEngineError] = [
            .notAuthorized,
            .authorizationDenied,
            .microphoneNotAuthorized,
            .engineNotAvailable,
            .audioSessionFailed(underlying: NSError(domain: "test", code: -1)),
            .recognizerUnavailableForLocale("xx-XX"),
            .sessionExpired,
            .unknownError(underlying: NSError(domain: "test", code: -2)),
        ]
        #expect(errors.count == 8)

        for error in errors {
            #expect(error is Error)
        }
    }

    // MARK: - Stop/Cancel Without Active Session

    @Test func stopSessionWithoutStartIsNoOp() async {
        let engine = MockSpeechEngine()
        await engine.stopSession()
        #expect(engine.stopSessionCallCount == 1)
    }

    @Test func cancelSessionWithoutStartIsNoOp() async {
        let engine = MockSpeechEngine()
        await engine.cancelSession()
        #expect(engine.cancelSessionCallCount == 1)
    }
}
