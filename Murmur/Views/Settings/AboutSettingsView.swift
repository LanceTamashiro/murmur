import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Murmur")
                .font(.title)
                .fontWeight(.bold)
            Text("Voice Dictation & Intelligent Notes")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Text("Built for Unconventional Psychotherapy")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
