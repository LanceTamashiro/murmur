import AppKit
import TextInjection

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
        // Check if there's a frontmost app to inject into
        guard appContextDetector.currentAppContext != nil else {
            return .skipped(reason: .noFocusedTextField)
        }

        // Try accessibility injection first
        if hasAccessibilityPermission {
            let result = axInjector.inject(text: text)
            switch result {
            case .success:
                return result
            case .failed, .skipped:
                // Fall through to clipboard
                break
            }
        }

        // Clipboard fallback
        return await clipboardInjector.inject(text: text)
    }

    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
