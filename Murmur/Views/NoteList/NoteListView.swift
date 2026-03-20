import SwiftUI
import SwiftData
import Models

struct NoteListView: View {
    @Query(filter: #Predicate<Note> { !$0.isTrashed }, sort: \Note.updatedAt, order: .reverse)
    private var notes: [Note]

    @Binding var selectedNoteID: PersistentIdentifier?
    @Binding var searchText: String
    @Environment(\.modelContext) private var modelContext

    private var filteredNotes: [Note] {
        if searchText.isEmpty { return notes }
        return notes.filter {
            $0.bodyMarkdown.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(selection: $selectedNoteID) {
            ForEach(filteredNotes) { note in
                NoteRowView(note: note)
                    .tag(note.persistentModelID)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            trashNote(note)
                        } label: {
                            Label("Trash", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(note.isPinned ? "Unpin" : "Pin") {
                            note.isPinned.toggle()
                            note.updatedAt = Date()
                        }
                        Divider()
                        Button("Move to Trash", role: .destructive) {
                            trashNote(note)
                        }
                    }
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem {
                Button(action: createNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n")
            }
        }
        .overlay {
            if filteredNotes.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Create a new note or start dictating.")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private func createNote() {
        let note = Note(bodyMarkdown: "")
        modelContext.insert(note)
        selectedNoteID = note.persistentModelID
    }

    private func trashNote(_ note: Note) {
        note.isTrashed = true
        note.trashedAt = Date()
        if selectedNoteID == note.persistentModelID {
            selectedNoteID = nil
        }
    }
}
