import Foundation

enum PlaybackStatePolicy {
    static func canSave(
        duration: Double,
        resumeEnabled: Bool,
        didApplyRestoreState: Bool,
        hasPendingRestoreState: Bool
    ) -> Bool {
        duration > 0 && resumeEnabled && (didApplyRestoreState || !hasPendingRestoreState)
    }

    static func shouldRestorePosition(_ position: Double, duration: Double) -> Bool {
        position > 5 && position < max(duration - 5, 0)
    }
}
