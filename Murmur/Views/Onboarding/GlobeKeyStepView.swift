import SwiftUI

struct GlobeKeyStepView: View {
    var onContinue: () -> Void
    @State private var isConfigured = false
    @State private var didAttemptSet = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Globe Key Setup")
                .font(.title)
                .fontWeight(.semibold)
            Text("Murmur uses the **Fn (Globe)** key for push-to-talk dictation — hold to speak, release to stop. This requires the Globe key to be set to \"Do Nothing\" in your keyboard settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()

            if isConfigured {
                Label("Globe key configured for Murmur", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else if didAttemptSet {
                Label("Setting updated — you may need to restart apps for it to take effect", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                Button("Configure Globe Key Automatically") {
                    setGlobeKeyToDoNothing()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("I'll set it manually in System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button("Skip — I'll use ⌘⇧Space instead") {
                    onContinue()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            isConfigured = currentGlobeKeySetting() == 0
        }
    }

    /// Read the current Globe key setting (0 = Do Nothing, 2 = Emoji, etc.)
    private func currentGlobeKeySetting() -> Int {
        UserDefaults(suiteName: "com.apple.HIToolbox")?.integer(forKey: "AppleFnUsageType") ?? -1
    }

    /// Set the Globe key to "Do Nothing" so Murmur can capture it
    private func setGlobeKeyToDoNothing() {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            process.arguments = ["write", "com.apple.HIToolbox", "AppleFnUsageType", "-int", "0"]
            try? process.run()
            process.waitUntilExit()

            await MainActor.run {
                didAttemptSet = true
                if currentGlobeKeySetting() == 0 {
                    isConfigured = true
                }
            }
        }
    }
}

#Preview {
    GlobeKeyStepView(onContinue: {})
}
