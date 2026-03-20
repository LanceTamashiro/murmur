import SwiftUI
import SwiftData
import Models

struct TrashView: View {
    @Query(
        filter: #Predicate<Note> { $0.isTrashed },
        sort: \Note.trashedAt,
        order: .reverse
    )
    private var trashedNotes: [Note]

    @Environment(\.modelContext) private var modelContext
    @State private var showEmptyTrashConfirmation = false

    var body: some View {
        List {
            ForEach(trashedNotes) { note in
                TrashRowView(note: note)
                    .contextMenu {
                        Button("Restore") {
                            restoreNote(note)
                        }
                        Divider()
                        Button("Delete Permanently", role: .destructive) {
                            deleteNote(note)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            restoreNote(note)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteNote(note)
                        } label: {
                            Label("Delete", systemImage: "trash.slash")
                        }
                    }
            }
        }
        .navigationTitle("Trash")
        .toolbar {
            ToolbarItem {
                Button("Empty Trash", role: .destructive) {
                    showEmptyTrashConfirmation = true
                }
                .disabled(trashedNotes.isEmpty)
            }
        }
        .alert("Empty Trash?", isPresented: $showEmptyTrashConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Empty Trash", role: .destructive) {
                emptyTrash()
            }
        } message: {
            Text("This will permanently delete \(trashedNotes.count) note\(trashedNotes.count == 1 ? "" : "s"). This cannot be undone.")
        }
        .overlay {
            if trashedNotes.isEmpty {
                ContentUnavailableView(
                    "Trash is Empty",
                    systemImage: "trash",
                    description: Text("Notes you delete will appear here.")
                )
            }
        }
    }

    private func restoreNote(_ note: Note) {
        note.isTrashed = false
        note.trashedAt = nil
        note.updatedAt = Date()
    }

    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
    }

    private func emptyTrash() {
        for note in trashedNotes {
            modelContext.delete(note)
        }
    }
}

struct TrashRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let trashedAt = note.trashedAt {
                Text("Deleted \(trashedAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(note.bodyMarkdown.isEmpty ? "Empty Note" : String(note.bodyMarkdown.prefix(100)))
                .font(.callout)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}
