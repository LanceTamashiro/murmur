import AppKit
import TextInjection

@MainActor
final class AppContextDetector: ObservableObject {
    @Published private(set) var currentAppContext: AppContext?

    private var contextContinuation: AsyncStream<AppContext?>.Continuation?
    let appContextChanges: AsyncStream<AppContext?>

    init() {
        var cont: AsyncStream<AppContext?>.Continuation?
        appContextChanges = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { cont = $0 }
        contextContinuation = cont

        updateContext()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in
                self.updateContext()
            }
        }
    }

    private func updateContext() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            currentAppContext = nil
            contextContinuation?.yield(nil)
            return
        }

        // Skip if Murmur itself is frontmost — preserve the last external app as
        // the injection target. Murmur uses non-activating panels but may still
        // become frontmost on launch or during certain system events.
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }

        let context = AppContext(
            bundleIdentifier: frontApp.bundleIdentifier ?? "unknown",
            displayName: frontApp.localizedName ?? "Unknown",
            processID: frontApp.processIdentifier
        )
        currentAppContext = context
        contextContinuation?.yield(context)
    }
}
