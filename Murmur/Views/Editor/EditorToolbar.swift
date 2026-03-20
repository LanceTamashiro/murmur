import SwiftUI
import AppKit
import Models

struct EditorToolbar: View {
    let note: Note
    @State private var showCopied = false

    var body: some View {
        HStack {
            Text("\(note.wordCount) words")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\u{00B7}")
                .foregroundStyle(.quaternary)
            Text("\(note.characterCount) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: copyToClipboard) {
                Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(note.bodyMarkdown.isEmpty)
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
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
