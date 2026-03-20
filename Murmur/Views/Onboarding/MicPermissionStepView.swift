import SwiftUI
import AVFoundation

struct MicPermissionStepView: View {
    var onContinue: () -> Void
    @State private var permissionGranted = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Microphone Access")
                .font(.title)
                .fontWeight(.semibold)
            Text("Murmur needs access to your microphone to transcribe speech. Audio is processed on-device and never sent to external servers.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            if permissionGranted {
                Label("Microphone access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                Button("Grant Microphone Access") {
                    Task {
                        let granted = await AVAudioApplication.requestRecordPermission()
                        permissionGranted = granted
                        if granted {
                            onContinue()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
    }
}
