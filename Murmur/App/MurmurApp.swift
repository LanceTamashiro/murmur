import SwiftUI
import SwiftData
import Models

@main
struct MurmurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var dictationViewModel = DictationViewModel()

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema(SchemaV1.models)
            let configuration = ModelConfiguration(
                "Murmur",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: MurmurMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted {
                    ContentView()
                        .task {
                            appDelegate.setup(
                                modelContainer: modelContainer,
                                dictationViewModel: dictationViewModel
                            )
                        }
                } else {
                    OnboardingView()
                }
            }
            .environment(dictationViewModel)
        }
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}
