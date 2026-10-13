import Darwin
@testable import ValenControl
import XCTest

final class ControlSocketPeerPolicyTests: XCTestCase {
    func testSameUserConnectionIsAuthorized() throws {
        let path = NSTemporaryDirectory() + "valen-peer-test-\(UUID().uuidString).sock"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let serverFD = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(serverFD, 0)
        defer { close(serverFD) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8CString)
        _ = pathBytes.withUnsafeBufferPointer { src in
            withUnsafeMutablePointer(to: &addr.sun_path) { dest in
                memcpy(dest, src.baseAddress, src.count)
            }
        }

        let bindOK = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                Darwin.bind(serverFD, rebound, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
            }
        }
        XCTAssertTrue(bindOK)
        XCTAssertEqual(Darwin.listen(serverFD, 1), 0)

        let clientFD = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(clientFD, 0)
        defer { close(clientFD) }

        let connectOK = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                Darwin.connect(clientFD, rebound, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
            }
        }
        XCTAssertTrue(connectOK)

        var accepted = Darwin.accept(serverFD, nil, nil)
        XCTAssertGreaterThanOrEqual(accepted, 0)
        defer { close(accepted) }

        XCTAssertTrue(ControlSocketPeerPolicy.isAuthorized(clientFD: accepted))
    }
}
