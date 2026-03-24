import Testing
import Foundation
import AppKit
import ApplicationServices
@testable import Murmur
@testable import TextInjection

/// Automated test that launches TextEdit, injects text via AX, and verifies it arrived.
/// Requires accessibility permission on the test host (Xcode/xcodebuild).
/// Skips gracefully if AX permission is not granted.
@MainActor
@Suite("Text Injection Tests", .serialized)
struct TextInjectionTests {

    // MARK: - Helpers

    private enum TextEditSetupError: Error, CustomStringConvertible {
        case timeout
        var description: String { "TextEdit did not produce a writable text element within timeout" }
    }

    /// Poll until TextEdit has a focused, AX-writable text element, or throw on timeout.
    private func waitForWritableElement(
        pid: pid_t,
        timeout: Duration = .seconds(8)
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let app = AXUIElementCreateApplication(pid)
            var focused: AnyObject?
            let res = AXUIElementCopyAttributeValue(
                app, kAXFocusedUIElementAttribute as CFString, &focused
            )
            if res == .success, let el = focused {
                let axEl = el as! AXUIElement
                // Check if value attribute exists (text field is present)
                var currentValue: AnyObject?
                let valueRes = AXUIElementCopyAttributeValue(axEl, kAXValueAttribute as CFString, &currentValue)
                if valueRes == .success {
                    // Also check settable
                    var settable: DarwinBoolean = false
                    AXUIElementIsAttributeSettable(axEl, kAXValueAttribute as CFString, &settable)
                    if settable.boolValue {
                        return
                    }
                }
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw TextEditSetupError.timeout
    }

    /// Send Cmd+N keystroke to create a new document.
    private func sendCmdN() {
        let cmdN_Down = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: true)!
        let cmdN_Up = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: false)!
        cmdN_Down.flags = .maskCommand
        cmdN_Up.flags = .maskCommand
        cmdN_Down.post(tap: .cghidEventTap)
        cmdN_Up.post(tap: .cghidEventTap)
    }

    /// Launch TextEdit and ensure it has a writable text field ready for injection.
    private func launchTextEditWithNewDocument() async throws -> NSRunningApplication {
        let url = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        let textEdit = try await NSWorkspace.shared.openApplication(
            at: url,
            configuration: config
        )

        // Wait for TextEdit to launch
        try await Task.sleep(for: .milliseconds(500))

        // Check if TextEdit already has a writable element (reopened a prior doc)
        do {
            try await waitForWritableElement(pid: textEdit.processIdentifier, timeout: .seconds(2))
            return textEdit
        } catch {
            // No writable element yet — send Cmd+N to create a new document
        }

        sendCmdN()

        // Poll for writable element after Cmd+N
        try await waitForWritableElement(pid: textEdit.processIdentifier, timeout: .seconds(5))
        return textEdit
    }

    /// Quietly terminate TextEdit without triggering the "is not open anymore" dialog.
    /// Brings the test host to front first so macOS doesn't warn about losing the active app.
    private func terminateTextEditQuietly(_ textEdit: NSRunningApplication) {
        // Bring test host (Murmur) back to front so TextEdit isn't the active app
        NSApp.activate(ignoringOtherApps: true)
        // Small delay to let activation take effect, then force-terminate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textEdit.forceTerminate()
        }
    }

    /// Inject text with a single retry if the first attempt fails.
    private func injectWithRetry(
        injector: AXTextInjector,
        text: String,
        targetPID: pid_t
    ) async -> InjectionResult {
        let result = injector.inject(text: text, targetPID: targetPID)
        if case .failed = result {
            try? await Task.sleep(for: .milliseconds(500))
            return injector.inject(text: text, targetPID: targetPID)
        }
        return result
    }

    // MARK: - AXTextInjector targets app by PID

    @Test func axInjectorTargetsSpecificAppByPID() async throws {
        guard AXIsProcessTrusted() else { return }

        let textEdit: NSRunningApplication
        do {
            textEdit = try await launchTextEditWithNewDocument()
        } catch {
            // TextEdit launch fails on macOS 26 beta (procNotFound) — skip gracefully
            return
        }
        defer {
            terminateTextEditQuietly(textEdit)
        }

        let injector = AXTextInjector()
        let testText = "Murmur injection test \(UUID().uuidString.prefix(8))"
        let result = await injectWithRetry(injector: injector, text: testText, targetPID: textEdit.processIdentifier)

        #expect(result == .success(strategy: .accessibilityDirect),
                "Expected .success(accessibilityDirect), got \(result)")

        // Verify the text is actually in TextEdit by reading it back via AX
        let targetApp = AXUIElementCreateApplication(textEdit.processIdentifier)
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            targetApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        if focusResult == .success, let element = focusedElement {
            var value: AnyObject?
            AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &value)
            if let textValue = value as? String {
                #expect(textValue.contains(testText),
                        "TextEdit should contain injected text. Got: \(textValue.prefix(100))")
            }
        }
    }

    // MARK: - Full injection flow via TextInjectionService

    @Test func fullInjectionServiceFlowInjectsIntoTextEdit() async throws {
        guard AXIsProcessTrusted() else { return }

        let textEdit: NSRunningApplication
        do {
            textEdit = try await launchTextEditWithNewDocument()
        } catch {
            // TextEdit launch fails on macOS 26 beta (procNotFound) — skip gracefully
            return
        }
        defer {
            terminateTextEditQuietly(textEdit)
        }

        let detector = AppContextDetector()
        let service = TextInjectionService(appContextDetector: detector)

        let testText = "Service injection test \(UUID().uuidString.prefix(8))"
        let result = await service.inject(text: testText)

        // Should succeed via AX direct or clipboard paste
        if case .success(let strategy) = result {
            #expect(strategy == .accessibilityDirect || strategy == .clipboardPaste,
                    "Expected accessibilityDirect or clipboardPaste, got \(strategy)")
        } else {
            Issue.record("Expected .success, got \(result)")
        }

        // Verify text arrived in TextEdit
        let targetApp = AXUIElementCreateApplication(textEdit.processIdentifier)
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            targetApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        if focusResult == .success, let element = focusedElement {
            var value: AnyObject?
            AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &value)
            if let textValue = value as? String {
                #expect(textValue.contains(testText),
                        "TextEdit should contain injected text. Got: \(textValue.prefix(100))")
            }
        }
    }

    // MARK: - Injection with Murmur as frontmost still works

    @Test func injectionWorksEvenWhenMurmurIsFrontmost() async throws {
        guard AXIsProcessTrusted() else { return }

        let textEdit: NSRunningApplication
        do {
            textEdit = try await launchTextEditWithNewDocument()
        } catch {
            // TextEdit launch fails on macOS 26 beta (procNotFound) — skip gracefully
            return
        }
        defer {
            terminateTextEditQuietly(textEdit)
        }

        // Bring Murmur (test host) to front — simulating the HUD stealing focus
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(300))

        // Reactivate TextEdit (simulating what TextInjectionService does)
        textEdit.activate()

        // Poll until TextEdit is writable again
        try await waitForWritableElement(pid: textEdit.processIdentifier, timeout: .seconds(5))

        let injector = AXTextInjector()
        let testText = "Background inject \(UUID().uuidString.prefix(8))"
        let result = await injectWithRetry(injector: injector, text: testText, targetPID: textEdit.processIdentifier)

        #expect(result == .success(strategy: .accessibilityDirect),
                "Expected .success(accessibilityDirect), got \(result)")
    }

    // MARK: - AX injection with invalid PID fails gracefully

    @Test func axInjectionWithInvalidPIDFailsGracefully() {
        guard AXIsProcessTrusted() else { return }

        let injector = AXTextInjector()
        let result = injector.inject(text: "test", targetPID: 99999)

        if case .failed(let error) = result {
            #expect(error == .noFocusedElement, "Expected noFocusedElement for invalid PID")
        } else {
            Issue.record("Expected .failed for invalid PID, got \(result)")
        }
    }
}

// MARK: - InjectionResult Equatable conformance for test assertions

extension InjectionResult: @retroactive Equatable {
    public static func == (lhs: InjectionResult, rhs: InjectionResult) -> Bool {
        switch (lhs, rhs) {
        case (.success(let a), .success(let b)):
            return a == b
        case (.skipped(let a), .skipped(let b)):
            return "\(a)" == "\(b)"
        case (.failed(let a), .failed(let b)):
            return "\(a)" == "\(b)"
        default:
            return false
        }
    }
}

extension InjectionError: @retroactive Equatable {
    public static func == (lhs: InjectionError, rhs: InjectionError) -> Bool {
        return "\(lhs)" == "\(rhs)"
    }
}
