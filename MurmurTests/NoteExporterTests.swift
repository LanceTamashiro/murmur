import Testing
import Foundation
import SwiftData
@testable import Murmur
@testable import Models

@MainActor
@Suite("NoteExporter", .serialized)
struct NoteExporterTests {

    private func makeNote(body: String) throws -> Note {
        let note = Note(bodyMarkdown: body)
        return note
    }

    // MARK: - Filename Sanitization

    @Test("Sanitizes normal title")
    func sanitizesNormalTitle() throws {
        let note = try makeNote(body: "Meeting notes for Monday")
        let filename = NoteExporter.sanitizedFilename(for: note)
        #expect(filename == "Meeting-notes-for-Monday")
    }

    @Test("Empty body produces 'note' filename")
    func emptyBodyFallback() throws {
        let note = try makeNote(body: "")
        let filename = NoteExporter.sanitizedFilename(for: note)
        #expect(filename == "note")
    }

    @Test("Special characters stripped from filename")
    func specialCharsStripped() throws {
        let note = try makeNote(body: "Hello! @World #2024 (test)")
        let filename = NoteExporter.sanitizedFilename(for: note)
        #expect(!filename.contains("!"))
        #expect(!filename.contains("@"))
        #expect(!filename.contains("#"))
        #expect(!filename.contains("("))
    }

    @Test("Long title truncated to 50 characters")
    func longTitleTruncated() throws {
        let longBody = String(repeating: "abcdefghij ", count: 20)
        let note = try makeNote(body: longBody)
        let filename = NoteExporter.sanitizedFilename(for: note)
        #expect(filename.count <= 50)
    }

    @Test("Path traversal characters stripped")
    func pathTraversalStripped() throws {
        let note = try makeNote(body: "../../../etc/passwd")
        let filename = NoteExporter.sanitizedFilename(for: note)
        #expect(!filename.contains(".."))
        #expect(!filename.contains("/"))
    }

    @Test("Shell metacharacters stripped")
    func shellMetacharsStripped() throws {
        let note = try makeNote(body: "$(whoami) `id` && rm -rf /")
        let filename = NoteExporter.sanitizedFilename(for: note)
        #expect(!filename.contains("$"))
        #expect(!filename.contains("`"))
        #expect(!filename.contains("&"))
    }

    @Test("Null byte in title stripped")
    func nullByteStripped() throws {
        let note = try makeNote(body: "Hello\0World")
        let filename = NoteExporter.sanitizedFilename(for: note)
        #expect(!filename.contains("\0"))
    }

    @Test("Title with only special chars produces 'note'")
    func onlySpecialChars() throws {
        let note = try makeNote(body: "!@#$%^&*()")
        let filename = NoteExporter.sanitizedFilename(for: note)
        #expect(filename == "note")
    }

    // MARK: - Markdown Stripping

    @Test("Strips headers")
    func stripsHeaders() {
        let result = NoteExporter.stripMarkdown("## Hello World")
        #expect(result == "Hello World")
    }

    @Test("Strips bold markers")
    func stripsBold() {
        let result = NoteExporter.stripMarkdown("This is **bold** text")
        #expect(result == "This is bold text")
    }

    @Test("Strips italic markers")
    func stripsItalic() {
        let result = NoteExporter.stripMarkdown("This is *italic* text")
        #expect(result == "This is italic text")
    }

    @Test("Strips inline code backticks")
    func stripsInlineCode() {
        let result = NoteExporter.stripMarkdown("Use `print()` here")
        #expect(result == "Use print() here")
    }

    @Test("Strips link syntax preserving text")
    func stripsLinks() {
        let result = NoteExporter.stripMarkdown("Visit [Google](https://google.com) now")
        #expect(result == "Visit Google now")
    }

    @Test("Strips combined markdown")
    func stripsCombined() {
        let input = "# Title\n\nThis is **bold** and *italic* with `code` and [a link](url)."
        let result = NoteExporter.stripMarkdown(input)
        #expect(result.contains("Title"))
        #expect(result.contains("bold"))
        #expect(result.contains("italic"))
        #expect(result.contains("code"))
        #expect(result.contains("a link"))
        #expect(!result.contains("**"))
        #expect(!result.contains("*"))
        #expect(!result.contains("`"))
        #expect(!result.contains("["))
    }

    @Test("Plain text passes through unchanged")
    func plainTextPassthrough() {
        let input = "Just plain text, nothing fancy."
        #expect(NoteExporter.stripMarkdown(input) == input)
    }

    // MARK: - PDF Rendering

    @Test("PDF renders non-empty data")
    func pdfRendersData() {
        let data = NoteExporter.renderPDF(text: "Hello world", title: "Test")
        #expect(!data.isEmpty)
    }

    @Test("PDF starts with valid header")
    func pdfValidHeader() {
        let data = NoteExporter.renderPDF(text: "Hello world", title: "Test")
        let header = String(data: data.prefix(5), encoding: .ascii)
        #expect(header == "%PDF-")
    }

    @Test("PDF handles empty text")
    func pdfEmptyText() {
        let data = NoteExporter.renderPDF(text: "", title: "Empty")
        // Should still produce valid PDF (with just title)
        #expect(!data.isEmpty)
        let header = String(data: data.prefix(5), encoding: .ascii)
        #expect(header == "%PDF-")
    }

    @Test("PDF handles very long text without hanging")
    func pdfLongText() {
        // 10,000 words should produce multi-page PDF within page limit
        let longText = String(repeating: "This is a test sentence with several words. ", count: 1000)
        let data = NoteExporter.renderPDF(text: longText, title: "Long Document")
        #expect(!data.isEmpty)
        let header = String(data: data.prefix(5), encoding: .ascii)
        #expect(header == "%PDF-")
    }

    // MARK: - ExportFormat

    @Test("Export format file extensions")
    func exportFormatExtensions() {
        #expect(ExportFormat.markdown.fileExtension == "md")
        #expect(ExportFormat.plainText.fileExtension == "txt")
        #expect(ExportFormat.pdf.fileExtension == "pdf")
    }

    @Test("Export format all cases")
    func exportFormatAllCases() {
        #expect(ExportFormat.allCases.count == 3)
    }
}
