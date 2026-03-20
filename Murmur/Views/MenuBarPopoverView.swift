import SwiftUI
import SwiftData
import Models

struct MenuBarPopoverView: View {
    var onStartDictating: () -> Void = {}
    var onOpenLibrary: () -> Void = {}
    @AppStorage("clinicalMode") private var clinicalMode = true
    @Query(
        filter: #Predicate<Note> { !$0.isTrashed },
        sort: \Note.createdAt,
        order: .reverse
    )
    private var recentNotes: [Note]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Murmur")
                    .font(.headline)
                if clinicalMode {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.shield")
                            .font(.caption2)
                        Text("Clinical")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                }
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
            }
            .padding()

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

                if recentNotes.prefix(5).isEmpty {
                    Text("No dictations yet")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(recentNotes.prefix(5)) { note in
                                RecentDictationRow(note: note)
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
        .frame(width: 340, height: 480)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

struct RecentDictationRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.bodyMarkdown.prefix(80))
                .font(.callout)
                .lineLimit(2)
                .foregroundStyle(.primary)
            HStack(spacing: 4) {
                Text(note.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let sourceApp = note.sourceApp {
                    Text("→ \(sourceApp)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("\(note.wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
        .contentShape(Rectangle())
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(note.bodyMarkdown, forType: .string)
        }
    }
}

#Preview {
    MenuBarPopoverView()
        .modelContainer(for: Note.self, inMemory: true)
}
