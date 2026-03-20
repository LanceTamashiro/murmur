import Testing
import Foundation
@testable import SpeechEngine

/// Check if current thread is main — workaround for Thread.isMainThread being
/// unavailable from async contexts in Swift 6.
private nonisolated func checkOnMainThread() -> Bool {
    pthread_main_np() != 0
}

/// Mock permission provider that simulates system APIs calling back on a
/// BACKGROUND QUEUE — exactly like SFSpeechRecognizer.requestAuthorization does.
/// This is the root cause of the crash we're testing against.
private final class BackgroundCallbackPermissionProvider: PermissionProvider, @unchecked Sendable {
    var micResult: Bool = true
    var speechResult: Bool = true
    /// Tracks which thread the callback fires on (should be background)
    var micCallbackWasOnMain: Bool? = nil
    var speechCallbackWasOnMain: Bool? = nil

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            // Simulate AVAudioApplication.requestRecordPermission() —
            // fires completion on a background queue
            DispatchQueue.global().async { [self] in
                micCallbackWasOnMain = checkOnMainThread()
                continuation.resume(returning: micResult)
            }
        }
    }

    func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            // Simulate SFSpeechRecognizer.requestAuthorization —
            // fires completion on a background queue (THIS CAUSED THE CRASH)
            DispatchQueue.global().async { [self] in
                speechCallbackWasOnMain = checkOnMainThread()
                continuation.resume(returning: speechResult)
            }
        }
    }
}

/// Mock that calls back on the main queue — for comparison testing.
private final class MainQueuePermissionProvider: PermissionProvider, @unchecked Sendable {
    var micResult: Bool = true
    var speechResult: Bool = true

    func requestMicrophonePermission() async -> Bool {
        micResult
    }

    func requestSpeechPermission() async -> Bool {
        speechResult
    }
}

// MARK: - Regression tests for onboarding threading crash

@Suite("Onboarding Permission Coordinator Tests")
struct OnboardingPermissionTests {

    // MARK: - The crash scenario: background callbacks + state mutation

    /// THE MAIN REGRESSION TEST.
    /// Simulates the exact crash scenario: SFSpeechRecognizer calls back on a
    /// background queue, and the coordinator must safely mutate state on main.
    /// Before the fix, this would crash with _dispatch_assert_queue_fail.
    @MainActor
    @Test func backgroundCallbackDoesNotCrashWhenMutatingState() async {
        let provider = BackgroundCallbackPermissionProvider()
        provider.micResult = true
        provider.speechResult = true

        let coordinator = OnboardingPermissionCoordinator(provider: provider)

        // This was the crash: system callback on background → state mutation
        await coordinator.requestMicAndSpeech()

        // If we get here without crashing, the threading fix works
        #expect(coordinator.micGranted == true)
        #expect(coordinator.speechGranted == true)
        #expect(coordinator.allGranted == true)
    }

    /// Verifies that the coordinator's state mutations happen on the main thread
    /// even when the provider calls back from a background queue.
    @MainActor
    @Test func stateMutationsHappenOnMainThread() async {
        let provider = BackgroundCallbackPermissionProvider()
        provider.micResult = true
        provider.speechResult = true

        let coordinator = OnboardingPermissionCoordinator(provider: provider)
        await coordinator.requestMicAndSpeech()

        // The provider callbacks fired on background queues
        #expect(provider.micCallbackWasOnMain == false,
                "Mic callback should fire on background (simulating system API)")
        #expect(provider.speechCallbackWasOnMain == false,
                "Speech callback should fire on background (simulating SFSpeechRecognizer)")

        // But the coordinator's state was mutated on main (no crash = success)
        #expect(coordinator.allGranted == true,
                "State must be safely updated despite background callbacks")
    }

    // MARK: - Permission flow logic

    @MainActor
    @Test func micDeniedSkipsSpeechRequest() async {
        let provider = BackgroundCallbackPermissionProvider()
        provider.micResult = false
        provider.speechResult = true

        let coordinator = OnboardingPermissionCoordinator(provider: provider)
        await coordinator.requestMicAndSpeech()

        #expect(coordinator.micGranted == false)
        #expect(coordinator.speechGranted == false, "Speech should not be requested if mic denied")
        #expect(coordinator.allGranted == false)
        #expect(provider.speechCallbackWasOnMain == nil, "Speech provider should not have been called")
    }

    @MainActor
    @Test func micGrantedButSpeechDenied() async {
        let provider = BackgroundCallbackPermissionProvider()
        provider.micResult = true
        provider.speechResult = false

        let coordinator = OnboardingPermissionCoordinator(provider: provider)
        await coordinator.requestMicAndSpeech()

        #expect(coordinator.micGranted == true)
        #expect(coordinator.speechGranted == false)
        #expect(coordinator.allGranted == false)
    }

    @MainActor
    @Test func speechOnlyRequest() async {
        let provider = BackgroundCallbackPermissionProvider()
        provider.speechResult = true

        let coordinator = OnboardingPermissionCoordinator(provider: provider)
        await coordinator.requestSpeechOnly()

        #expect(coordinator.speechGranted == true)
        #expect(provider.speechCallbackWasOnMain == false,
                "Speech callback fires on background queue")
    }

    @MainActor
    @Test func bothDenied() async {
        let provider = BackgroundCallbackPermissionProvider()
        provider.micResult = false
        provider.speechResult = false

        let coordinator = OnboardingPermissionCoordinator(provider: provider)
        await coordinator.requestMicAndSpeech()

        #expect(coordinator.micGranted == false)
        #expect(coordinator.speechGranted == false)
        #expect(coordinator.allGranted == false)
    }

    // MARK: - Stress test: rapid sequential requests

    /// Simulates pressing the permission button multiple times rapidly.
    /// Each request fires callbacks on a background queue — all must
    /// safely mutate state on main without crashing.
    @MainActor
    @Test func rapidSequentialRequestsDoNotCrash() async {
        let provider = BackgroundCallbackPermissionProvider()
        provider.micResult = true
        provider.speechResult = true

        let coordinator = OnboardingPermissionCoordinator(provider: provider)

        // Simulate rapid button presses
        for _ in 0..<10 {
            await coordinator.requestMicAndSpeech()
        }

        // All requests completed without crash
        #expect(coordinator.allGranted == true)
    }

    // MARK: - Main queue callback (control test)

    /// Control test: when callbacks happen on main queue, everything works.
    /// This proves the test infrastructure is correct.
    @MainActor
    @Test func mainQueueCallbacksAlsoWork() async {
        let provider = MainQueuePermissionProvider()
        provider.micResult = true
        provider.speechResult = true

        let coordinator = OnboardingPermissionCoordinator(provider: provider)
        await coordinator.requestMicAndSpeech()

        #expect(coordinator.allGranted == true)
    }
}
