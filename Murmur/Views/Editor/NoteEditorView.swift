import SwiftUI
import Models

struct NoteEditorView: View {
    @Bindable var note: Note

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $note.bodyMarkdown)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .scrollContentBackground(.hidden)

            EditorToolbar(note: note)
        }
        .onChange(of: note.bodyMarkdown) {
            note.updateWordCount()
            note.updatedAt = Date()
        }
    }
}

#Preview {
    NoteEditorView(note: Note(bodyMarkdown: "Hello world, this is a test."))
        .frame(width: 500, height: 400)
}
