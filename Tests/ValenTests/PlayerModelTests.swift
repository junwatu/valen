import Foundation
@testable import Valen
import XCTest

@MainActor
final class PlayerModelTests: XCTestCase {
    func testFormatTimeHandlesEmptyAndInvalidValues() {
        XCTAssertEqual(PlayerModel.formatTime(-1), "00:00")
        XCTAssertEqual(PlayerModel.formatTime(0), "00:00")
        XCTAssertEqual(PlayerModel.formatTime(.nan), "00:00")
        XCTAssertEqual(PlayerModel.formatTime(.infinity), "00:00")
    }

    func testFormatTimeHandlesMinutesAndHours() {
        XCTAssertEqual(PlayerModel.formatTime(1), "00:01")
        XCTAssertEqual(PlayerModel.formatTime(65), "01:05")
        XCTAssertEqual(PlayerModel.formatTime(3_725), "1:02:05")
    }

    func testMediaTrackDisplayNameUsesStableMetadataOrder() {
        let track = MediaTrack(
            id: 4,
            kind: .subtitle,
            title: "Full Subs [BlurayDesuYo]",
            language: "ja",
            codec: "ass",
            isDefault: true,
            isForced: true,
            isSelected: false
        )

        XCTAssertEqual(
            track.displayName,
            "Track 4 - Full Subs [BlurayDesuYo] - metadata lang: JA - default - forced"
        )
    }

    func testSavedPlaybackStateSubtitleDescription() {
        XCTAssertEqual(
            SavedPlaybackState(
                position: 10,
                duration: 100,
                audioTrackID: nil,
                subtitleTrackID: nil,
                subtitlesOff: true,
                volume: 80,
                updatedAt: Date()
            ).subtitleDescription,
            "off"
        )

        XCTAssertEqual(
            SavedPlaybackState(
                position: 10,
                duration: 100,
                audioTrackID: nil,
                subtitleTrackID: 3,
                subtitlesOff: false,
                volume: 80,
                updatedAt: Date()
            ).subtitleDescription,
            "3"
        )

        XCTAssertEqual(
            SavedPlaybackState(
                position: 10,
                duration: 100,
                audioTrackID: nil,
                subtitleTrackID: nil,
                subtitlesOff: false,
                volume: 80,
                updatedAt: Date()
            ).subtitleDescription,
            "auto"
        )
    }

    func testPlaybackStateStoreSavesByStandardizedFilePath() throws {
        let defaultsKey = "dev.valen.tests.playbackState.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: defaultsKey) }

        let store = PlaybackStateStore(defaultsKey: defaultsKey)
        let url = URL(fileURLWithPath: "/tmp/../tmp/valen-test.mkv")
        let state = SavedPlaybackState(
            position: 42,
            duration: 120,
            audioTrackID: 2,
            subtitleTrackID: 4,
            subtitlesOff: false,
            volume: 63,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        store.save(state, for: url)
        let restored = try XCTUnwrap(store.state(for: url.standardizedFileURL))

        XCTAssertEqual(restored.position, 42)
        XCTAssertEqual(restored.duration, 120)
        XCTAssertEqual(restored.audioTrackID, 2)
        XCTAssertEqual(restored.subtitleTrackID, 4)
        XCTAssertFalse(restored.subtitlesOff)
        XCTAssertEqual(restored.volume, 63)
    }
}
