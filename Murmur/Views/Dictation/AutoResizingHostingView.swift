import AppKit
import SwiftUI

/// NSHostingView subclass that automatically resizes its parent window
/// when the SwiftUI content changes size (e.g., idle pill → recording bar).
///
/// Sets `sizingOptions = []` to prevent NSHostingView from driving window
/// constraints via intrinsicContentSize. Without this, the hosting view's
/// internal view graph evaluation during updateConstraints() triggers
/// setNeedsUpdateConstraints, creating a recursive constraint loop that
/// crashes with NSGenericException ("more Update Constraints in Window
/// passes than there are views in the window").
///
/// Window sizing is managed manually in layout() with a deferred resize
/// and re-entrancy guard to break the layout→resize→layout cycle.
final class AutoResizingHostingView<Content: View>: NSHostingView<Content> {
    private var lastAppliedSize: NSSize = .zero
    private var resizeScheduled = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
        // Prevent the hosting view from participating in the window's
        // constraint system. This stops the recursive constraint update
        // loop where updateConstraints → minSize → view graph evaluation
        // → invalidateTransform → setNeedsUpdateConstraints → repeat.
        sizingOptions = []
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func layout() {
        super.layout()

        // Re-entrancy guard: skip if we already have a resize pending.
        // Without this, layout() → deferred setContentSize → layout() → ...
        guard !resizeScheduled, let window else { return }

        let newSize = fittingSize

        // Only resize if genuinely changed (2pt threshold avoids sub-pixel oscillation)
        guard abs(newSize.width - lastAppliedSize.width) > 2
           || abs(newSize.height - lastAppliedSize.height) > 2 else { return }

        resizeScheduled = true

        // Defer the resize to break out of the current display cycle.
        // setContentSize triggers constraint invalidation, which would
        // re-enter layout() synchronously if done inline.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            self.resizeScheduled = false
            let size = self.fittingSize
            self.lastAppliedSize = size
            window.setContentSize(size)
            if let hudWindow = window as? DictationHUDWindow {
                hudWindow.positionBottomCenter()
            }
        }
    }
}
