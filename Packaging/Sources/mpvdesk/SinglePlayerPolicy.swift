import Foundation

/// Valen is a single-player, single-window app. Opening media always replaces
/// the current file in the existing session instead of spawning another player.
enum SinglePlayerPolicy {
    static let mainWindowID = "main"
    static let mainWindowTitle = "Valen"

    enum OpenIntent: Equatable {
        case loadMedia(URL)
        case loadSubtitle(URL)
        case none
    }

    /// Resolve Finder / drag / multi-select opens for a single player.
    /// Prefer the first media file; only accept a subtitle when a video is already open.
    static func openIntent(for urls: [URL], hasCurrentFile: Bool) -> OpenIntent {
        if let media = urls.first(where: { SupportedMediaTypes.supports(fileExtension: $0.pathExtension) }) {
            return .loadMedia(media.standardizedFileURL)
        }

        if hasCurrentFile,
           let subtitle = urls.first(where: { SupportedSubtitleTypes.supports(url: $0) }) {
            return .loadSubtitle(subtitle.standardizedFileURL)
        }

        return .none
    }

    /// Window title for the single player window.
    static func windowTitle(for file: URL?) -> String {
        file?.lastPathComponent ?? mainWindowTitle
    }

    /// Keep only the player window (plus system panels like Settings / About).
    /// Extra `WindowGroup`-style player windows are closed if they appear.
    static func shouldCloseAsExtraPlayerWindow(
        isVisible: Bool,
        isMiniaturized: Bool,
        isFloatingOrModalPanel: Bool,
        hasMPVHostView: Bool,
        isMainPlayerWindow: Bool
    ) -> Bool {
        guard isVisible || isMiniaturized else { return false }
        guard !isFloatingOrModalPanel else { return false }
        guard hasMPVHostView else { return false }
        return !isMainPlayerWindow
    }
}
