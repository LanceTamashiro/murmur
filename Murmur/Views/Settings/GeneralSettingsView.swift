import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("activationMode") private var activationMode = "toggle"
    @AppStorage("triggerKey") private var triggerKey = "fn"
    @AppStorage("toggleMaxDuration") private var toggleMaxDuration = 300
    @AppStorage("appearance") private var appearance = "system"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Activation Mode", selection: $activationMode) {
                    Text("Toggle (press to start/stop)").tag("toggle")
                    Text("Hold to Dictate").tag("hold")
                }
                if activationMode == "hold" {
                    Picker("Trigger Key", selection: $triggerKey) {
                        ForEach(TriggerKey.allCases, id: \.rawValue) { key in
                            Text(key.displayName).tag(key.rawValue)
                        }
                    }
                    Text("Restart Murmur after changing the trigger key.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if activationMode == "toggle" {
                    Picker("Max Duration", selection: $toggleMaxDuration) {
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                        Text("5 minutes").tag(300)
                        Text("10 minutes").tag(600)
                        Text("No limit").tag(0)
                    }
                }
                Text("Global Hotkey: ⌘⇧Space")
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Privacy") {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text("Speech recognition is always on-device")
                }
                Text("Voice audio and notes never leave your Mac. If you enable AI editing with a cloud provider (OpenAI or Claude), only the transcribed text is sent to polish grammar and tone. Configure providers in the AI Editing tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
