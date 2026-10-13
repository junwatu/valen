import Foundation

/// Keeps UI subtitle selection aligned with mpv `sid` / `sub-visibility`, not transient track flags.
enum SubtitleSelectionPolicy {
    static func selectedTrackID(
        sid: String?,
        subVisibility: Bool,
        subtitleTracks: [MediaTrack]
    ) -> Int? {
        guard subVisibility, sid != "no" else {
            return nil
        }

        guard let sid, let sidInt = Int(sid) else {
            return subtitleTracks.first(where: \.isSelected)?.id
        }

        return sidInt
    }
}
