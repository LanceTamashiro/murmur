import AppKit
import SwiftUI

/// NSHostingView subclass that automatically resizes its parent window
/// when the SwiftUI content changes size (e.g., idle pill → recording bar).
///
/// Uses a cancellable DispatchWorkItem to coalesce rapid layout changes
/// and avoid the layout recursion that setContentSize triggers.
final class AutoResizingHostingView<Content: View>: NSHostingView<Content> {
    private var lastAppliedSize: NSSize = .zero
    private var resizeWorkItem: DispatchWorkItem?

    override func layout() {
        super.layout()

        guard window != nil else { return }

        let newSize = fittingSize

        // Only resize if genuinely changed (2pt threshold avoids sub-pixel oscillation)
        guard abs(newSize.width - lastAppliedSize.width) > 2
           || abs(newSize.height - lastAppliedSize.height) > 2 else { return }

        // Cancel any pending resize to coalesce rapid state transitions
        resizeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let window = self.window else { return }
            // Re-read fittingSize at execution time to get the settled value
            let size = self.fittingSize
            self.lastAppliedSize = size
            window.setContentSize(size)
            if let hudWindow = window as? DictationHUDWindow {
                hudWindow.positionBottomCenter()
            }
        }
        resizeWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }
}
