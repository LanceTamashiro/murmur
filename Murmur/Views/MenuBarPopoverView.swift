import SwiftUI
import SwiftData
import AppKit
import Models

struct MenuBarPopoverView: View {
    var onStartDictating: () -> Void = {}
    var onOpenLibrary: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Note> { !$0.isTrashed },
        sort: \Note.createdAt,
        order: .reverse
    )
    private var recentNotes: [Note]

    @State private var quickNoteText = ""
    @State private var showQuickNote = false
    @FocusState private var quickNoteFocused: Bool
    @State private var selectedNote: Note?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Murmur")
                        .font(.headline)
                    HStack(spacing: 3) {
                        Image(systemName: "lock.shield")
                            .font(.caption2)
                        Text("On-Device")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                    Spacer()
                    Button(action: { showQuickNote.toggle() }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
                    .help("Quick Note")
                    Button(action: openSettings) {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                // Quick Note input
                if showQuickNote {
                    VStack(spacing: 8) {
                        TextEditor(text: $quickNoteText)
                            .font(.body)
                            .frame(height: 60)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                            .focused($quickNoteFocused)
                        HStack {
                            Spacer()
                            Button("Save") {
                                saveQuickNote()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.return, modifiers: .command)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .onAppear { quickNoteFocused = true }
                }

                Divider()

                // Dictation toggle
                Button(action: onStartDictating) {
                    Label("Start Dictating", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()

                Divider()

                // Recent dictations
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Dictations")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if recentNotes.prefix(50).isEmpty {
                        Text("No dictations yet")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(recentNotes.prefix(50)) { note in
                                    RecentDictationRow(note: note) {
                                        selectedNote = note
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Spacer()

                Divider()

                // Footer
                HStack {
                    Text("Hold Fn or ⌘⇧Space")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Notes Library", action: onOpenLibrary)
                        .buttonStyle(.link)
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationDestination(item: $selectedNote) { note in
                NotePreviewView(note: note, onOpenLibrary: onOpenLibrary)
            }
        }
        .frame(width: 340, height: 480)
    }

    private func saveQuickNote() {
        let text = quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let note = Note(bodyMarkdown: text)
        modelContext.insert(note)
        try? modelContext.save()

        quickNoteText = ""
        showQuickNote = false
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

// MARK: - Note Preview View

private struct NotePreviewView: View {
    let note: Note
    var onOpenLibrary: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(note.bodyMarkdown)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Divider()

            // Metadata + actions bar
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(relativeTimeString(note.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("\(note.wordCount) words")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if let sourceApp = note.sourceApp {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 7))
                                .foregroundStyle(.tertiary)
                            Text(friendlyAppName(sourceApp))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                Button(action: trashNote) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Move to Trash")

                Button(action: copyToClipboard) {
                    Label(
                        showCopied ? "Copied!" : "Copy",
                        systemImage: showCopied ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: onOpenLibrary) {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .help("Open in Notes Library")
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.bodyMarkdown, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }

    private func trashNote() {
        note.isTrashed = true
        note.trashedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Recent Dictation Row

struct RecentDictationRow: View {
    let note: Note
    var onSelect: () -> Void = {}
    @State private var showCopied = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.bodyMarkdown.prefix(80))
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text(relativeTimeString(note.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let sourceApp = note.sourceApp {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                        Text(friendlyAppName(sourceApp))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("\(note.wordCount) words")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Button(action: copyToClipboard) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(showCopied ? .green : .secondary)
                    .font(.caption)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.bodyMarkdown, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}

// MARK: - Helpers

func relativeTimeString(_ date: Date) -> String {
    let now = Date()
    let interval = now.timeIntervalSince(date)

    if interval < 60 {
        return "Just now"
    } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes) min ago"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
    } else if interval < 172800 {
        return "Yesterday"
    } else {
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

func friendlyAppName(_ bundleID: String) -> String {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
        return url.deletingPathExtension().lastPathComponent
    }
    // Fallback: last component of bundle ID
    let components = bundleID.split(separator: ".")
    if let last = components.last {
        return String(last).capitalized
    }
    return bundleID
}

// MARK: - Hashable conformance for Note navigation

extension Note: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    MenuBarPopoverView()
        .modelContainer(for: Note.self, inMemory: true)
}
