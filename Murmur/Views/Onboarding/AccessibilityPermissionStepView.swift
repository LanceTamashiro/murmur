import SwiftUI
import AppKit

struct AccessibilityPermissionStepView: View {
    var onContinue: () -> Void
    @State private var isGranted = false
    @State private var showManualContinue = false
    @State private var pollCount = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "accessibility")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Accessibility Permission")
                .font(.title)
                .fontWeight(.semibold)
            Text("Murmur needs accessibility access to insert text into other applications. This lets you dictate directly into any text field on your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            if isGranted {
                Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                Button("Grant Accessibility Access") {
                    promptForAccessibility()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Text("Click **Grant** above. If Murmur appears in the list, toggle it **on**.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if showManualContinue {
                    Button("I've already granted access — continue") {
                        onContinue()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .padding(.top, 4)

                    Text("Xcode debug builds may require a relaunch for accessibility to take effect.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                } else {
                    Button("Skip for now") {
                        onContinue()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .task {
            isGranted = AXIsProcessTrusted()
            while !isGranted {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                pollCount += 1
                // After 5 seconds of polling, show the manual continue button
                if pollCount >= 5 {
                    showManualContinue = true
                }
                let trusted = AXIsProcessTrusted()
                if trusted {
                    isGranted = true
                    onContinue()
                }
            }
        }
    }

    private func promptForAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
