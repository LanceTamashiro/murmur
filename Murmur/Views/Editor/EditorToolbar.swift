import SwiftUI
import Models

struct EditorToolbar: View {
    let note: Note

    var body: some View {
        HStack {
            Text("\(note.wordCount) words")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("·")
                .foregroundStyle(.quaternary)
            Text("\(note.characterCount) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
