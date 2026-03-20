import AppKit
import SwiftUI

final class DictationHUDWindow: NSPanel {
    enum Mode {
        case idle    // Tiny sliver (48x6), expands on hover
        case recording // Full flow bar with waveform
    }

    private(set) var mode: Mode = .idle

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = contentView

        positionBottomCenter()
    }

    // MARK: - Multi-monitor: position on the screen where the cursor is

    func positionBottomCenter() {
        let screen = screenContainingCursor() ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.minY + 40
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func screenContainingCursor() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    // MARK: - Show/Hide

    func showHUD() {
        positionBottomCenter()
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        }
    }

    func dismissHUD(afterDelay: TimeInterval = 0) {
        if afterDelay > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(afterDelay))
                animateOut()
            }
        } else {
            animateOut()
        }
    }

    private func animateOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.orderOut(nil)
                self?.alphaValue = 1.0
            }
        })
    }

    // MARK: - Mode Transitions

    func transitionToRecording() {
        mode = .recording
        positionBottomCenter()
    }

    func transitionToIdle() {
        mode = .idle
        positionBottomCenter()
    }
}
