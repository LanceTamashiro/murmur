import AppKit
import os.log

private let logger = Logger(subsystem: "com.unconventionalpsychotherapy.murmur", category: "HotkeyMonitor")

/// Configurable push-to-talk trigger key for hold-to-dictate mode.
enum TriggerKey: String, CaseIterable, Sendable {
    case fn = "fn"
    case rightOption = "rightOption"
    case rightCommand = "rightCommand"
    case capsLock = "capsLock"

    var displayName: String {
        switch self {
        case .fn: "Fn (Globe)"
        case .rightOption: "Right Option"
        case .rightCommand: "Right Command"
        case .capsLock: "Caps Lock"
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .fn: 63
        case .rightOption: 61
        case .rightCommand: 54
        case .capsLock: 57
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .fn: .function
        case .rightOption: .option
        case .rightCommand: .command
        case .capsLock: .capsLock
        }
    }
}

@MainActor
final class GlobalHotkeyMonitor {
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var triggerKeyIsDown = false
    private var triggerPressTime: Date?
    private var triggerKey: TriggerKey = .fn
    private var onFnDown: (() -> Void)?
    private var onFnUp: (() -> Void)?
    private var onFnCancel: (() -> Void)?
    private var onToggle: (() -> Void)?

    /// Minimum hold duration (seconds) to prevent accidental triggers.
    private static let minimumHoldDuration: TimeInterval = 0.3

    /// Whether accessibility permission is granted (required for global event monitoring)
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Start monitoring for push-to-talk and toggle hotkey.
    /// - Parameters:
    ///   - triggerKey: The key used for push-to-talk (default: Fn/Globe)
    ///   - onFnDown: Called when trigger key is pressed down (start dictation)
    ///   - onFnUp: Called when trigger key is released after ≥300ms (stop dictation)
    ///   - onFnCancel: Called when trigger key is released before 300ms (cancel dictation)
    ///   - onToggle: Called when Cmd+Shift+Space is pressed (toggle dictation)
    func start(
        triggerKey: TriggerKey = .fn,
        onFnDown: @escaping () -> Void,
        onFnUp: @escaping () -> Void,
        onFnCancel: @escaping () -> Void = {},
        onToggle: @escaping () -> Void
    ) {
        self.triggerKey = triggerKey
        self.onFnDown = onFnDown
        self.onFnUp = onFnUp
        self.onFnCancel = onFnCancel
        self.onToggle = onToggle

        if !AXIsProcessTrusted() {
            logger.warning("Accessibility permission not granted — global hotkey monitoring (\(triggerKey.displayName)) will not work. Only local events within the app will be captured.")
        } else {
            logger.info("Accessibility permission granted — global hotkey monitoring active")
        }

        // Trigger key monitoring (flagsChanged) — modifier keys fire flagsChanged, not keyDown
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

        logger.info("Hotkey monitoring started (\(triggerKey.displayName) + Cmd+Shift+Space)")
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
        onFnCancel = nil
        onToggle = nil
    }

    // MARK: - Trigger Key (Push-to-Talk)

    private func handleFlagsChanged(_ event: NSEvent) {
        logger.debug("flagsChanged: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)")

        guard event.keyCode == triggerKey.keyCode else { return }

        let keyPressed = event.modifierFlags.contains(triggerKey.modifierFlag)

        if keyPressed && !triggerKeyIsDown {
            triggerKeyIsDown = true
            triggerPressTime = Date()
            logger.info("\(self.triggerKey.displayName) DOWN — starting dictation")
            onFnDown?()
        } else if !keyPressed && triggerKeyIsDown {
            triggerKeyIsDown = false
            let holdDuration = triggerPressTime.map { Date().timeIntervalSince($0) } ?? 0
            triggerPressTime = nil
            if holdDuration >= Self.minimumHoldDuration {
                logger.info("\(self.triggerKey.displayName) UP — stopping dictation (held \(String(format: "%.0f", holdDuration * 1000))ms)")
                onFnUp?()
            } else {
                logger.info("\(self.triggerKey.displayName) UP — cancelling (held \(String(format: "%.0f", holdDuration * 1000))ms < 300ms minimum)")
                onFnCancel?()
            }
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
