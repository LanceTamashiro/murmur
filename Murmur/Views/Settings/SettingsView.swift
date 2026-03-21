import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
            DictionarySettingsView()
                .tabItem {
                    Label("Dictionary", systemImage: "character.book.closed")
                }
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

#Preview {
    SettingsView()
}
