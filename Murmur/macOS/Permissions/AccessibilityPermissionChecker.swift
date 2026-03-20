import AppKit

@MainActor
@Observable
final class AccessibilityPermissionChecker {
    var isGranted: Bool = false
    private var pollTask: Task<Void, Never>?

    init() {
        isGranted = AXIsProcessTrusted()
    }

    func startPolling() {
        pollTask = Task {
            while !Task.isCancelled {
                let trusted = AXIsProcessTrusted()
                if trusted != isGranted {
                    isGranted = trusted
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
