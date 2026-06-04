import ValenControl
import XCTest

/// Integration tests against a running Valen GUI via the Unix control socket.
/// Skipped automatically when Valen is not running (CI-safe).
final class MCPLiveControlTests: XCTestCase {
    override func setUpWithError() throws {
        try MCPLiveTestSupport.requireValenRunning()
    }

    func testLiveGetStateReturnsProtocolV2Fields() throws {
        let response = try MCPLiveTestSupport.send("get_state", id: 101)
        let state = try MCPLiveTestSupport.stateDictionary(from: response)

        XCTAssertEqual(state["protocolVersion"] as? Int, 2)
        XCTAssertNotNil(state["isPaused"])
        XCTAssertNotNil(state["volume"])
        XCTAssertNotNil(state["speed"])
        XCTAssertNotNil(state["position"])
        XCTAssertNotNil(state["duration"])
        XCTAssertNotNil(state["subtitlesVisible"])
        XCTAssertNotNil(state["audioTracks"])
        XCTAssertNotNil(state["subtitleTracks"])
    }

    func testLiveListAudioTracksReturnsTracksArray() throws {
        let response = try MCPLiveTestSupport.send("list_audio_tracks", id: 102)
        let tracks = try MCPLiveTestSupport.tracksArray(from: response)
        // Empty when idle is valid; shape is what we guard.
        for track in tracks {
            XCTAssertNotNil(track["id"])
            XCTAssertEqual(track["kind"] as? String, "audio")
            XCTAssertNotNil(track["displayName"])
        }
    }

    func testLiveListSubtitleTracksReturnsTracksArray() throws {
        let response = try MCPLiveTestSupport.send("list_subtitle_tracks", id: 103)
        let tracks = try MCPLiveTestSupport.tracksArray(from: response)
        for track in tracks {
            XCTAssertNotNil(track["id"])
            XCTAssertEqual(track["kind"] as? String, "subtitle")
            XCTAssertNotNil(track["displayName"])
        }
    }

    func testLiveOpenFileRejectsRelativePath() throws {
        let response = try MCPLiveTestSupport.send(
            "open_file",
            params: ["path": AnyCodable("movie.mkv")],
            id: 104
        )
        XCTAssertEqual(response.id, 104)
        XCTAssertNotNil(response.error)
        XCTAssertTrue(response.error?.contains("absolute") == true)
    }

    func testLiveSubtitlesOffSucceeds() throws {
        let response = try MCPLiveTestSupport.send("subtitles_off", id: 105)
        XCTAssertNil(response.error)
    }

    func testLiveAllControlMethodsRespond() throws {
        let playbackMethods: Set<ControlMethod> = [
            .play, .pause, .togglePlayPause, .seek, .setVolume, .setSpeed
        ]
        let allowPlayback = ProcessInfo.processInfo.environment["VALEN_LIVE_PLAYBACK"] == "1"

        var id = 200
        for method in ControlMethod.allCases {
            if playbackMethods.contains(method), !allowPlayback {
                continue
            }
            id += 1
            switch method {
            case .openFile:
                let response = try MCPLiveTestSupport.send(
                    method.rawValue,
                    params: ["path": AnyCodable("not-absolute")],
                    id: id
                )
                XCTAssertNotNil(response.error, method.rawValue)
            case .selectAudioTrack, .selectSubtitleTrack:
                let response = try MCPLiveTestSupport.send(
                    method.rawValue,
                    params: ["id": AnyCodable(999_999)],
                    id: id
                )
                XCTAssertNotNil(response.error, method.rawValue)
            case .seek:
                let response = try MCPLiveTestSupport.send(
                    method.rawValue,
                    params: ["seconds": AnyCodable(0), "relative": AnyCodable(false)],
                    id: id
                )
                XCTAssertNil(response.error, method.rawValue)
            case .setVolume:
                let response = try MCPLiveTestSupport.send(
                    method.rawValue,
                    params: ["value": AnyCodable(100)],
                    id: id
                )
                XCTAssertNil(response.error, method.rawValue)
            case .setSpeed:
                let response = try MCPLiveTestSupport.send(
                    method.rawValue,
                    params: ["speed": AnyCodable(1.0)],
                    id: id
                )
                XCTAssertNil(response.error, method.rawValue)
            default:
                let response = try MCPLiveTestSupport.send(method.rawValue, id: id)
                XCTAssertNil(response.error, "\(method.rawValue): \(response.error ?? "")")
            }
        }
    }

    func testLivePlaybackRoundTripWhenEnabled() throws {
        guard ProcessInfo.processInfo.environment["VALEN_LIVE_PLAYBACK"] == "1" else {
            throw XCTSkip("Set VALEN_LIVE_PLAYBACK=1 to run play/pause integration checks.")
        }

        let pause = try MCPLiveTestSupport.send("pause", id: 301)
        XCTAssertNil(pause.error)

        let play = try MCPLiveTestSupport.send("play", id: 302)
        XCTAssertNil(play.error)

        let toggle = try MCPLiveTestSupport.send("toggle_play_pause", id: 303)
        XCTAssertNil(toggle.error)
    }

    func testLiveOpenFileWhenTestMediaConfigured() throws {
        guard let path = ProcessInfo.processInfo.environment["VALEN_TEST_MEDIA"],
              ControlCommandPolicy.validAbsoluteOpenPath(path) != nil else {
            throw XCTSkip("Set VALEN_TEST_MEDIA to an absolute media path to test open_file.")
        }

        let response = try MCPLiveTestSupport.send(
            "open_file",
            params: ["path": AnyCodable(path)],
            id: 401
        )
        XCTAssertNil(response.error)

        let state = try MCPLiveTestSupport.stateDictionary(
            from: try MCPLiveTestSupport.send("get_state", id: 402)
        )
        XCTAssertEqual(state["currentFile"] as? String, (path as NSString).standardizingPath)
    }
}