import SwiftUI

struct AllSetStepView: View {
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Hold the **Fn** key anywhere to dictate — release to stop. You can also press **⌘⇧Space** to toggle. Your words will appear right where you're typing, or as a new note.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            HStack(spacing: 16) {
                Button("Open Notes Library", action: onComplete)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button("Start Dictating", action: onComplete)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding()
    }
}
