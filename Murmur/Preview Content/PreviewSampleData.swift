import SwiftData
import Models

@MainActor
let previewContainer: ModelContainer = {
    let schema = Schema(SchemaV1.models)
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    let sampleNotes = [
        Note(bodyMarkdown: "Discussed the Q1 roadmap and team priorities for the next sprint."),
        Note(bodyMarkdown: "Remember to follow up with Sarah about the documentation review."),
        Note(bodyMarkdown: "Progress on CBT exercises. Client reports improved sleep patterns."),
    ]

    for note in sampleNotes {
        container.mainContext.insert(note)
    }

    return container
}()
