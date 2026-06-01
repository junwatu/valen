import Foundation

public enum ControlClientError: Error, LocalizedError {
    case notRunning
    case decodeFailed(String)
    case disconnected

    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Valen is not running (no control socket at \(ControlConstants.socketURL.path))."
        case .decodeFailed(let message):
            return "Failed to decode control response: \(message)"
        case .disconnected:
            return "Control socket disconnected before a response was received."
        }
    }
}

public final class ControlClient: @unchecked Sendable {
    private let socketURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(socketURL: URL = ControlConstants.socketURL) {
        self.socketURL = socketURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func isServerRunning() -> Bool {
        FileManager.default.fileExists(atPath: socketURL.path)
    }

    public func send(_ request: ControlRequest) throws -> ControlResponse {
        guard isServerRunning() else {
            throw ControlClientError.notRunning
        }

        let data = try encoder.encode(request)
        guard var line = String(data: data, encoding: .utf8) else {
            throw ControlClientError.decodeFailed("request was not valid UTF-8")
        }
        line.append("\n")

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw ControlClientError.disconnected
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketURL.path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            throw ControlClientError.disconnected
        }
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { rebound in
                _ = pathBytes.withUnsafeBufferPointer { src in
                    memcpy(rebound, src.baseAddress, src.count)
                }
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                Darwin.connect(fd, rebound, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else {
            throw ControlClientError.notRunning
        }

        let payload = Data(line.utf8)
        let written = payload.withUnsafeBytes { raw -> Int in
            Darwin.write(fd, raw.baseAddress, raw.count)
        }
        guard written == payload.count else {
            throw ControlClientError.disconnected
        }

        shutdown(fd, SHUT_WR)

        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = buffer.withUnsafeMutableBufferPointer { buf -> Int in
                Darwin.read(fd, buf.baseAddress, buf.count)
            }
            if n > 0 {
                received.append(buffer, count: n)
            } else {
                break
            }
        }

        guard let text = String(data: received, encoding: .utf8) else {
            throw ControlClientError.decodeFailed("response was not valid UTF-8")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let responseData = trimmed.data(using: .utf8) else {
            throw ControlClientError.decodeFailed("response was empty")
        }

        do {
            return try decoder.decode(ControlResponse.self, from: responseData)
        } catch {
            throw ControlClientError.decodeFailed(error.localizedDescription)
        }
    }
}
