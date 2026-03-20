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
@Suite("Text Injection Tests")
struct TextInjectionTests {

    // MARK: - AXTextInjector targets app by PID

    @Test func axInjectorTargetsSpecificAppByPID() async throws {
        // Skip if no accessibility permission
        guard AXIsProcessTrusted() else {
            return
        }

        // Launch TextEdit
        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        let textEdit = try await NSWorkspace.shared.openApplication(
            at: textEditURL,
            configuration: config
        )

        // Wait for TextEdit to become frontmost and create a window
        try await Task.sleep(for: .milliseconds(1000))

        // Create a new document (Cmd+N) to ensure a text field is focused
        let cmdN_Down = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: true)!
        let cmdN_Up = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: false)!
        cmdN_Down.flags = .maskCommand
        cmdN_Up.flags = .maskCommand
        cmdN_Down.post(tap: .cghidEventTap)
        cmdN_Up.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(500))

        // Inject text targeting TextEdit by PID
        let injector = AXTextInjector()
        let testText = "Murmur injection test \(UUID().uuidString.prefix(8))"
        let result = injector.inject(text: testText, targetPID: textEdit.processIdentifier)

        // Verify injection succeeded
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

        // Clean up: close TextEdit
        textEdit.terminate()
        try await Task.sleep(for: .milliseconds(300))
    }

    // MARK: - Full injection flow via TextInjectionService

    @Test func fullInjectionServiceFlowInjectsIntoTextEdit() async throws {
        guard AXIsProcessTrusted() else {
            return
        }

        // Launch TextEdit
        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        let textEdit = try await NSWorkspace.shared.openApplication(
            at: textEditURL,
            configuration: config
        )

        try await Task.sleep(for: .milliseconds(1000))

        // New document
        let cmdN_Down = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: true)!
        let cmdN_Up = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: false)!
        cmdN_Down.flags = .maskCommand
        cmdN_Up.flags = .maskCommand
        cmdN_Down.post(tap: .cghidEventTap)
        cmdN_Up.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(500))

        // Set up the injection service with AppContextDetector
        let detector = AppContextDetector()
        let service = TextInjectionService(appContextDetector: detector)

        // Manually set the context to TextEdit (since Murmur is the test host)
        // We can't set currentAppContext directly, so we use the fallback path
        // in inject() which checks NSWorkspace.shared.frontmostApplication.
        // TextEdit should be frontmost since we just activated it.

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

        // Clean up
        textEdit.terminate()
        try await Task.sleep(for: .milliseconds(300))
    }

    // MARK: - Injection with Murmur as frontmost still works

    @Test func injectionWorksEvenWhenMurmurIsFrontmost() async throws {
        guard AXIsProcessTrusted() else {
            return
        }

        // Launch TextEdit and create a new document
        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        let textEdit = try await NSWorkspace.shared.openApplication(
            at: textEditURL,
            configuration: config
        )

        try await Task.sleep(for: .milliseconds(1000))

        let cmdN_Down = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: true)!
        let cmdN_Up = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: false)!
        cmdN_Down.flags = .maskCommand
        cmdN_Up.flags = .maskCommand
        cmdN_Down.post(tap: .cghidEventTap)
        cmdN_Up.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(500))

        // Now bring Murmur (test host) to front — simulating the HUD stealing focus
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(300))

        // Inject directly into TextEdit by PID — should work even though Murmur is frontmost
        let injector = AXTextInjector()
        let testText = "Background inject \(UUID().uuidString.prefix(8))"

        // Reactivate TextEdit first (simulating what TextInjectionService does)
        textEdit.activate()
        try await Task.sleep(for: .milliseconds(150))

        let result = injector.inject(text: testText, targetPID: textEdit.processIdentifier)
        #expect(result == .success(strategy: .accessibilityDirect),
                "Expected .success(accessibilityDirect), got \(result)")

        // Clean up
        textEdit.terminate()
        try await Task.sleep(for: .milliseconds(300))
    }

    // MARK: - AX injection with invalid PID fails gracefully

    @Test func axInjectionWithInvalidPIDFailsGracefully() {
        guard AXIsProcessTrusted() else {
            return
        }

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
