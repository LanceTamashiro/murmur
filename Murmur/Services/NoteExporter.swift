import AppKit
import Models
import os.log
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "com.unconventionalpsychotherapy.murmur", category: "NoteExporter")

enum ExportFormat: String, CaseIterable {
    case markdown = "Markdown"
    case plainText = "Plain Text"
    case pdf = "PDF"

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .pdf: return "pdf"
        }
    }

    var utType: UTType {
        switch self {
        case .markdown: return .init(filenameExtension: "md") ?? .plainText
        case .plainText: return .plainText
        case .pdf: return .pdf
        }
    }
}

@MainActor
struct NoteExporter {

    static func export(note: Note, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.title = "Export Note"
        panel.nameFieldStringValue = sanitizedFilename(for: note) + "." + format.fileExtension
        panel.allowedContentTypes = [format.utType]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            switch format {
            case .markdown:
                try note.bodyMarkdown.write(to: url, atomically: true, encoding: .utf8)

            case .plainText:
                let plainText = stripMarkdown(note.bodyMarkdown)
                try plainText.write(to: url, atomically: true, encoding: .utf8)

            case .pdf:
                let pdfData = renderPDF(text: note.bodyMarkdown, title: note.title)
                try pdfData.write(to: url, options: .atomic)
            }

            logger.info("Exported note as \(format.rawValue) to \(url.path)")
        } catch {
            logger.error("Export failed: \(error)")
        }
    }

    static func share(note: Note, from view: NSView) {
        let items: [Any] = [note.bodyMarkdown]
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    // MARK: - Internal (for testing)

    static func sanitizedFilename(for note: Note) -> String {
        let title = note.title
        let cleaned = title.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return cleaned.isEmpty ? "note" : String(cleaned.prefix(50))
    }

    static func stripMarkdown(_ text: String) -> String {
        var result = text
        // Remove headers
        result = result.replacingOccurrences(of: "#{1,6}\\s+", with: "", options: .regularExpression)
        // Remove bold/italic markers
        result = result.replacingOccurrences(of: "[*_]{1,3}", with: "", options: .regularExpression)
        // Remove inline code backticks
        result = result.replacingOccurrences(of: "`", with: "")
        // Remove link syntax [text](url) → text
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        return result
    }

    static func renderPDF(text: String, title: String) -> Data {
        let pageWidth: CGFloat = 612 // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 72 // 1 inch

        let textRect = CGRect(
            x: margin, y: margin,
            width: pageWidth - 2 * margin,
            height: pageHeight - 2 * margin
        )

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: NSColor.labelColor
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]

        let fullText = NSMutableAttributedString()
        fullText.append(NSAttributedString(string: title + "\n\n", attributes: titleAttributes))
        fullText.append(NSAttributedString(string: text, attributes: bodyAttributes))

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            logger.error("Failed to create PDF context")
            return Data()
        }

        // Use NSTextStorage + NSLayoutManager for pagination
        let textStorage = NSTextStorage(attributedString: fullText)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        var pageOrigin = CGPoint.zero
        var done = false
        let maxPages = 100

        while !done {
            let textContainer = NSTextContainer(size: textRect.size)
            layoutManager.addTextContainer(textContainer)

            let glyphRange = layoutManager.glyphRange(for: textContainer)
            if glyphRange.length == 0 { break }

            context.beginPDFPage(nil)

            // Flip coordinate system for text drawing
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext

            // Draw in a flipped coordinate space
            context.saveGState()
            context.translateBy(x: margin, y: pageHeight - margin)
            context.scaleBy(x: 1.0, y: -1.0)

            layoutManager.drawBackground(forGlyphRange: glyphRange, at: pageOrigin)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: pageOrigin)

            context.restoreGState()
            NSGraphicsContext.restoreGraphicsState()

            context.endPDFPage()

            // Check if we're done (all glyphs laid out)
            let lastGlyph = NSMaxRange(glyphRange)
            if lastGlyph >= layoutManager.numberOfGlyphs {
                done = true
            }

            // Safety: prevent infinite loop on malformed text
            if layoutManager.textContainers.count >= maxPages {
                logger.warning("PDF export hit \(maxPages)-page limit, truncating")
                break
            }
        }

        context.closePDF()
        return pdfData as Data
    }
}
