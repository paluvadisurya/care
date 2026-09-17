import SwiftUI

// iOS 27 additions, compiled only with the Xcode 27 toolchain (Swift 6.3) and used only on iOS 27.
// On iOS 26 the app falls back to the closest equivalent, so one build serves both.

public extension View {
    /// `swipeActionsContainer()` on iOS 27; no-op on iOS 26 (rows then act as plain buttons).
    @ViewBuilder
    func careSwipeActionsContainer() -> some View {
        #if compiler(>=6.3)
        if #available(iOS 27, *) {
            self.swipeActionsContainer()
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Minimise the navigation bar on scroll down where available.
    @ViewBuilder
    func careMinimizingNavigationBar() -> some View {
        #if compiler(>=6.3)
        if #available(iOS 27, *) {
            self.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
