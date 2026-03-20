import SwiftUI
import SwiftData
import Models

struct DictionarySettingsView: View {
    @Query(sort: \DictionaryEntry.canonicalForm)
    private var entries: [DictionaryEntry]

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var editingEntry: DictionaryEntry?

    private var filteredEntries: [DictionaryEntry] {
        if searchText.isEmpty { return entries }
        return entries.filter {
            $0.canonicalForm.localizedCaseInsensitiveContains(searchText)
            || ($0.phoneticForm?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if entries.isEmpty && searchText.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Custom Words",
                    systemImage: "text.badge.plus",
                    description: Text("Add words to improve transcription accuracy.")
                )
                Button("Add Word") { showingAddSheet = true }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                Spacer()
            } else {
                HStack {
                    TextField("Search words…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

                List {
                    ForEach(filteredEntries) { entry in
                        DictionaryEntryRow(entry: entry)
                            .contextMenu {
                                Button("Edit") { editingEntry = entry }
                                Button(entry.isSuppressed ? "Enable" : "Suppress") {
                                    entry.isSuppressed.toggle()
                                    try? modelContext.save()
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    modelContext.delete(entry)
                                    try? modelContext.save()
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(entry)
                                    try? modelContext.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    entry.isSuppressed.toggle()
                                    try? modelContext.save()
                                } label: {
                                    Label(
                                        entry.isSuppressed ? "Enable" : "Suppress",
                                        systemImage: entry.isSuppressed ? "checkmark.circle" : "minus.circle"
                                    )
                                }
                                .tint(entry.isSuppressed ? .green : .orange)
                            }
                    }

                    if filteredEntries.isEmpty && !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            DictionaryEntryFormView { newEntry in
                modelContext.insert(newEntry)
                try? modelContext.save()
            }
        }
        .sheet(item: $editingEntry) { entry in
            DictionaryEntryFormView(entry: entry) { _ in
                try? modelContext.save()
            }
        }
    }
}

// MARK: - Entry Row

private struct DictionaryEntryRow: View {
    let entry: DictionaryEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.canonicalForm)
                        .fontWeight(.medium)
                        .opacity(entry.isSuppressed ? 0.5 : 1)
                    if entry.isSuppressed {
                        Text("Suppressed")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.2))
                            .clipShape(Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                if let phonetic = entry.phoneticForm, !phonetic.isEmpty {
                    Text("/" + phonetic + "/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !entry.alternativeForms.isEmpty {
                    Text("Also: " + entry.alternativeForms.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let language = entry.language, !language.isEmpty {
                Text(language)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add/Edit Form

private struct DictionaryEntryFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var canonicalForm: String
    @State private var phoneticForm: String
    @State private var alternativeFormsText: String
    @State private var language: String

    private let existingEntry: DictionaryEntry?
    private let onSave: (DictionaryEntry) -> Void

    init(entry: DictionaryEntry? = nil, onSave: @escaping (DictionaryEntry) -> Void) {
        self.existingEntry = entry
        self.onSave = onSave
        _canonicalForm = State(initialValue: entry?.canonicalForm ?? "")
        _phoneticForm = State(initialValue: entry?.phoneticForm ?? "")
        _alternativeFormsText = State(initialValue: entry?.alternativeForms.joined(separator: ", ") ?? "")
        _language = State(initialValue: entry?.language ?? "")
    }

    private var isEditing: Bool { existingEntry != nil }
    private var canSave: Bool { !canonicalForm.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Word" : "Add Word")
                .font(.headline)
                .padding()

            Form {
                TextField("Word or Phrase", text: $canonicalForm)
                TextField("Phonetic Form (optional)", text: $phoneticForm)
                TextField("Alternative Forms (comma-separated)", text: $alternativeFormsText)
                TextField("Language (e.g. en-US)", text: $language)
            }
            .padding(.horizontal)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 380)
    }

    private func save() {
        let trimmedCanonical = canonicalForm.trimmingCharacters(in: .whitespaces)
        let alternatives = alternativeFormsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let trimmedPhonetic = phoneticForm.trimmingCharacters(in: .whitespaces)
        let trimmedLanguage = language.trimmingCharacters(in: .whitespaces)

        if let existing = existingEntry {
            existing.canonicalForm = trimmedCanonical
            existing.phoneticForm = trimmedPhonetic.isEmpty ? nil : trimmedPhonetic
            existing.alternativeForms = alternatives
            existing.language = trimmedLanguage.isEmpty ? nil : trimmedLanguage
            onSave(existing)
        } else {
            let entry = DictionaryEntry(
                canonicalForm: trimmedCanonical,
                phoneticForm: trimmedPhonetic.isEmpty ? nil : trimmedPhonetic,
                alternativeForms: alternatives,
                language: trimmedLanguage.isEmpty ? nil : trimmedLanguage
            )
            onSave(entry)
        }
    }
}
