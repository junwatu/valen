@testable import ValenControl
import XCTest

final class MCPToolsTests: XCTestCase {
    private let expectedToolNames: Set<String> = Set(ControlMethod.allCases.map(\.rawValue))

    func testEveryControlMethodHasMatchingMCPToolName() {
        for method in ControlMethod.allCases {
            XCTAssertTrue(
                expectedToolNames.contains(method.rawValue),
                "Control method \(method.rawValue) should be exposed as an MCP tool name"
            )
        }
    }

    func testMCPToolCatalogMatchesControlMethods() {
        XCTAssertEqual(ControlMethod.allCases.count, 13)
        XCTAssertTrue(expectedToolNames.contains("list_audio_tracks"))
        XCTAssertTrue(expectedToolNames.contains("list_subtitle_tracks"))
        XCTAssertTrue(expectedToolNames.contains("select_audio_track"))
        XCTAssertTrue(expectedToolNames.contains("select_subtitle_track"))
        XCTAssertTrue(expectedToolNames.contains("subtitles_off"))
    }

    func testOpenFileRequiresAbsolutePathInPolicy() {
        XCTAssertNil(ControlCommandPolicy.validAbsoluteOpenPath("movie.mkv"))
        XCTAssertNil(ControlCommandPolicy.validAbsoluteOpenPath("~/Downloads/movie.mkv"))
        XCTAssertEqual(
            ControlCommandPolicy.validAbsoluteOpenPath("  /Users/example/movie.mkv  "),
            "/Users/example/movie.mkv"
        )
    }

    func testRichControlStateEncodesExpectedKeys() throws {
        let state = ControlState(
            currentFile: "/Users/example/movie.mkv",
            isPaused: true,
            position: 12.5,
            duration: 100,
            volume: 80,
            speed: 1.25,
            selectedAudioID: 1,
            selectedSubtitleID: 3,
            subtitlesVisible: true,
            activeSubtitleText: "Hello",
            audioTracks: [
                ControlTrackInfo(
                    id: 1,
                    kind: "audio",
                    title: "Japanese",
                    language: "jpn",
                    codec: "aac",
                    isDefault: true,
                    isForced: false,
                    isSelected: true,
                    displayName: "Track 1 - Japanese"
                )
            ],
            subtitleTracks: []
        )

        let keys = Set(state.jsonDictionary.keys)
        XCTAssertTrue(keys.contains("selectedAudioID"))
        XCTAssertTrue(keys.contains("selectedSubtitleID"))
        XCTAssertTrue(keys.contains("subtitlesVisible"))
        XCTAssertTrue(keys.contains("activeSubtitleText"))
        XCTAssertTrue(keys.contains("audioTracks"))
        XCTAssertTrue(keys.contains("subtitleTracks"))
        XCTAssertEqual(state.protocolVersion, 2)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ControlState.self, from: data)
        XCTAssertEqual(decoded.selectedAudioID, 1)
        XCTAssertEqual(decoded.activeSubtitleText, "Hello")
        XCTAssertEqual(decoded.audioTracks.count, 1)
    }
}