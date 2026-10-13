@testable import Valen
import XCTest

final class SubtitleSelectionPolicyTests: XCTestCase {
    private func subtitleTrack(id: Int, selected: Bool = false) -> MediaTrack {
        MediaTrack(
            id: id,
            kind: .subtitle,
            title: nil,
            language: nil,
            codec: "ass",
            isDefault: false,
            isForced: false,
            isSelected: selected
        )
    }

    func testSidNoMeansOffEvenIfTrackMarkedSelected() {
        let tracks = [subtitleTrack(id: 2, selected: true)]
        XCTAssertNil(
            SubtitleSelectionPolicy.selectedTrackID(
                sid: "no",
                subVisibility: true,
                subtitleTracks: tracks
            )
        )
    }

    func testSidIntegerWinsWhenPausedTrackNotMarkedSelected() {
        let tracks = [subtitleTrack(id: 2, selected: false)]
        XCTAssertEqual(
            SubtitleSelectionPolicy.selectedTrackID(
                sid: "2",
                subVisibility: true,
                subtitleTracks: tracks
            ),
            2
        )
    }

    func testSubVisibilityFalseTreatsAsOff() {
        XCTAssertNil(
            SubtitleSelectionPolicy.selectedTrackID(
                sid: "2",
                subVisibility: false,
                subtitleTracks: [subtitleTrack(id: 2, selected: true)]
            )
        )
    }

    func testExternalSidRetainedBeforeTrackListUpdates() {
        XCTAssertEqual(
            SubtitleSelectionPolicy.selectedTrackID(
                sid: "5",
                subVisibility: true,
                subtitleTracks: []
            ),
            5
        )
    }
}
