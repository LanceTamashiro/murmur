import SwiftUI
import SwiftData
import Models

enum SidebarDestination: Hashable {
    case notes
    case trash
}

struct ContentView: View {
    @State private var selectedNoteID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var sidebarDestination: SidebarDestination = .notes

    @Query(filter: #Predicate<Note> { $0.isTrashed })
    private var trashedNotes: [Note]

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("View", selection: $sidebarDestination) {
                    Label("Notes", systemImage: "note.text")
                        .tag(SidebarDestination.notes)
                    Label("Trash", systemImage: "trash")
                        .tag(SidebarDestination.trash)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch sidebarDestination {
                case .notes:
                    NoteListView(selectedNoteID: $selectedNoteID, searchText: $searchText)
                case .trash:
                    TrashView()
                }
            }
        } detail: {
            if sidebarDestination == .notes, let selectedNoteID {
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
