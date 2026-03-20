import SwiftUI

struct DictionarySettingsView: View {
    var body: some View {
        VStack {
            Text("Personal Dictionary")
                .font(.headline)
            Text("Add custom words to improve transcription accuracy.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ContentUnavailableView(
                "No Custom Words",
                systemImage: "text.badge.plus",
                description: Text("Words you add will appear here.")
            )
            Spacer()
        }
        .padding()
    }
}
