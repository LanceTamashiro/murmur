import SwiftUI
import SwiftData
import Models

struct ContentView: View {
    @State private var selectedNoteID: PersistentIdentifier?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            NoteListView(selectedNoteID: $selectedNoteID, searchText: $searchText)
        } detail: {
            if let selectedNoteID {
                NoteDetailView(noteID: selectedNoteID)
            } else {
                ContentUnavailableView(
                    "No Note Selected",
                    systemImage: "note.text",
                    description: Text("Select a note from the sidebar or create a new one.")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search notes")
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct NoteDetailView: View {
    let noteID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let note: Note = modelContext.registeredModel(for: noteID) {
            NoteEditorView(note: note)
        } else {
            ContentUnavailableView("Note not found", systemImage: "exclamationmark.triangle")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}
