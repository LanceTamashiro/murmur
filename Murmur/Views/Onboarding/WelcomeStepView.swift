import SwiftUI

struct WelcomeStepView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text("Your voice, your notes.")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Murmur turns your voice into text — anywhere on your Mac. Dictate into any app, or capture thoughts in the built-in notes library.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button("Get Started", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }
}
