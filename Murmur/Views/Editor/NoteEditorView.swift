import SwiftUI
import Models

struct NoteEditorView: View {
    @Bindable var note: Note
    @AppStorage("editorMode") private var editorMode = "source"

    var body: some View {
        VStack(spacing: 0) {
            if editorMode == "split" {
                HSplitView {
                    TextEditor(text: $note.bodyMarkdown)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .scrollContentBackground(.hidden)

                    MarkdownPreviewView(markdown: note.bodyMarkdown)
                        .frame(minWidth: 200)
                }
            } else {
                TextEditor(text: $note.bodyMarkdown)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .scrollContentBackground(.hidden)
            }

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
