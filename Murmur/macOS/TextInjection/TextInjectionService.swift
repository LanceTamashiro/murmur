import AppKit
import os.log
import TextInjection

private let logger = Logger(subsystem: "com.unconventionalpsychotherapy.murmur", category: "TextInjection")

@MainActor
final class TextInjectionService {
    private let axInjector = AXTextInjector()
    private let clipboardInjector = ClipboardFallbackInjector()
    let appContextDetector: AppContextDetector

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    init(appContextDetector: AppContextDetector) {
        self.appContextDetector = appContextDetector
    }

    func inject(text: String) async -> InjectionResult {
        // Capture target app context upfront (may change during async work)
        guard let targetContext = appContextDetector.currentAppContext else {
            logger.warning("inject: no frontmost app context — skipping")
            return .skipped(reason: .noFocusedTextField)
        }
        logger.info("inject: target app = \(targetContext.displayName) (pid=\(targetContext.processID)), AX=\(self.hasAccessibilityPermission)")

        // Try accessibility injection first
        if hasAccessibilityPermission {
            let result = axInjector.inject(text: text)
            logger.info("inject: AX result = \(String(describing: result))")
            switch result {
            case .success:
                return result
            case .failed, .skipped:
                // Fall through to clipboard
                break
            }
        }

        // Re-activate target app before clipboard paste (focus may have drifted)
        if let targetApp = NSRunningApplication(processIdentifier: targetContext.processID) {
            logger.info("inject: re-activating \(targetContext.displayName) before paste")
            targetApp.activate()
            try? await Task.sleep(for: .milliseconds(100))
        }

        // Clipboard fallback
        let clipResult = await clipboardInjector.inject(text: text)
        logger.info("inject: clipboard result = \(String(describing: clipResult))")
        return clipResult
    }

    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
