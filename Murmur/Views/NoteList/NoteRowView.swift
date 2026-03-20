import SwiftUI
import Models

struct NoteRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(note.bodyMarkdown.isEmpty ? "New Note" : String(note.bodyMarkdown.prefix(100)))
                .font(.callout)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}
