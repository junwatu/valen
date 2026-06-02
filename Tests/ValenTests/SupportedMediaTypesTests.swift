@testable import Valen
import UniformTypeIdentifiers
import XCTest

final class SupportedMediaTypesTests: XCTestCase {
    func testCommonMediaExtensionsStaySupported() {
        let expectedExtensions = [
            "mkv",
            "mka",
            "webm",
            "mp4",
            "mov",
            "m4v",
            "avi",
            "flv",
            "wmv",
            "mp3",
            "flac",
            "ogg",
            "wav"
        ]

        XCTAssertEqual(SupportedMediaTypes.fileExtensions, expectedExtensions)

        for fileExtension in expectedExtensions {
            XCTAssertTrue(SupportedMediaTypes.supports(fileExtension: fileExtension))
            XCTAssertTrue(SupportedMediaTypes.supports(fileExtension: fileExtension.uppercased()))
        }
    }

    func testOpenPanelContentTypesIncludeCustomContainers() {
        let identifiers = Set(SupportedMediaTypes.contentTypes.map(\.identifier))

        XCTAssertTrue(identifiers.contains(UTType.movie.identifier))
        XCTAssertTrue(identifiers.contains(UTType.audio.identifier))
        XCTAssertTrue(identifiers.contains(UTType(filenameExtension: "mkv")?.identifier ?? ""))
        XCTAssertTrue(identifiers.contains(UTType(filenameExtension: "webm")?.identifier ?? ""))
        XCTAssertTrue(identifiers.contains(UTType(filenameExtension: "flac")?.identifier ?? ""))
    }

    func testUnsupportedExtensionIsRejectedByPolicy() {
        XCTAssertFalse(SupportedMediaTypes.supports(fileExtension: "txt"))
        XCTAssertFalse(SupportedMediaTypes.supports(fileExtension: "pdf"))
    }
}
