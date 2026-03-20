import AppKit
import SwiftUI

/// NSHostingView subclass that automatically resizes its parent window
/// when the SwiftUI content changes size (e.g., idle pill → recording bar).
final class AutoResizingHostingView<Content: View>: NSHostingView<Content> {
    override func layout() {
        super.layout()

        guard let window else { return }

        let newSize = fittingSize
        let currentSize = window.frame.size

        // Only resize if the size actually changed (1pt tolerance prevents infinite layout loops)
        guard abs(newSize.width - currentSize.width) > 1
           || abs(newSize.height - currentSize.height) > 1 else { return }

        window.setContentSize(newSize)

        // Reposition to stay bottom-center after resize
        if let hudWindow = window as? DictationHUDWindow {
            hudWindow.positionBottomCenter()
        }
    }
}
