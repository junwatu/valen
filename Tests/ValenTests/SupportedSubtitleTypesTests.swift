import Foundation
@testable import Valen
import XCTest

final class SupportedSubtitleTypesTests: XCTestCase {
    func testCommonSubtitleExtensionsAreSupported() {
        for ext in ["srt", "ass", "ssa", "vtt", "sub", "sup"] {
            XCTAssertTrue(SupportedSubtitleTypes.supports(fileExtension: ext), ext)
        }
    }

    func testUnsupportedSubtitleExtensionIsRejected() {
        XCTAssertFalse(SupportedSubtitleTypes.supports(fileExtension: "mkv"))
        XCTAssertFalse(SupportedSubtitleTypes.supports(fileExtension: "txt"))
    }

    func testMatchingSubtitleURLFindsSiblingFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("valen-subtitle-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let media = directory.appendingPathComponent("Episode 01.mkv")
        let subtitle = directory.appendingPathComponent("Episode 01.srt")
        FileManager.default.createFile(atPath: media.path, contents: Data([0x00]))
        FileManager.default.createFile(atPath: subtitle.path, contents: "1\n00:00:01,000 --> 00:00:02,000\nHi\n".data(using: .utf8))

        XCTAssertEqual(
            SupportedSubtitleTypes.matchingSubtitleURL(for: media)?.lastPathComponent,
            "Episode 01.srt"
        )
    }

    func testMatchingSubtitleURLPrefersEarlierExtensionOrderWhenMultipleExist() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("valen-subtitle-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let media = directory.appendingPathComponent("movie.mkv")
        FileManager.default.createFile(atPath: media.path, contents: Data())
        FileManager.default.createFile(atPath: directory.appendingPathComponent("movie.ass").path, contents: Data())
        FileManager.default.createFile(atPath: directory.appendingPathComponent("movie.srt").path, contents: Data())

        XCTAssertEqual(
            SupportedSubtitleTypes.matchingSubtitleURL(for: media)?.pathExtension,
            "srt"
        )
    }
}