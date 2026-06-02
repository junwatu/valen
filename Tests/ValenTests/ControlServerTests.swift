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
}
