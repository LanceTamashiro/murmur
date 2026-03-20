import AppKit
import SwiftUI

/// NSHostingView subclass that automatically resizes its parent window
/// when the SwiftUI content changes size (e.g., idle pill → recording bar).
///
/// Window resize is deferred to the next run loop iteration to avoid
/// layout recursion (setContentSize during layout triggers another layout pass).
final class AutoResizingHostingView<Content: View>: NSHostingView<Content> {
    private var lastAppliedSize: NSSize = .zero
    private var resizePending = false

    override func layout() {
        super.layout()

        guard window != nil, !resizePending else { return }

        let newSize = fittingSize

        // Only resize if the size genuinely changed (compare against what we last applied)
        guard abs(newSize.width - lastAppliedSize.width) > 1
           || abs(newSize.height - lastAppliedSize.height) > 1 else { return }

        lastAppliedSize = newSize
        resizePending = true

        // Defer resize to avoid layout recursion — setContentSize triggers constraints
        // update which triggers layout, causing an infinite loop if done synchronously.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.resizePending = false
            guard let window = self.window else { return }

            window.setContentSize(self.lastAppliedSize)

            if let hudWindow = window as? DictationHUDWindow {
                hudWindow.positionBottomCenter()
            }
        }
    }
}
