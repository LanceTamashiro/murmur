import SwiftUI
import Models

struct NoteEditorView: View {
    @Bindable var note: Note

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $note.title)
                .font(.title)
                .textFieldStyle(.plain)
                .padding(.horizontal)
                .padding(.top)

            Divider()
                .padding(.horizontal)

            TextEditor(text: $note.bodyMarkdown)
                .font(.body)
                .padding(.horizontal, 12)
                .scrollContentBackground(.hidden)

            EditorToolbar(note: note)
        }
        .onChange(of: note.bodyMarkdown) {
            note.updateWordCount()
            note.updatedAt = Date()
        }
        .onChange(of: note.title) {
            note.updatedAt = Date()
        }
    }
}

#Preview {
    NoteEditorView(note: Note(title: "Sample Note", bodyMarkdown: "Hello world, this is a test."))
        .frame(width: 500, height: 400)
}
