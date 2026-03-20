import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("activationMode") private var activationMode = "toggle"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("clinicalMode") private var clinicalMode = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Activation Mode", selection: $activationMode) {
                    Text("Toggle (press to start/stop)").tag("toggle")
                    Text("Hold to Dictate").tag("hold")
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
                Toggle("Clinical Mode", isOn: $clinicalMode)
                Text("When enabled, all cloud AI providers are disabled. Only on-device processing is used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
