import AppKit
import os.log

private let logger = Logger(subsystem: "com.unconventionalpsychotherapy.murmur", category: "HotkeyMonitor")

@MainActor
final class GlobalHotkeyMonitor {
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var fnKeyIsDown = false
    private var onFnDown: (() -> Void)?
    private var onFnUp: (() -> Void)?
    private var onToggle: (() -> Void)?

    /// Whether accessibility permission is granted (required for global event monitoring)
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Start monitoring for push-to-talk and toggle hotkey.
    /// - Parameters:
    ///   - onFnDown: Called when Fn key is pressed down (start dictation)
    ///   - onFnUp: Called when Fn key is released (stop dictation)
    ///   - onToggle: Called when Cmd+Shift+Space is pressed (toggle dictation)
    func start(
        onFnDown: @escaping () -> Void,
        onFnUp: @escaping () -> Void,
        onToggle: @escaping () -> Void
    ) {
        self.onFnDown = onFnDown
        self.onFnUp = onFnUp
        self.onToggle = onToggle

        if !AXIsProcessTrusted() {
            logger.warning("Accessibility permission not granted — global hotkey monitoring (Globe key) will not work. Only local events within the app will be captured.")
        } else {
            logger.info("Accessibility permission granted — global hotkey monitoring active")
        }

        // Fn key monitoring (flagsChanged) — works if Globe key set to "Do Nothing"
        // NOTE: addGlobalMonitorForEvents requires accessibility permission to work.
        // Without it, the closure is never called for events outside the app.
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
            return event
        }

        // Cmd+Shift+Space monitoring (keyDown) — reliable fallback hotkey
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyDown(event)
            }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyDown(event)
            }
            return event
        }

        logger.info("Hotkey monitoring started (Globe key + Cmd+Shift+Space)")
    }

    /// Convenience: start with toggle-only (no push-to-talk).
    func start(onToggle: @escaping () -> Void) {
        start(onFnDown: {}, onFnUp: {}, onToggle: onToggle)
    }

    func stop() {
        for monitor in [globalFlagsMonitor, localFlagsMonitor, globalKeyMonitor, localKeyMonitor] {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
        globalKeyMonitor = nil
        localKeyMonitor = nil
        onFnDown = nil
        onFnUp = nil
        onToggle = nil
    }

    // MARK: - Fn Key (Push-to-Talk)

    private func handleFlagsChanged(_ event: NSEvent) {
        // Log all flagsChanged events for debugging (keyCode helps identify which key)
        logger.debug("flagsChanged: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)")

        // keyCode 63 is specifically the Fn/Globe key
        guard event.keyCode == 63 else { return }

        let fnPressed = event.modifierFlags.contains(.function)

        if fnPressed && !fnKeyIsDown {
            fnKeyIsDown = true
            logger.info("Globe key DOWN — starting dictation")
            onFnDown?()
        } else if !fnPressed && fnKeyIsDown {
            fnKeyIsDown = false
            logger.info("Globe key UP — stopping dictation")
            onFnUp?()
        }
    }

    // MARK: - Cmd+Shift+Space (Toggle)

    private func handleKeyDown(_ event: NSEvent) {
        // keyCode 49 = Space bar
        guard event.keyCode == 49 else { return }

        let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]
        let currentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check Cmd+Shift are held, and no other modifiers (option, control)
        if currentFlags.contains(requiredFlags) &&
            !currentFlags.contains(.option) &&
            !currentFlags.contains(.control) {
            onToggle?()
        }
    }
}
