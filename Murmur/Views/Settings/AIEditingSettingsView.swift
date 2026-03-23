import SwiftUI
import AIEditor

struct AIEditingSettingsView: View {
    @AppStorage("aiEditingEnabled") private var aiEditingEnabled = true
    @AppStorage("fillerRemovalEnabled") private var fillerRemovalEnabled = true
    @AppStorage("backtrackCorrectionEnabled") private var backtrackCorrectionEnabled = true
    @AppStorage("grammarCorrectionEnabled") private var grammarCorrectionEnabled = true
    @AppStorage("toneAdaptationEnabled") private var toneAdaptationEnabled = false
    @AppStorage("commandExecutionEnabled") private var commandExecutionEnabled = true

    var body: some View {
        Form {
            Section("AI Editing") {
                Toggle("Enable AI Editing", isOn: $aiEditingEnabled)
                Text("When enabled, dictated text is cleaned up and polished before injection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Processing Stages") {
                Toggle("Remove Filler Words", isOn: $fillerRemovalEnabled)
                    .disabled(!aiEditingEnabled)
                Text("Removes \"um\", \"uh\", \"you know\", and other filler words.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Backtrack Correction", isOn: $backtrackCorrectionEnabled)
                    .disabled(!aiEditingEnabled)
                Text("Handles \"no wait\", \"scratch that\", and similar corrections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Grammar Correction", isOn: $grammarCorrectionEnabled)
                    .disabled(!aiEditingEnabled)
                Text("Fixes grammar, spelling, and punctuation (requires AI provider).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Tone Adaptation", isOn: $toneAdaptationEnabled)
                    .disabled(!aiEditingEnabled)
                Text("Adjusts text tone based on voice commands (requires AI provider).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Voice Commands", isOn: $commandExecutionEnabled)
                    .disabled(!aiEditingEnabled)
                Text("Detects commands like \"new line\", \"capitalize that\", \"translate to French\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("AI Providers") {
                ProviderSettingsView()
            }

            Section("Privacy") {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text("Filler removal and backtrack correction run entirely on-device")
                }
                Text("Grammar correction, tone adaptation, and AI commands send text to your configured AI provider. Apple Intelligence runs on-device. API keys are stored in your Mac's Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
