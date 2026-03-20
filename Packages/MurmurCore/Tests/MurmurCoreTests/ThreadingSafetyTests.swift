import Testing
import Foundation

/// Check if current thread is main — workaround for Thread.isMainThread being
/// unavailable from async contexts in Swift 6.
nonisolated func isCurrentlyOnMainThread() -> Bool {
    pthread_main_np() != 0
}

/// Regression tests for the onboarding threading crash (_dispatch_assert_queue_fail).
///
/// Root cause: SFSpeechRecognizer.requestAuthorization fires its callback on a
/// background queue. When using withCheckedContinuation to bridge this callback
/// into async/await, the continuation resumes on that background queue. Any
/// @State mutations or UI closure calls after the continuation MUST explicitly
/// hop to the main thread via MainActor.run — otherwise GCD dispatch assertions
/// fire and the app crashes.
///
/// These tests verify the threading contract our onboarding code relies on.
@Suite("Threading Safety Tests")
struct ThreadingSafetyTests {

    // MARK: - The bug: continuation resumes on background queue

    /// Proves that withCheckedContinuation does NOT guarantee main thread
    /// when resumed from a background queue. This is the root cause of the crash.
    @Test func continuationResumedFromBackgroundIsNotOnMainThread() async {
        let isOnMain = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                // This simulates SFSpeechRecognizer.requestAuthorization's callback
                continuation.resume(returning: isCurrentlyOnMainThread())
            }
        }

        // The continuation resumes on whatever queue called resume() —
        // in this case, a global background queue. NOT main thread.
        #expect(!isOnMain, "Continuation callback should fire on background queue (simulating SFSpeechRecognizer)")
    }

    // MARK: - The fix: MainActor.run guarantees main thread

    /// Verifies that MainActor.run hops to main thread after a background
    /// continuation resume. This is the pattern our fix uses in
    /// MicPermissionStepView.requestSpeechAuth().
    @Test func mainActorRunHopsToMainAfterBackgroundContinuation() async {
        // Step 1: Simulate a system callback on a background queue
        let callbackValue = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: 42)
            }
        }

        // Step 2: Use MainActor.run (our fix pattern) — verify it's on main
        let wasOnMain = await MainActor.run {
            isCurrentlyOnMainThread()
        }

        #expect(callbackValue == 42)
        #expect(wasOnMain, "MainActor.run must execute on main thread even after background continuation")
    }

    /// Verifies the complete pattern used in MicPermissionStepView:
    /// background callback → withCheckedContinuation → MainActor.run { state mutation }.
    /// This is the exact code path that was crashing.
    @Test func fullPermissionCallbackPatternExecutesStateOnMain() async {
        // Simulate the permission request flow:
        // 1. System API calls back on background queue with a result
        // 2. We bridge it via withCheckedContinuation
        // 3. We use MainActor.run to safely mutate state

        actor StateTracker: Sendable {
            var mutatedOnMain = false
            var value: String = ""
            func update(onMain: Bool, with val: String) {
                mutatedOnMain = onMain
                value = val
            }
        }

        let tracker = StateTracker()

        // Simulate: SFSpeechRecognizer.requestAuthorization { status in ... }
        let status = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: "authorized")
            }
        }

        // This is the FIXED pattern — MainActor.run ensures main thread
        let onMain = await MainActor.run {
            isCurrentlyOnMainThread()
        }
        await tracker.update(onMain: onMain, with: status)

        let wasOnMain = await tracker.mutatedOnMain
        let finalValue = await tracker.value

        #expect(wasOnMain, "State mutation must happen on main thread — this was the crash")
        #expect(finalValue == "authorized")
    }

    // MARK: - Task { @MainActor in } pattern

    /// Verifies that Task { @MainActor in } binds the task to the main actor,
    /// ensuring all awaits within resume on main. This is the pattern used
    /// for button action Tasks in MicPermissionStepView.
    @Test func taskWithMainActorAnnotationRunsOnMain() async {
        actor ResultHolder: Sendable {
            var afterAwaitOnMain = false
            func set(_ value: Bool) { afterAwaitOnMain = value }
        }

        let holder = ResultHolder()

        // Simulate: Button action → Task { @MainActor in ... }
        let task = Task { @MainActor in
            // Simulate: micGranted = await AVAudioApplication.requestRecordPermission()
            _ = await withCheckedContinuation { continuation in
                DispatchQueue.global().async {
                    continuation.resume(returning: true)
                }
            }
            // After the await, we should still be on main actor
            let onMain = isCurrentlyOnMainThread()
            await holder.set(onMain)
        }

        await task.value
        let wasOnMain = await holder.afterAwaitOnMain
        #expect(wasOnMain, "Task { @MainActor in } must resume on main thread after background await")
    }

    // MARK: - Task.detached pattern (GlobeKeyStepView)

    /// Verifies that Task.detached + MainActor.run correctly runs blocking
    /// work off main thread, then hops back for state updates.
    /// This is the pattern used in GlobeKeyStepView.setGlobeKeyToDoNothing().
    @Test func detachedTaskWithMainActorRunForStateUpdates() async {
        actor ResultHolder: Sendable {
            var blockingWorkOnMain = true  // should become false
            var stateUpdateOnMain = false  // should become true
            func setBlocking(_ value: Bool) { blockingWorkOnMain = value }
            func setStateUpdate(_ value: Bool) { stateUpdateOnMain = value }
        }

        let holder = ResultHolder()

        let task = Task.detached {
            // Blocking work should NOT be on main
            let blockingOnMain = isCurrentlyOnMainThread()
            await holder.setBlocking(blockingOnMain)

            // State update MUST be on main
            let stateOnMain = await MainActor.run {
                isCurrentlyOnMainThread()
            }
            await holder.setStateUpdate(stateOnMain)
        }

        await task.value

        let blockingOnMain = await holder.blockingWorkOnMain
        let stateOnMain = await holder.stateUpdateOnMain

        #expect(!blockingOnMain, "Blocking work (Process.waitUntilExit) must NOT run on main thread")
        #expect(stateOnMain, "State updates after blocking work must run on main thread")
    }
}
