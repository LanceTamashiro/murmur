import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    enum IconState {
        case idle
        case listening
        case processing
        case error
    }

    var iconState: IconState = .idle {
        didSet { updateIcon() }
    }

    func setup(popoverContent: @escaping () -> AnyView) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Murmur")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: popoverContent())
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        popover?.performClose(nil)
    }

    private func updateIcon() {
        let symbolName: String
        switch iconState {
        case .idle:
            symbolName = "mic"
        case .listening:
            symbolName = "mic.fill"
        case .processing:
            symbolName = "ellipsis.circle"
        case .error:
            symbolName = "exclamationmark.triangle"
        }
        statusItem?.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Murmur - \(iconState)"
        )
    }
}
