@testable import Valen
import XCTest

final class SinglePlayerPolicyTests: XCTestCase {
    func testMainWindowIdentityIsStable() {
        XCTAssertEqual(SinglePlayerPolicy.mainWindowID, "main")
        XCTAssertEqual(SinglePlayerPolicy.mainWindowTitle, "Valen")
    }

    func testWindowTitleUsesFileNameOrDefault() {
        let url = URL(fileURLWithPath: "/Movies/Show.mkv")
        XCTAssertEqual(SinglePlayerPolicy.windowTitle(for: url), "Show.mkv")
        XCTAssertEqual(SinglePlayerPolicy.windowTitle(for: nil), "Valen")
    }

    func testOpenIntentPrefersFirstMediaFile() {
        let urls = [
            URL(fileURLWithPath: "/tmp/notes.txt"),
            URL(fileURLWithPath: "/Movies/A.mkv"),
            URL(fileURLWithPath: "/Movies/B.mp4"),
            URL(fileURLWithPath: "/Movies/A.srt")
        ]

        let intent = SinglePlayerPolicy.openIntent(for: urls, hasCurrentFile: false)
        XCTAssertEqual(intent, .loadMedia(URL(fileURLWithPath: "/Movies/A.mkv")))
    }

    func testOpenIntentLoadsSubtitleOnlyWhenMediaIsAlreadyOpen() {
        let subtitle = URL(fileURLWithPath: "/Movies/Show.srt")
        let urls = [subtitle]

        XCTAssertEqual(
            SinglePlayerPolicy.openIntent(for: urls, hasCurrentFile: false),
            .none
        )
        XCTAssertEqual(
            SinglePlayerPolicy.openIntent(for: urls, hasCurrentFile: true),
            .loadSubtitle(subtitle)
        )
    }

    func testOpenIntentIgnoresUnsupportedFiles() {
        let urls = [
            URL(fileURLWithPath: "/tmp/readme.md"),
            URL(fileURLWithPath: "/tmp/photo.png")
        ]
        XCTAssertEqual(SinglePlayerPolicy.openIntent(for: urls, hasCurrentFile: true), .none)
    }

    func testExtraPlayerWindowPolicyClosesOnlyDuplicatePlayerSurfaces() {
        XCTAssertTrue(
            SinglePlayerPolicy.shouldCloseAsExtraPlayerWindow(
                isVisible: true,
                isMiniaturized: false,
                isFloatingOrModalPanel: false,
                hasMPVHostView: true,
                isMainPlayerWindow: false
            )
        )
        XCTAssertFalse(
            SinglePlayerPolicy.shouldCloseAsExtraPlayerWindow(
                isVisible: true,
                isMiniaturized: false,
                isFloatingOrModalPanel: false,
                hasMPVHostView: true,
                isMainPlayerWindow: true
            )
        )
        XCTAssertFalse(
            SinglePlayerPolicy.shouldCloseAsExtraPlayerWindow(
                isVisible: true,
                isMiniaturized: false,
                isFloatingOrModalPanel: true,
                hasMPVHostView: true,
                isMainPlayerWindow: false
            )
        )
        XCTAssertFalse(
            SinglePlayerPolicy.shouldCloseAsExtraPlayerWindow(
                isVisible: false,
                isMiniaturized: false,
                isFloatingOrModalPanel: false,
                hasMPVHostView: true,
                isMainPlayerWindow: false
            )
        )
    }
}
