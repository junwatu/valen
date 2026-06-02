@testable import ValenControl
import XCTest

final class ControlClientTests: XCTestCase {
    func testNotRunningWhenSocketMissing() {
        let path = NSTemporaryDirectory() + "valen-missing-\(UUID().uuidString).sock"
        let client = ControlClient(socketURL: URL(fileURLWithPath: path))
        let request = ControlRequest(id: 1, method: "play", params: [:])

        XCTAssertThrowsError(try client.send(request)) { error in
            guard let clientError = error as? ControlClientError else {
                XCTFail("Expected ControlClientError, got \(error)")
                return
            }
            switch clientError {
            case .notRunning:
                break
            case .decodeFailed, .disconnected:
                XCTFail("Expected .notRunning, got \(clientError)")
            }
        }
    }

    func testIsServerRunningReportsFalseForMissingSocket() {
        let path = NSTemporaryDirectory() + "valen-missing-\(UUID().uuidString).sock"
        let client = ControlClient(socketURL: URL(fileURLWithPath: path))
        XCTAssertFalse(client.isServerRunning())
    }
}
