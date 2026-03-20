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
        // Resolve target: prefer tracked context, fall back to current frontmost (excluding Murmur)
        let targetContext: AppContext
        if let tracked = appContextDetector.currentAppContext {
            targetContext = tracked
        } else if let frontApp = NSWorkspace.shared.frontmostApplication,
                  frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetContext = AppContext(
                bundleIdentifier: frontApp.bundleIdentifier ?? "unknown",
                displayName: frontApp.localizedName ?? "Unknown",
                processID: frontApp.processIdentifier
            )
        } else {
            logger.warning("inject: no external target app — skipping")
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

        // CGEvent.post requires accessibility — without it, Cmd+V is silently dropped
        if !hasAccessibilityPermission {
            logger.error("inject: accessibility permission required for Cmd+V paste — grant in System Settings > Privacy > Accessibility")
            return .skipped(reason: .noAccessibilityPermission)
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

    /// Prompt the user for accessibility permission, open System Settings,
    /// and poll for up to `timeout` seconds. Returns true if permission was granted.
    func requestAccessibilityAndWait(timeout: TimeInterval = 8.0) async -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let alreadyTrusted = AXIsProcessTrustedWithOptions(options)
        if alreadyTrusted { return true }

        openAccessibilityPreferences()

        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(for: .milliseconds(500))
            if AXIsProcessTrusted() {
                logger.info("requestAccessibilityAndWait: permission granted after \(Date().timeIntervalSince(start))s")
                return true
            }
        }

        logger.warning("requestAccessibilityAndWait: timed out after \(timeout)s — permission still not granted")
        return false
    }

    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
