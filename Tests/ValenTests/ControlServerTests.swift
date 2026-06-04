@testable import Valen
@testable import ValenControl
import XCTest

@MainActor
final class ControlServerTests: XCTestCase {
    private var player: PlayerModel!
    private var server: ControlServer!
    private var socketURL: URL!
    private var socketPath: String!

    override func setUp() async throws {
        player = PlayerModel()
        socketPath = NSTemporaryDirectory() + "valen-test-\(UUID().uuidString).sock"
        socketURL = URL(fileURLWithPath: socketPath)
        server = ControlServer(player: player, socketURL: socketURL)
        try server.start()
    }

    override func tearDown() async throws {
        server?.stop()
        player = nil
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    private func sendOnBackground(_ request: ControlRequest) throws -> ControlResponse? {
        let client = ControlClient(socketURL: socketURL)
        let exp = expectation(description: "send")
        var result: Result<ControlResponse, Error>!
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                result = .success(try client.send(request))
            } catch {
                result = .failure(error)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
        return try result.get()
    }

    func testPlayCommandRoundTrip() throws {
        let request = ControlRequest(id: 1, method: "play", params: [:])
        let response = try XCTUnwrap(sendOnBackground(request))
        XCTAssertNil(response.error)
        XCTAssertEqual(response.id, 1)
    }

    func testUnknownMethodReturnsFailure() throws {
        let request = ControlRequest(id: 7, method: "nope", params: [:])
        let response = try XCTUnwrap(sendOnBackground(request))
        XCTAssertEqual(response.id, 7)
        XCTAssertNotNil(response.error)
        XCTAssertTrue(response.error?.contains("unknown method") == true)
    }

    func testRequestLargerThanMaxIsRejected() throws {
        let oversized = String(repeating: "x", count: ControlServer.maxRequestBytes)
        let request = ControlRequest(id: 2, method: "play", params: ["pad": AnyCodable(oversized)])
        let response = try XCTUnwrap(sendOnBackground(request))
        XCTAssertEqual(response.id, 0)
        XCTAssertEqual(response.error, "request too large")
    }

    func testOpenFileRejectsRelativePath() throws {
        let request = ControlRequest(
            id: 3,
            method: "open_file",
            params: ["path": AnyCodable("movie.mkv")]
        )
        let response = try XCTUnwrap(sendOnBackground(request))
        XCTAssertEqual(response.id, 3)
        XCTAssertNotNil(response.error)
        XCTAssertTrue(response.error?.contains("absolute") == true)
    }

    func testGetStateReturnsRichFields() throws {
        let request = ControlRequest(id: 4, method: "get_state", params: [:])
        let response = try XCTUnwrap(sendOnBackground(request))
        XCTAssertNil(response.error)

        let dict = try XCTUnwrap(response.result?.value as? [String: Any])
        XCTAssertEqual(dict["protocolVersion"] as? Int, 2)
        XCTAssertNotNil(dict["audioTracks"])
        XCTAssertNotNil(dict["subtitleTracks"])
        XCTAssertNotNil(dict["subtitlesVisible"])
    }

    func testListAudioTracksReturnsTracksKey() throws {
        let request = ControlRequest(id: 5, method: "list_audio_tracks", params: [:])
        let response = try XCTUnwrap(sendOnBackground(request))
        XCTAssertNil(response.error)
        let dict = try XCTUnwrap(response.result?.value as? [String: Any])
        XCTAssertTrue(dict["tracks"] is [Any])
    }

    func testControlActionIsLogged() throws {
        _ = try sendOnBackground(ControlRequest(id: 6, method: "pause", params: [:]))
        let lines = player.debugLines.joined(separator: "\n")
        XCTAssertTrue(lines.contains("[control] pause"))
    }
}
