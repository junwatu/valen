import Foundation

enum OverlayVisibilityPolicy {
    static func shouldShowControls(
        isPaused: Bool,
        hasCurrentFile: Bool,
        isDebugVisible: Bool,
        hasActivePopover: Bool,
        isPointerActive: Bool
    ) -> Bool {
        isPaused || !hasCurrentFile || isDebugVisible || hasActivePopover || isPointerActive
    }

    static func shouldHideCursor(
        isFullscreen: Bool,
        isPointerInside: Bool,
        hasCurrentFile: Bool,
        isPaused: Bool,
        shouldShowControls: Bool
    ) -> Bool {
        let pointerCanBeHidden = isFullscreen || isPointerInside
        return pointerCanBeHidden && hasCurrentFile && !isPaused && !shouldShowControls
    }
}
