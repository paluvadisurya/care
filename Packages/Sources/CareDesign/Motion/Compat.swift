import SwiftUI

// iOS 27 additions. They compile only when the CARE_SDK27 condition is set, because the iOS 26 SDK does not
// know these symbols. On Xcode 27, add `-DCARE_SDK27` under Other Swift Flags (or `.define("CARE_SDK27")`
// in Package.swift) and they light up on iOS 27 devices; everything else already runs on iOS 26.

public extension View {
    /// `swipeActionsContainer()` on iOS 27; no-op otherwise (rows keep their context menus).
    @ViewBuilder
    func careSwipeActionsContainer() -> some View {
        #if CARE_SDK27
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
        #if CARE_SDK27
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
