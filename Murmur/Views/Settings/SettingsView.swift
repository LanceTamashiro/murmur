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
            AIEditingSettingsView()
                .tabItem {
                    Label("AI Editing", systemImage: "wand.and.stars")
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
