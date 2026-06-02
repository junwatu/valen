@testable import Valen
import XCTest

final class PlaybackStatePolicyTests: XCTestCase {
    func testPlaybackStateIsNotSavedWithoutDuration() {
        XCTAssertFalse(
            PlaybackStatePolicy.canSave(
                duration: 0,
                resumeEnabled: true,
                didApplyRestoreState: true,
                hasPendingRestoreState: false
            )
        )
    }

    func testPlaybackStateRespectsResumePreference() {
        XCTAssertFalse(
            PlaybackStatePolicy.canSave(
                duration: 120,
                resumeEnabled: false,
                didApplyRestoreState: true,
                hasPendingRestoreState: false
            )
        )
    }

    func testPlaybackStateWaitsForPendingRestoreBeforeSaving() {
        XCTAssertFalse(
            PlaybackStatePolicy.canSave(
                duration: 120,
                resumeEnabled: true,
                didApplyRestoreState: false,
                hasPendingRestoreState: true
            )
        )

        XCTAssertTrue(
            PlaybackStatePolicy.canSave(
                duration: 120,
                resumeEnabled: true,
                didApplyRestoreState: true,
                hasPendingRestoreState: true
            )
        )
    }

    func testRestorePositionAvoidsStartAndEndOfVideo() {
        XCTAssertFalse(PlaybackStatePolicy.shouldRestorePosition(5, duration: 120))
        XCTAssertTrue(PlaybackStatePolicy.shouldRestorePosition(6, duration: 120))
        XCTAssertTrue(PlaybackStatePolicy.shouldRestorePosition(114, duration: 120))
        XCTAssertFalse(PlaybackStatePolicy.shouldRestorePosition(115, duration: 120))
        XCTAssertFalse(PlaybackStatePolicy.shouldRestorePosition(20, duration: 22))
    }
}
