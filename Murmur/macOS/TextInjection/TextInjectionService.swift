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

        let axTrusted = hasAccessibilityPermission
        logger.info("inject: target app = \(targetContext.displayName) (pid=\(targetContext.processID)), AX=\(axTrusted)")

        // Reactivate the target app BEFORE any injection attempt.
        // Murmur's HUD or main window may have taken focus — the target app
        // must be frontmost for both AX and clipboard injection to work.
        if let targetApp = NSRunningApplication(processIdentifier: targetContext.processID) {
            logger.info("inject: re-activating \(targetContext.displayName) before injection")
            targetApp.activate()
            try? await Task.sleep(for: .milliseconds(300))
        }

        // Try AX direct injection, targeting the specific app by PID.
        // AXIsProcessTrusted() can return stale false in Xcode debug builds
        // even when permission is granted — the AX API calls return proper errors.
        let axResult = axInjector.inject(text: text, targetPID: targetContext.processID)
        logger.info("inject: AX result = \(String(describing: axResult))")
        if case .success = axResult {
            return axResult
        }

        // Clipboard paste (Cmd+V via CGEvent.post) — always attempt as fallback.
        // With proper code signing, AXIsProcessTrusted() is reliable. CGEvent.post
        // silently drops events without permission, but that's caught by the final
        // clipboard-copy fallback below.
        let clipResult = await clipboardInjector.inject(text: text)
        logger.info("inject: clipboard paste result = \(String(describing: clipResult))")
        if case .success = clipResult {
            return clipResult
        }

        // Fallback: copy text to clipboard without auto-pasting.
        // NSPasteboard requires no special permissions — always works.
        logger.info("inject: injection failed (AX=\(axTrusted)) — copying to clipboard only")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return .success(strategy: .clipboardCopy)
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
