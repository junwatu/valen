import Foundation
import ValenControl
import XCTest

enum MCPLiveTestSupport {
    static let skipMessage = """
    Valen is not running. Launch the Valen GUI (swift run valen or Valen.app), then run:
      swift test --filter MCPLive
    or:
      Scripts/test-mcp-live.sh
    Control socket expected at: \(ControlConstants.socketURL.path)
    """

    static var isValenRunning: Bool {
        ControlClient().isServerRunning()
    }

    static func requireValenRunning() throws {
        guard isValenRunning else {
            throw XCTSkip(skipMessage)
        }
    }

    static func requireMCPEndpoint() throws -> URL {
        guard let url = mcpExecutableURL() else {
            throw XCTSkip("valen-mcp not built. Run: swift build")
        }
        return url
    }

    static func mcpExecutableURL() -> URL? {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            root.appendingPathComponent(".build/debug/valen-mcp"),
            root.appendingPathComponent(".build/arm64-apple-macosx/debug/valen-mcp"),
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func send(_ method: String, params: [String: AnyCodable] = [:], id: Int = 1) throws -> ControlResponse {
        let client = ControlClient()
        return try client.send(ControlRequest(id: id, method: method, params: params))
    }

    static func stateDictionary(from response: ControlResponse) throws -> [String: Any] {
        XCTAssertNil(response.error, "control error: \(response.error ?? "")")
        return try XCTUnwrap(response.result?.value as? [String: Any])
    }

    static func tracksArray(from response: ControlResponse) throws -> [[String: Any]] {
        let dict = try stateDictionary(from: response)
        let tracks = try XCTUnwrap(dict["tracks"] as? [Any])
        return tracks.compactMap { $0 as? [String: Any] }
    }

    @discardableResult
    static func runMCPLines(_ lines: [String]) throws -> String {
        let executable = try requireMCPEndpoint()
        let process = Process()
        process.executableURL = executable
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        try process.run()

        let inputHandle = inputPipe.fileHandleForWriting
        for line in lines {
            inputHandle.write(Data((line + "\n").utf8))
        }
        try inputHandle.close()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: outputData, encoding: .utf8) ?? ""
    }

    static func parseJSONLines(_ text: String) -> [[String: Any]] {
        text
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> [String: Any]? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      let data = trimmed.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return nil
                }
                return object
            }
    }

    static func mcpToolCallLines(tool: String, arguments: [String: Any] = [:], id: Int = 2) -> [String] {
        let argsJSON: String
        if arguments.isEmpty {
            argsJSON = "{}"
        } else if let data = try? JSONSerialization.data(withJSONObject: arguments, options: [.sortedKeys]),
                  let json = String(data: data, encoding: .utf8) {
            argsJSON = json
        } else {
            argsJSON = "{}"
        }
        return [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"valen-test","version":"0.0.1"}}}"#,
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            #"{"jsonrpc":"2.0","id":\#(id),"method":"tools/call","params":{"name":"\#(tool)","arguments":\#(argsJSON)}}"#,
        ]
    }
}