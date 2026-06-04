@testable import ValenControl
import XCTest

final class ControlProtocolTests: XCTestCase {
    func testRequestRoundTrip() throws {
        let original = ControlRequest(
            id: 42,
            method: "open_file",
            params: ["path": AnyCodable("/Users/example/movie.mkv")]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ControlRequest.self, from: data)

        XCTAssertEqual(decoded.id, 42)
        XCTAssertEqual(decoded.method, "open_file")
        XCTAssertEqual(decoded.params?["path"]?.value as? String, "/Users/example/movie.mkv")
    }

    func testResponseOkWithoutResult() throws {
        let response = ControlResponse.ok(id: 7)
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ControlResponse.self, from: data)

        XCTAssertEqual(decoded.id, 7)
        XCTAssertNil(decoded.error)
    }

    func testResponseFailCarriesErrorMessage() throws {
        let response = ControlResponse.fail(id: 9, message: "missing path")
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ControlResponse.self, from: data)

        XCTAssertEqual(decoded.id, 9)
        XCTAssertEqual(decoded.error, "missing path")
    }

    func testAnyCodableHandlesAllJSONTypes() throws {
        let original: Any = [
            "string": "hello",
            "int": 42,
            "double": 3.14,
            "bool": true,
            "null": NSNull(),
            "array": [1, 2, 3],
            "object": ["nested": "value"]
        ]

        let data = try JSONEncoder().encode(AnyCodable(original))
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        let dict = decoded.value as? [String: Any]
        XCTAssertEqual(dict?["string"] as? String, "hello")
        XCTAssertEqual(dict?["int"] as? Int, 42)
        XCTAssertEqual(dict?["double"] as? Double, 3.14)
        XCTAssertEqual(dict?["bool"] as? Bool, true)
        XCTAssertTrue(dict?["null"] is NSNull)
        XCTAssertEqual(dict?["array"] as? [Int], [1, 2, 3])
        XCTAssertEqual((dict?["object"] as? [String: Any])?["nested"] as? String, "value")
    }

    func testControlMethodRawValues() {
        XCTAssertEqual(ControlMethod.play.rawValue, "play")
        XCTAssertEqual(ControlMethod.pause.rawValue, "pause")
        XCTAssertEqual(ControlMethod.togglePlayPause.rawValue, "toggle_play_pause")
        XCTAssertEqual(ControlMethod.openFile.rawValue, "open_file")
        XCTAssertEqual(ControlMethod.seek.rawValue, "seek")
        XCTAssertEqual(ControlMethod.setVolume.rawValue, "set_volume")
        XCTAssertEqual(ControlMethod.setSpeed.rawValue, "set_speed")
        XCTAssertEqual(ControlMethod.getState.rawValue, "get_state")
        XCTAssertEqual(ControlMethod.listAudioTracks.rawValue, "list_audio_tracks")
        XCTAssertEqual(ControlMethod.listSubtitleTracks.rawValue, "list_subtitle_tracks")
        XCTAssertEqual(ControlMethod.selectAudioTrack.rawValue, "select_audio_track")
        XCTAssertEqual(ControlMethod.selectSubtitleTrack.rawValue, "select_subtitle_track")
        XCTAssertEqual(ControlMethod.subtitlesOff.rawValue, "subtitles_off")
    }

    func testControlStateRoundTrip() throws {
        let state = ControlState(
            currentFile: "/Users/example/movie.mkv",
            isPaused: false,
            position: 123.45,
            duration: 3600,
            volume: 80,
            speed: 1.5,
            selectedAudioID: 2,
            selectedSubtitleID: 4,
            subtitlesVisible: true,
            activeSubtitleText: "Line one",
            audioTracks: [],
            subtitleTracks: []
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ControlState.self, from: data)

        XCTAssertEqual(decoded.currentFile, "/Users/example/movie.mkv")
        XCTAssertFalse(decoded.isPaused)
        XCTAssertEqual(decoded.position, 123.45, accuracy: 0.001)
        XCTAssertEqual(decoded.duration, 3600)
        XCTAssertEqual(decoded.volume, 80)
        XCTAssertEqual(decoded.speed, 1.5)
        XCTAssertEqual(decoded.selectedAudioID, 2)
        XCTAssertEqual(decoded.selectedSubtitleID, 4)
        XCTAssertTrue(decoded.subtitlesVisible)
        XCTAssertEqual(decoded.activeSubtitleText, "Line one")
        XCTAssertEqual(decoded.protocolVersion, 2)
    }

    func testControlPolicyRejectsMissingOpenPath() {
        XCTAssertNil(ControlCommandPolicy.validOpenPath(nil))
        XCTAssertNil(ControlCommandPolicy.validOpenPath(""))
        XCTAssertNil(ControlCommandPolicy.validOpenPath("   "))
    }

    func testControlPolicyRejectsNonAbsoluteOpenPath() {
        XCTAssertNil(ControlCommandPolicy.validAbsoluteOpenPath("movie.mkv"))
        XCTAssertNil(ControlCommandPolicy.validAbsoluteOpenPath("relative/dir/file.mkv"))
    }

    func testControlPolicyTrimsOpenPath() {
        XCTAssertEqual(ControlCommandPolicy.validOpenPath("  /Users/example/movie.mkv\n"), "/Users/example/movie.mkv")
        XCTAssertEqual(
            ControlCommandPolicy.validAbsoluteOpenPath("  /Users/example/movie.mkv\n"),
            "/Users/example/movie.mkv"
        )
    }

    func testControlPolicyValidatesTrackID() {
        XCTAssertNil(ControlCommandPolicy.validTrackID(nil))
        XCTAssertNil(ControlCommandPolicy.validTrackID(-1))
        XCTAssertEqual(ControlCommandPolicy.validTrackID(0), 0)
        XCTAssertEqual(ControlCommandPolicy.validTrackID(3), 3)
    }

    func testAnyCodableDecodesIntegerParams() throws {
        let params = AnyCodable(["id": 2])
        XCTAssertEqual(params.int(for: "id"), 2)
    }

    func testControlPolicyClampsVolumeAndSpeed() {
        XCTAssertEqual(ControlCommandPolicy.clampVolume(-10), 0)
        XCTAssertEqual(ControlCommandPolicy.clampVolume(80), 80)
        XCTAssertEqual(ControlCommandPolicy.clampVolume(200), 150)

        XCTAssertEqual(ControlCommandPolicy.clampSpeed(0.1), 0.25)
        XCTAssertEqual(ControlCommandPolicy.clampSpeed(1.25), 1.25)
        XCTAssertEqual(ControlCommandPolicy.clampSpeed(10), 4.0)
    }
}
