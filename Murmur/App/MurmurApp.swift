import SwiftUI
import SwiftData
import Models

@main
struct MurmurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var dictationViewModel = DictationViewModel()

    let modelContainer: ModelContainer

    /// True when running as a test host — detected via XCTest class presence or environment.
    private static var isTestEnvironment: Bool {
        ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTest") != nil
    }

    init() {
        do {
            let schema = Schema(SchemaV1.models)
            let configuration = ModelConfiguration(
                "Murmur",
                schema: schema,
                isStoredInMemoryOnly: MurmurApp.isTestEnvironment
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
                if MurmurApp.isTestEnvironment {
                    // Show nothing when running as a test host — tests create
                    // their own components directly. Rendering ContentView in
                    // the test host triggers SwiftData/SwiftUI crashes.
                    Color.clear
                } else if onboardingCompleted {
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
