import SwiftUI
import AVFoundation
import Speech
import SpeechEngine

/// Real system permission provider — calls AVAudioApplication and SFSpeechRecognizer.
/// SFSpeechRecognizer.requestAuthorization fires its callback on a BACKGROUND QUEUE.
private final class SystemPermissionProvider: PermissionProvider, @unchecked Sendable {
    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                // This fires on a background queue — the coordinator handles threading
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

struct MicPermissionStepView: View {
    var onContinue: () -> Void
    @State private var coordinator = OnboardingPermissionCoordinator(
        provider: SystemPermissionProvider()
    )

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Microphone & Speech Access")
                .font(.title)
                .fontWeight(.semibold)
            Text("Murmur needs microphone access and speech recognition to transcribe your voice. Audio is processed on-device and never sent to external servers.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()

            if coordinator.allGranted {
                VStack(spacing: 8) {
                    Label("Microphone access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("Speech recognition granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                if coordinator.micGranted {
                    Label("Microphone access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant Microphone Access") {
                        Task { @MainActor in
                            await coordinator.requestMicAndSpeech()
                            if coordinator.allGranted {
                                onContinue()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if coordinator.micGranted && !coordinator.speechGranted {
                    Button("Grant Speech Recognition") {
                        Task { @MainActor in
                            await coordinator.requestSpeechOnly()
                            if coordinator.allGranted {
                                onContinue()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding()
    }
}
