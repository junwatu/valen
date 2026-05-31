@testable import Valen
import XCTest

final class LayoutMetricsTests: XCTestCase {
    func testEmptyStateCopyAndIconStayStable() {
        XCTAssertEqual(ValenLayoutMetrics.emptyStateIcon, "play.rectangle")
        XCTAssertEqual(ValenLayoutMetrics.emptyStateTitle, "Open a video or audio file")
        XCTAssertEqual(ValenLayoutMetrics.emptyStateDropTitle, "Drop to play")
        XCTAssertEqual(ValenLayoutMetrics.emptyStateSubtitle, "Drag a file here or use Command-O.")
        XCTAssertEqual(ValenLayoutMetrics.emptyStateButtonTitle, "Open File")
    }

    func testEmptyStateSpacingStaysCompact() {
        XCTAssertEqual(ValenLayoutMetrics.emptyStateSpacing, 16.0)
        XCTAssertEqual(ValenLayoutMetrics.emptyStateIconSize, 56.0)
        XCTAssertEqual(ValenLayoutMetrics.emptyStateTextSpacing, 6.0)
        XCTAssertEqual(ValenLayoutMetrics.emptyStatePadding, 32.0)
    }

    func testPlaybackOverlayMetricsStayQuickTimeLike() {
        XCTAssertEqual(ValenLayoutMetrics.overlayWidthWithoutMedia, 420.0)
        XCTAssertEqual(ValenLayoutMetrics.overlayWidthWithMedia, 760.0)
        XCTAssertEqual(ValenLayoutMetrics.overlayOpacity, 0.60)
        XCTAssertEqual(ValenLayoutMetrics.overlayCornerRadius, 12.0)
    }

    func testPlaybackOverlayIconsStaySemantic() {
        XCTAssertEqual(ValenLayoutMetrics.volumeIcon, "speaker.wave.2")
        XCTAssertEqual(ValenLayoutMetrics.audioTracksIcon, "music.note.list")
        XCTAssertEqual(ValenLayoutMetrics.subtitlesInactiveIcon, "captions.bubble")
        XCTAssertEqual(ValenLayoutMetrics.subtitlesActiveIcon, "captions.bubble.fill")
        XCTAssertEqual(ValenLayoutMetrics.appInfoIcon, "info.circle")
        XCTAssertEqual(ValenLayoutMetrics.openFileIcon, "folder.badge.plus")
    }
}
