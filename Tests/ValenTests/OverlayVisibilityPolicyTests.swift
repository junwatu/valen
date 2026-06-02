@testable import Valen
import XCTest

final class OverlayVisibilityPolicyTests: XCTestCase {
    func testOverlayShowsWhenPausedOrNoFileOrDebugVisible() {
        XCTAssertTrue(
            OverlayVisibilityPolicy.shouldShowControls(
                isPaused: true,
                hasCurrentFile: true,
                isDebugVisible: false,
                hasActivePopover: false,
                isPointerActive: false
            )
        )

        XCTAssertTrue(
            OverlayVisibilityPolicy.shouldShowControls(
                isPaused: false,
                hasCurrentFile: false,
                isDebugVisible: false,
                hasActivePopover: false,
                isPointerActive: false
            )
        )

        XCTAssertTrue(
            OverlayVisibilityPolicy.shouldShowControls(
                isPaused: false,
                hasCurrentFile: true,
                isDebugVisible: true,
                hasActivePopover: false,
                isPointerActive: false
            )
        )
    }

    func testOverlayStaysVisibleWhileAudioOrSubtitlePopoverIsOpen() {
        XCTAssertTrue(
            OverlayVisibilityPolicy.shouldShowControls(
                isPaused: false,
                hasCurrentFile: true,
                isDebugVisible: false,
                hasActivePopover: true,
                isPointerActive: false
            )
        )
    }

    func testOverlayCanHideDuringKeyboardOnlyPlayback() {
        XCTAssertFalse(
            OverlayVisibilityPolicy.shouldShowControls(
                isPaused: false,
                hasCurrentFile: true,
                isDebugVisible: false,
                hasActivePopover: false,
                isPointerActive: false
            )
        )
    }

    func testCursorHidesOnlyWhenPlaybackControlsAreHidden() {
        XCTAssertTrue(
            OverlayVisibilityPolicy.shouldHideCursor(
                isFullscreen: false,
                isPointerInside: true,
                hasCurrentFile: true,
                isPaused: false,
                shouldShowControls: false
            )
        )

        XCTAssertFalse(
            OverlayVisibilityPolicy.shouldHideCursor(
                isFullscreen: false,
                isPointerInside: true,
                hasCurrentFile: true,
                isPaused: false,
                shouldShowControls: true
            )
        )
    }
}
