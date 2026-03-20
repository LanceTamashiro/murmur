import SwiftUI
import Models

struct NoteRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
            Text(note.bodyMarkdown.prefix(100))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(note.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
