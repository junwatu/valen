import AppKit
import Foundation
#if SWIFT_PACKAGE
import ValenControl
#endif

final class ControlServer: @unchecked Sendable {
    static let maxRequestBytes = 1_048_576

    private let player: PlayerModel
    private let socketURL: URL
    private let queue = DispatchQueue(label: "dev.valen.control.io", qos: .userInitiated)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var acceptThread: Thread?
    private var stopped = false

    init(player: PlayerModel, socketURL: URL = ControlConstants.socketURL) {
        self.player = player
        self.socketURL = socketURL
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard listenFD == -1 else { return }

        try? FileManager.default.removeItem(at: socketURL)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw ControlServerError.socketFailed(errno)
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketURL.path.utf8) + [0]
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw ControlServerError.pathTooLong
        }
        _ = pathBytes.withUnsafeBufferPointer { src in
            withUnsafeMutablePointer(to: &addr.sun_path) { dest in
                memcpy(dest, src.baseAddress, src.count)
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                Darwin.bind(fd, rebound, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            let code = errno
            close(fd)
            throw ControlServerError.bindFailed(code)
        }

        guard listen(fd, 16) == 0 else {
            let code = errno
            close(fd)
            throw ControlServerError.listenFailed(code)
        }

        listenFD = fd

        let thread = Thread { [weak self] in
            self?.acceptLoop()
        }
        thread.name = "dev.valen.control.accept"
        thread.start()
        acceptThread = thread

        NSLog("[valen] control server listening at \(socketURL.path)")
    }

    func stop() {
        lock.lock()
        stopped = true
        let fd = listenFD
        listenFD = -1
        lock.unlock()

        if fd >= 0 {
            shutdown(fd, SHUT_RDWR)
            close(fd)
        }
        try? FileManager.default.removeItem(at: socketURL)
    }

    private func currentListenFD() -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        return listenFD
    }

    private func isStopped() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    private func acceptLoop() {
        while !isStopped() {
            let fd = currentListenFD()
            guard fd >= 0 else { return }
            var addr = sockaddr()
            var len = socklen_t(MemoryLayout<sockaddr>.size)
            let clientFD = accept(fd, &addr, &len)
            if clientFD < 0 {
                if isStopped() { return }
                if errno == EINTR { continue }
                NSLog("[valen] control accept failed: errno=\(errno)")
                return
            }
            queue.async { [weak self] in
                self?.handleConnection(clientFD)
            }
        }
    }

    private func handleConnection(_ fd: Int32) {
        defer { close(fd) }

        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        _ = withUnsafePointer(to: &timeout) { ptr -> Int32 in
            ptr.withMemoryRebound(to: timeval.self, capacity: 1) { rebound in
                setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, rebound, socklen_t(MemoryLayout<timeval>.size))
            }
        }

        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = buffer.withUnsafeMutableBufferPointer { buf -> Int in
                Darwin.read(fd, buf.baseAddress, buf.count)
            }
            if n > 0 {
                if received.count + n > ControlServer.maxRequestBytes {
                    writeResponse(fd: fd, response: .fail(id: 0, message: "request too large"))
                    return
                }
                received.append(buffer, count: n)
            } else {
                break
            }
        }

        guard let text = String(data: received, encoding: .utf8) else {
            writeResponse(fd: fd, response: .fail(id: 0, message: "request was not valid UTF-8"))
            return
        }

        let lines = text.split(whereSeparator: { $0 == "\n" }).map(String.init)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8) else { continue }
            do {
                let request = try decoder.decode(ControlRequest.self, from: data)
                let response = handleOnMain(request)
                writeResponse(fd: fd, response: response)
            } catch {
                writeResponse(fd: fd, response: .fail(id: 0, message: "decode error: \(error.localizedDescription)"))
            }
        }
    }

    private func handleOnMain(_ request: ControlRequest) -> ControlResponse {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { handleOnMainActor(request) }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { handleOnMainActor(request) }
        }
    }

    @MainActor
    private func handleOnMainActor(_ request: ControlRequest) -> ControlResponse {
        let id = request.id
        let method = request.method
        let params = AnyCodable(request.params ?? [:])
        player.logControlAction(method, detail: Self.paramsSummary(params))

        switch method {
        case ControlMethod.play.rawValue:
            player.setPaused(false)
            return .ok(id: id)

        case ControlMethod.pause.rawValue:
            player.setPaused(true)
            return .ok(id: id)

        case ControlMethod.togglePlayPause.rawValue:
            player.togglePlayPause()
            return .ok(id: id)

        case ControlMethod.openFile.rawValue:
            guard let path = ControlCommandPolicy.validAbsoluteOpenPath(params.string(for: "path")) else {
                return .fail(id: id, message: "missing or non-absolute 'path' (must start with /)")
            }
            player.load(URL(fileURLWithPath: path))
            player.activateMainWindow()
            return .ok(id: id)

        case ControlMethod.seek.rawValue:
            guard let seconds = params.double(for: "seconds") else {
                return .fail(id: id, message: "missing 'seconds'")
            }
            let relative = params.bool(for: "relative") ?? false
            if relative {
                player.seek(relativeSeconds: seconds)
            } else {
                player.scrub(to: seconds)
            }
            return .ok(id: id)

        case ControlMethod.setVolume.rawValue:
            guard let value = params.double(for: "value") else {
                return .fail(id: id, message: "missing 'value'")
            }
            let clamped = ControlCommandPolicy.clampVolume(value)
            player.volume = clamped
            player.setVolume(clamped)
            return .ok(id: id)

        case ControlMethod.setSpeed.rawValue:
            guard let speed = params.double(for: "speed") else {
                return .fail(id: id, message: "missing 'speed'")
            }
            player.setSpeed(ControlCommandPolicy.clampSpeed(speed))
            return .ok(id: id)

        case ControlMethod.getState.rawValue:
            return .ok(id: id, result: AnyCodable(player.snapshot().jsonDictionary))

        case ControlMethod.listAudioTracks.rawValue:
            return trackListResponse(id: id, tracks: player.audioTracks.map(\.controlInfo))

        case ControlMethod.listSubtitleTracks.rawValue:
            return trackListResponse(id: id, tracks: player.subtitleTracks.map(\.controlInfo))

        case ControlMethod.selectAudioTrack.rawValue:
            guard let trackID = ControlCommandPolicy.validTrackID(params.int(for: "id")) else {
                return .fail(id: id, message: "missing or invalid 'id'")
            }
            guard let track = player.audioTracks.first(where: { $0.id == trackID }) else {
                return .fail(id: id, message: "unknown audio track id \(trackID)")
            }
            player.selectAudioTrack(track)
            return .ok(id: id)

        case ControlMethod.selectSubtitleTrack.rawValue:
            guard let trackID = ControlCommandPolicy.validTrackID(params.int(for: "id")) else {
                return .fail(id: id, message: "missing or invalid 'id'")
            }
            guard let track = player.subtitleTracks.first(where: { $0.id == trackID }) else {
                return .fail(id: id, message: "unknown subtitle track id \(trackID)")
            }
            player.selectSubtitleTrack(track)
            return .ok(id: id)

        case ControlMethod.subtitlesOff.rawValue:
            player.selectSubtitleTrack(nil)
            return .ok(id: id)

        default:
            return .fail(id: id, message: "unknown method '\(method)'")
        }
    }

    @MainActor
    private func trackListResponse(id: Int, tracks: [ControlTrackInfo]) -> ControlResponse {
        guard let data = try? JSONEncoder().encode(["tracks": tracks]),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .fail(id: id, message: "failed to encode track list")
        }
        return .ok(id: id, result: AnyCodable(dict))
    }

    private static func paramsSummary(_ params: AnyCodable) -> String? {
        guard let dict = params.value as? [String: Any], !dict.isEmpty else {
            return nil
        }
        let parts = dict.keys.sorted().compactMap { key -> String? in
            guard let value = dict[key] else { return nil }
            return "\(key)=\(value)"
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func writeResponse(fd: Int32, response: ControlResponse) {
        guard let data = try? encoder.encode(response) else { return }
        var line = data
        line.append(0x0A)
        _ = line.withUnsafeBytes { raw -> Int in
            Darwin.write(fd, raw.baseAddress, raw.count)
        }
        shutdown(fd, SHUT_WR)
    }
}

enum ControlServerError: Error, LocalizedError {
    case socketFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)
    case pathTooLong

    var errorDescription: String? {
        switch self {
        case .socketFailed(let code):
            return "Failed to create control socket (errno=\(code))."
        case .bindFailed(let code):
            return "Failed to bind control socket (errno=\(code))."
        case .listenFailed(let code):
            return "Failed to listen on control socket (errno=\(code))."
        case .pathTooLong:
            return "Control socket path is too long."
        }
    }
}
