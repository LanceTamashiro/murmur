import SwiftUI

/// Read-only rendered Markdown preview using `AttributedString`.
///
/// Displays headings, bold, italic, code, lists, and links.
/// Designed to sit alongside the TextEditor in a split view.
struct MarkdownPreviewView: View {
    let markdown: String

    private var rendered: AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(markdown)
    }

    var body: some View {
        ScrollView {
            Text(rendered)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }
}

#Preview {
    MarkdownPreviewView(markdown: """
    # Heading

    This is **bold** and *italic* text.

    - Bullet one
    - Bullet two

    Some `inline code` here.
    """)
    .frame(width: 400, height: 300)
}
