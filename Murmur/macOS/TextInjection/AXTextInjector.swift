import AppKit
import ApplicationServices
import TextInjection
import os.log

private let logger = Logger(subsystem: "com.unconventionalpsychotherapy.murmur", category: "AXTextInjector")

final class AXTextInjector {

    func inject(text: String, targetPID: pid_t) -> InjectionResult {
        // Target the specific application by PID rather than querying system-wide focus.
        // System-wide focus can return Murmur's own HUD element or nil when Murmur is
        // in front — targeting the app directly ensures we find its focused text field.
        let targetApp = AXUIElementCreateApplication(targetPID)

        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            targetApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            logger.warning("AX focusedElement query failed: error=\(focusResult.rawValue) (apiDisabled=-25211, cannotComplete=-25204, noValue=-25212)")
            return .failed(error: .noFocusedElement)
        }

        let axElement = element as! AXUIElement

        // Skip web areas — browsers don't reliably support direct AX value setting
        if isInsideWebArea(axElement) {
            return .failed(error: .elementNotWritable)
        }

        // Check if the element supports text value
        var roleValue: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue)

        // Try to get the current value to verify it's a text field
        var currentValue: AnyObject?
        let valueResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &currentValue)

        guard valueResult == .success else {
            return .failed(error: .elementNotWritable)
        }

        // Check if value is settable
        var isSettable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(axElement, kAXValueAttribute as CFString, &isSettable)

        if isSettable.boolValue {
            return injectViaSetValue(element: axElement, text: text, currentValue: currentValue as? String)
        } else {
            return .failed(error: .elementNotWritable)
        }
    }

    // MARK: - Web Area Detection

    /// Walk up the AX parent chain to detect if the focused element is inside a web area.
    /// Browser text fields (AXWebArea descendants) don't reliably support direct AX value setting.
    private func isInsideWebArea(_ element: AXUIElement) -> Bool {
        // Check the element itself
        if elementRole(element) == "AXWebArea" {
            return true
        }

        // Walk up parent chain (max 10 levels to avoid infinite loops)
        var current = element
        for _ in 0..<10 {
            var parent: AnyObject?
            let result = AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent)
            guard result == .success, let parentElement = parent else { break }

            let parentAX = parentElement as! AXUIElement
            if elementRole(parentAX) == "AXWebArea" {
                return true
            }
            current = parentAX
        }

        return false
    }

    private func elementRole(_ element: AXUIElement) -> String? {
        var role: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        guard result == .success else { return nil }
        return role as? String
    }

    // MARK: - Value Injection with Verification

    private func injectViaSetValue(element: AXUIElement, text: String, currentValue: String?) -> InjectionResult {
        let current = currentValue ?? ""

        // Get selected text range to insert at cursor position
        var selectedRange: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRange
        )

        var selectionLength = 0
        let newValue: String
        if rangeResult == .success, let rangeValue = selectedRange {
            // Get the range and replace selection
            var range = CFRange()
            if AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) {
                selectionLength = range.length
                let startIndex = current.index(current.startIndex, offsetBy: min(range.location, current.count))
                let endIndex = current.index(startIndex, offsetBy: min(range.length, current.count - min(range.location, current.count)))
                var mutable = current
                mutable.replaceSubrange(startIndex..<endIndex, with: text)
                newValue = mutable
            } else {
                // Append to existing value
                newValue = current + text
            }
        } else {
            // No selection info — append
            newValue = current + text
        }

        let expectedLength = current.count - selectionLength + text.count

        let setResult = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            newValue as CFTypeRef
        )

        guard setResult == .success else {
            return .failed(error: .elementNotWritable)
        }

        // Verify the text was actually inserted by reading the value back
        var verifyValue: AnyObject?
        let verifyResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &verifyValue)
        if verifyResult == .success, let actualValue = verifyValue as? String {
            if actualValue.count != expectedLength {
                return .failed(error: .verificationFailed(expected: expectedLength, actual: actualValue.count))
            }
        }

        // Move cursor to end of inserted text
        let cursorPosition = (current.count - selectionLength) + text.count
        var newRange = CFRangeMake(cursorPosition, 0)
        if let rangeValue = AXValueCreate(.cfRange, &newRange) {
            AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                rangeValue
            )
        }

        return .success(strategy: .accessibilityDirect)
    }
}
