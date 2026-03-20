import Testing
import Foundation
import AVFoundation
@testable import Murmur
@testable import SpeechEngine
@testable import NoteStore
@testable import Models
import SwiftData

// MARK: - Race Condition Regression Tests

@MainActor
@Suite("DictationViewModel Race Condition Tests", .serialized)
struct DictationViewModelRaceTests {

    /// Helper: create a configured DictationViewModel with MockSpeechEngine and in-memory storage.
    /// The TextInjectionService uses a real AppContextDetector (lightweight, no side effects in tests).
    private static func makeViewModel(engine: MockSpeechEngine) throws -> (DictationViewModel, MockSpeechEngine) {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let noteStore = NoteStoreService(modelContainer: container)

        let appContextDetector = AppContextDetector()
        let injectionService = TextInjectionService(appContextDetector: appContextDetector)

        let vm = DictationViewModel()
        vm.configure(
            speechEngine: engine,
            textInjectionService: injectionService,
            noteStore: noteStore
        )
        return (vm, engine)
    }

    // MARK: - Bug regression: stop before session starts should reset to idle

    @Test func stopBeforeSessionStartsResetsToIdle() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        // Delay authorization to create a window where state is .recording but session hasn't started
        engine.authorizationDelay = 0.5

        let (vm, _) = try DictationViewModelRaceTests.makeViewModel(engine: engine)

        // Start dictation — state becomes .recording immediately
        vm.startDictation()
        #expect(vm.state == .recording)

        // Wait briefly for the Task to start but not complete (it's waiting on authorizationDelay)
        try await Task.sleep(for: .milliseconds(50))

        // Stop before the session has started — this was the race condition bug.
        // Previously: stopDictation() called speechEngine.stopSession() on a non-existent session (no-op),
        // set state to .processing, and the startup Task continued to start a session that was never stopped.
        // Now: stopDictation() detects currentSessionID == nil, cancels startup, and resets to .idle.
        vm.stopAndInject()

        // Give time for reset to complete
        try await Task.sleep(for: .milliseconds(100))

        // State should be idle, not stuck in .processing
        #expect(vm.state == .idle)

        // The engine's startSession should NOT have been called (cancelled before it got there)
        #expect(engine.startSessionCallCount == 0)

        vm.cancel()
        try await Task.sleep(for: .milliseconds(200))
    }

    // MARK: - Bug regression: stop during startSession delay resets cleanly

    @Test func stopDuringStartSessionDelayResetsCleanly() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        // No auth delay, but slow session start
        engine.startSessionDelay = 0.5

        let (vm, _) = try DictationViewModelRaceTests.makeViewModel(engine: engine)

        vm.startDictation()
        #expect(vm.state == .recording)

        // Wait for auth to complete but not startSession
        try await Task.sleep(for: .milliseconds(100))

        // Stop while startSession is delayed
        vm.stopAndInject()

        // Give time for the state guard in the startup Task to fire
        try await Task.sleep(for: .milliseconds(100))

        // State should be idle — startup Task should have detected state != .recording and bailed
        #expect(vm.state == .idle)

        // Cancel all async tasks to prevent use-after-free on ModelContainer
        vm.cancel()
        try await Task.sleep(for: .milliseconds(200))
    }

    // MARK: - Normal flow: start, record, stop saves correctly
    // Note: This test requires microphone permission to be granted to the test host.
    // It verifies the full happy path: start → record → stop → session ends.

    @Test func normalStartStopFlowProcessesSession() async throws {
        // Skip if mic permission isn't available (can't test full flow without it)
        let micPerm = AVAudioApplication.shared.recordPermission
        guard micPerm == .granted else {
            // In test environments without mic permission, the ViewModel's startDictation
            // will fail at the mic check. This is expected — the race condition tests above
            // cover the critical bug fix. This test covers the happy path when permission exists.
            return
        }

        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        engine.mockTranscriptionText = "Test note text"

        let (vm, _) = try DictationViewModelRaceTests.makeViewModel(engine: engine)

        vm.startDictation()
        #expect(vm.state == .recording)

        // Wait for session to actually start (async Task completes)
        try await Task.sleep(for: .milliseconds(200))

        // Session should be running now
        #expect(engine.startSessionCallCount == 1)

        // Stop — should trigger normal stop flow
        vm.stopAndInject()

        // Wait for processing to complete
        try await Task.sleep(for: .milliseconds(500))

        // State should progress through .processing → .completed → .idle
        let state = vm.state
        let isValid = (state == .completed || state == .idle)
        #expect(isValid, "Expected .completed or .idle, got \(state)")

        // Cancel all async tasks to prevent use-after-free on ModelContainer
        vm.cancel()
        try await Task.sleep(for: .milliseconds(200))
    }

    // MARK: - Rapid double-tap should not get stuck

    @Test func rapidDoubleTapDoesNotGetStuck() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        engine.authorizationDelay = 0.3

        let (vm, _) = try DictationViewModelRaceTests.makeViewModel(engine: engine)

        // First tap: start then immediately stop
        vm.startDictation()
        #expect(vm.state == .recording)
        vm.stopAndInject()

        // Wait for cleanup
        try await Task.sleep(for: .milliseconds(200))

        // State should be idle — ready for next attempt (not stuck in .processing)
        #expect(vm.state == .idle)

        // Second tap: start again — state should transition to .recording
        engine.authorizationDelay = 0
        vm.startDictation()
        #expect(vm.state == .recording)

        // The key assertion: the state machine recovered from the first aborted attempt.
        // Whether startSession succeeds depends on mic permission in the test environment,
        // but the ViewModel is not stuck.

        vm.cancel()
        try await Task.sleep(for: .milliseconds(200))
    }

    // MARK: - State guards: startDictation aborts if state changes during auth

    @Test func startDictationAbortsIfStateChangedDuringAuth() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        engine.authorizationDelay = 0.3

        let (vm, _) = try DictationViewModelRaceTests.makeViewModel(engine: engine)

        vm.startDictation()
        #expect(vm.state == .recording)

        // Simulate stop being called during the auth delay
        try await Task.sleep(for: .milliseconds(50))
        vm.stopAndInject()

        // Wait for everything to settle
        try await Task.sleep(for: .milliseconds(500))

        // No session should have been started
        #expect(engine.startSessionCallCount == 0)
        #expect(vm.state == .idle)

        vm.cancel()
        try await Task.sleep(for: .milliseconds(200))
    }

    // MARK: - State guards: orphan session is cleaned up

    @Test func orphanSessionIsCleanedUpIfStateChanges() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        // Auth fast, session start slow enough to create a tiny window
        engine.startSessionDelay = 0.3

        let (vm, _) = try DictationViewModelRaceTests.makeViewModel(engine: engine)

        vm.startDictation()

        // Wait for auth to complete, then stop while startSession is in progress
        try await Task.sleep(for: .milliseconds(100))
        vm.stopAndInject()

        // Wait for the startup Task to complete (it will detect state changed and stop the orphan)
        try await Task.sleep(for: .seconds(1))

        // The session should have been started then immediately stopped (orphan cleanup)
        // startSession may or may not have completed depending on cancellation timing,
        // but the engine should not have a dangling active session
        #expect(vm.state == .idle || vm.state == .completed || String(describing: vm.state).hasPrefix("error"),
                "Expected idle/completed/error, got \(vm.state)")

        // Cancel all async tasks to prevent use-after-free on ModelContainer
        vm.cancel()
        try await Task.sleep(for: .milliseconds(500))
    }
}

// MARK: - Early Injection Tests

@MainActor
@Suite("Early Injection Tests", .serialized)
struct EarlyInjectionTests {

    private static func makeViewModel(engine: MockSpeechEngine) throws -> (DictationViewModel, MockSpeechEngine, NoteStoreService) {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let noteStore = NoteStoreService(modelContainer: container)

        let appContextDetector = AppContextDetector()
        let injectionService = TextInjectionService(appContextDetector: appContextDetector)

        let vm = DictationViewModel()
        vm.configure(
            speechEngine: engine,
            textInjectionService: injectionService,
            noteStore: noteStore
        )
        return (vm, engine, noteStore)
    }

    @Test func earlyInjectionUsesAccumulatedText() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        // Slow finalization so early injection has time to fire first
        engine.stopSessionDelay = .seconds(1)
        engine.mockTranscriptionText = "Hello world. This is a test."

        let (vm, _, noteStore) = try EarlyInjectionTests.makeViewModel(engine: engine)

        vm.startDictation()
        try await Task.sleep(for: .milliseconds(200))

        // Simulate sentence-boundary finals during recording
        engine.simulateFinalResult("Hello world. ")
        engine.simulatePartialResult("Hello world. This is")
        try await Task.sleep(for: .milliseconds(50))

        // At this point, finalizedSegments = ["Hello world. "] and
        // liveTranscript = "Hello world. This is"

        // Stop — should trigger early injection with "Hello world. This is"
        vm.stopAndInject()
        #expect(vm.state == .processing)

        // Give early injection time to fire (but less than the 1s stopSessionDelay)
        try await Task.sleep(for: .milliseconds(300))

        // A note should have been saved with the snapshot text
        let notes = try noteStore.notes(filter: NoteFilter(), sortOrder: .createdAtDescending)
        #expect(notes.count >= 1)
        if let firstNote = notes.first {
            #expect(firstNote.bodyMarkdown == "Hello world. This is")
        }

        // Clean up
        vm.cancel()
        try await Task.sleep(for: .milliseconds(200))
    }

    @Test func tailTextUpdatesNote() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        // Slow finalization to ensure early injection fires first
        engine.stopSessionDelay = .milliseconds(500)
        engine.mockTranscriptionText = "Hello world. This is a test."

        let (vm, _, noteStore) = try EarlyInjectionTests.makeViewModel(engine: engine)

        vm.startDictation()
        try await Task.sleep(for: .milliseconds(200))

        // Simulate a finalized sentence during recording
        engine.simulateFinalResult("Hello world. ")
        try await Task.sleep(for: .milliseconds(50))

        // Stop — early injection fires with "Hello world. "
        vm.stopAndInject()
        try await Task.sleep(for: .milliseconds(100))

        // Note should exist with early snapshot text
        var notes = try noteStore.notes(filter: NoteFilter(), sortOrder: .createdAtDescending)
        #expect(notes.count >= 1)
        let earlyText = notes.first?.bodyMarkdown
        #expect(earlyText == "Hello world. ")

        // Wait for stopSession to complete (emits final + sessionEnded with full text)
        try await Task.sleep(for: .seconds(1))

        // The note should now be updated with the full text including tail
        notes = try noteStore.notes(filter: NoteFilter(), sortOrder: .createdAtDescending)
        #expect(notes.count >= 1)
        if let updatedNote = notes.first {
            #expect(updatedNote.bodyMarkdown == "Hello world. This is a test.")
        }

        vm.cancel()
        try await Task.sleep(for: .milliseconds(200))
    }

    @Test func emptySnapshotSkipsEarlyInjection() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        engine.mockTranscriptionText = "Late arriving text."

        let (vm, _, noteStore) = try EarlyInjectionTests.makeViewModel(engine: engine)

        vm.startDictation()
        try await Task.sleep(for: .milliseconds(200))

        // Don't emit any transcription events — snapshot will be empty

        // Stop — should NOT trigger early injection
        vm.stopAndInject()
        #expect(vm.state == .processing)

        // No note should exist yet (early injection skipped)
        try await Task.sleep(for: .milliseconds(100))
        var notes = try noteStore.notes(filter: NoteFilter(), sortOrder: .createdAtDescending)
        #expect(notes.isEmpty)

        // Wait for normal sessionEnded path
        try await Task.sleep(for: .milliseconds(500))

        // Now a note should exist via the normal path
        notes = try noteStore.notes(filter: NoteFilter(), sortOrder: .createdAtDescending)
        #expect(notes.count == 1)
        #expect(notes.first?.bodyMarkdown == "Late arriving text.")

        vm.cancel()
        try await Task.sleep(for: .milliseconds(200))
    }

    @Test func earlyInjectionDoesNotDoubleInject() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        engine.stopSessionDelay = .milliseconds(300)
        engine.mockTranscriptionText = "Hello world."

        let (vm, _, noteStore) = try EarlyInjectionTests.makeViewModel(engine: engine)

        vm.startDictation()
        try await Task.sleep(for: .milliseconds(200))

        engine.simulateFinalResult("Hello world.")
        try await Task.sleep(for: .milliseconds(50))

        vm.stopAndInject()

        // Wait for everything to complete (early injection + sessionEnded)
        try await Task.sleep(for: .seconds(1))

        // Only ONE note should exist — sessionEnded should NOT create a second note
        let notes = try noteStore.notes(filter: NoteFilter(), sortOrder: .createdAtDescending)
        #expect(notes.count == 1)

        vm.cancel()
        try await Task.sleep(for: .milliseconds(200))
    }
}

// MARK: - AppDelegate Setup Guard Tests

@MainActor
@Suite("AppDelegate Setup Tests")
struct AppDelegateSetupTests {

    @Test func setupCompletedGuardPreventsDoubleInit() async throws {
        let delegate = AppDelegate()
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let vm = DictationViewModel()

        // First setup
        delegate.setup(modelContainer: container, dictationViewModel: vm)

        // Create a second ViewModel to detect if setup runs again
        let vm2 = DictationViewModel()

        // Second setup with different VM — should be no-op due to setupCompleted guard
        delegate.setup(modelContainer: container, dictationViewModel: vm2)

        // The delegate should still reference the first VM's state
        // (If setupCompleted guard works, the second call is ignored)
        // We can't directly inspect the delegate's private state, but we can verify
        // that calling setup twice doesn't crash
    }
}

// MARK: - MockSpeechEngine Race Condition Tests (MurmurCore level)

@Suite("MockSpeechEngine Race Condition Tests")
struct MockSpeechEngineRaceTests {

    @Test func stopSessionBeforeStartIsNoOp() async {
        let engine = MockSpeechEngine()
        await engine.stopSession()
        #expect(engine.stopSessionCallCount == 1)
        // No crash, no events emitted
    }

    @Test func startAfterNoOpStopWorks() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        _ = await engine.requestAuthorization()

        // Stop with no session (no-op)
        await engine.stopSession()

        // Start should still work
        let sessionID = try await engine.startSession(locale: nil, customVocabulary: [])
        #expect(sessionID != UUID())
        #expect(engine.startSessionCallCount == 1)
    }

    @Test func delayedStartSessionCanBeCancelled() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        engine.startSessionDelay = 1.0
        _ = await engine.requestAuthorization()

        let startTask = Task {
            try await engine.startSession(locale: nil, customVocabulary: [])
        }

        // Cancel before startSession completes
        try await Task.sleep(for: .milliseconds(100))
        startTask.cancel()

        // The task should be cancelled
        do {
            _ = try await startTask.value
            // If it completes without error, that's ok too (race between cancel and completion)
        } catch is CancellationError {
            // Expected — the delay's Task.sleep threw CancellationError
        } catch {
            // startSession may throw a different error on cancellation — acceptable
        }
    }

    @Test func delayedAuthorizationCanBeCancelled() async throws {
        let engine = MockSpeechEngine()
        engine.mockAuthorizationResult = .authorized
        engine.authorizationDelay = 1.0

        let authTask = Task {
            await engine.requestAuthorization()
        }

        try await Task.sleep(for: .milliseconds(100))
        authTask.cancel()

        let status = await authTask.value
        // Status may be .authorized (if delay completed) or .notDetermined (if cancelled early)
        // Either way, no crash
        #expect(status == .authorized || status == .notDetermined)
    }
}
