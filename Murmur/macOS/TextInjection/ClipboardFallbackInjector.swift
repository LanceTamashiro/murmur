import AppKit
import TextInjection

@MainActor
final class ClipboardFallbackInjector {

    func inject(text: String) async -> InjectionResult {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents
        let savedItems = savePasteboardContents(pasteboard)

        // Write dictation text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Brief delay to ensure clipboard contents are available to target app
        try? await Task.sleep(for: .milliseconds(50))

        // Synthesize Cmd+V
        let success = simulatePaste()

        guard success else {
            // Restore clipboard on failure
            restorePasteboardContents(pasteboard, items: savedItems)
            return .failed(error: .clipboardOperationFailed)
        }

        // Wait for target app to consume the paste before restoring clipboard.
        // 200ms is sufficient for most apps (native apps are instant, Electron <100ms).
        try? await Task.sleep(for: .milliseconds(200))
        restorePasteboardContents(pasteboard, items: savedItems)

        return .success(strategy: .clipboardPaste)
    }

    private func simulatePaste() -> Bool {
        let source = CGEventSource(stateID: .privateState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return false
        }

        // 0x09 = 'v' key
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    private struct SavedPasteboardItem {
        let types: [NSPasteboard.PasteboardType]
        let data: [NSPasteboard.PasteboardType: Data]
    }

    private func savePasteboardContents(_ pasteboard: NSPasteboard) -> [SavedPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.compactMap { item in
            var dataMap: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dataMap[type] = data
                }
            }
            return SavedPasteboardItem(types: item.types, data: dataMap)
        }
    }

    private func restorePasteboardContents(_ pasteboard: NSPasteboard, items: [SavedPasteboardItem]) {
        pasteboard.clearContents()
        for savedItem in items {
            let item = NSPasteboardItem()
            for (type, data) in savedItem.data {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }
}
