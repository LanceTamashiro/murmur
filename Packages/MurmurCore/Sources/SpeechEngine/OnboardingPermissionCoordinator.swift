import Foundation

/// Result of the onboarding permission flow.
public struct PermissionFlowResult: Sendable, Equatable {
    public let micGranted: Bool
    public let speechGranted: Bool
    public var allGranted: Bool { micGranted && speechGranted }

    public init(micGranted: Bool, speechGranted: Bool) {
        self.micGranted = micGranted
        self.speechGranted = speechGranted
    }
}

/// Protocol for system permission requests — mockable for testing.
public protocol PermissionProvider: Sendable {
    func requestMicrophonePermission() async -> Bool
    /// Callback-based API (like SFSpeechRecognizer.requestAuthorization).
    /// The callback may fire on ANY queue — callers must handle threading.
    func requestSpeechPermission() async -> Bool
}

/// Coordinates the mic + speech permission flow during onboarding.
/// All state mutations happen on the main actor, regardless of which
/// queue the system callbacks fire on.
@MainActor
public final class OnboardingPermissionCoordinator: Observable {
    public private(set) var micGranted = false
    public private(set) var speechGranted = false
    public var allGranted: Bool { micGranted && speechGranted }

    private let provider: PermissionProvider

    public init(provider: PermissionProvider) {
        self.provider = provider
    }

    /// Request microphone permission, then automatically request speech if mic is granted.
    /// All state mutations are guaranteed to happen on @MainActor (main thread).
    public func requestMicAndSpeech() async {
        let mic = await provider.requestMicrophonePermission()
        // We're @MainActor, so this assignment is on main thread
        micGranted = mic

        if mic {
            await requestSpeechOnly()
        }
    }

    /// Request speech permission only (mic already granted).
    /// State mutation is guaranteed to happen on @MainActor (main thread).
    public func requestSpeechOnly() async {
        let speech = await provider.requestSpeechPermission()
        // We're @MainActor, so this assignment is on main thread
        speechGranted = speech
    }
}
