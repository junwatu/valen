import Foundation
import ValenControl

struct MCPRequest: Decodable {
    let jsonrpc: String
    let id: AnyCodable?
    let method: String
    let params: AnyCodable?
}

struct MCPResponse: Codable {
    let jsonrpc: String = "2.0"
    let id: AnyCodable?
    let result: AnyCodable?
    let error: MCPError?
}

struct MCPError: Codable {
    let code: Int
    let message: String
}

struct ToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: AnyCodable
}

struct ToolCallResult: Codable {
    let content: [TextContent]
    let isError: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case isError = "isError"
    }
}

struct TextContent: Codable {
    let type: String
    let text: String
}

let serverInfo: [String: String] = [
    "name": "valen-mcp",
    "version": "0.2.1"
]

let protocolVersion = "2024-11-05"

let tools: [ToolDefinition] = [
    ToolDefinition(
        name: "play",
        description: "Start or resume playback in the Valen player.",
        inputSchema: AnyCodable([
            "type": "object",
            "properties": [String: String](),
            "additionalProperties": false
        ])
    ),
    ToolDefinition(
        name: "pause",
        description: "Pause playback in the Valen player.",
        inputSchema: AnyCodable([
            "type": "object",
            "properties": [String: String](),
            "additionalProperties": false
        ])
    ),
    ToolDefinition(
        name: "toggle_play_pause",
        description: "Toggle play/pause in the Valen player.",
        inputSchema: AnyCodable([
            "type": "object",
            "properties": [String: String](),
            "additionalProperties": false
        ])
    ),
    ToolDefinition(
        name: "open_file",
        description: "Open a media file in the Valen player. The path must be accessible to the Valen GUI process (e.g. on the same machine).",
        inputSchema: AnyCodable([
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Absolute filesystem path to the media file."
                ]
            ],
            "required": ["path"],
            "additionalProperties": false
        ])
    ),
    ToolDefinition(
        name: "seek",
        description: "Seek to an absolute position (seconds) or by a relative offset (seconds, signed).",
        inputSchema: AnyCodable([
            "type": "object",
            "properties": [
                "seconds": [
                    "type": "number",
                    "description": "Target time in seconds. With relative=true, signed offset in seconds."
                ],
                "relative": [
                    "type": "boolean",
                    "description": "If true, treat seconds as a signed relative offset. Defaults to false (absolute seek).",
                    "default": false
                ]
            ],
            "required": ["seconds"],
            "additionalProperties": false
        ])
    ),
    ToolDefinition(
        name: "set_volume",
        description: "Set the player volume. Range 0-150 (100 is unity gain; values above 100 are software boost).",
        inputSchema: AnyCodable([
            "type": "object",
            "properties": [
                "value": [
                    "type": "number",
                    "minimum": 0,
                    "maximum": 150,
                    "description": "Target volume."
                ]
            ],
            "required": ["value"],
            "additionalProperties": false
        ])
    ),
    ToolDefinition(
        name: "set_speed",
        description: "Set the playback speed multiplier. Range 0.25-4.0.",
        inputSchema: AnyCodable([
            "type": "object",
            "properties": [
                "speed": [
                    "type": "number",
                    "minimum": 0.25,
                    "maximum": 4.0,
                    "description": "Target speed multiplier. 1.0 is normal."
                ]
            ],
            "required": ["speed"],
            "additionalProperties": false
        ])
    ),
    ToolDefinition(
        name: "get_state",
        description: "Read the current player state: paused, position, duration, volume, speed, and the file path if any.",
        inputSchema: AnyCodable([
            "type": "object",
            "properties": [String: String](),
            "additionalProperties": false
        ])
    )
]

let toolByName: [String: ToolDefinition] = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })

let client = ControlClient()

func jsonLine(_ data: Data) {
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
}

func send(_ response: MCPResponse) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    do {
        let data = try encoder.encode(response)
        jsonLine(data)
    } catch {
        FileHandle.standardError.write(Data("valen-mcp: failed to encode response: \(error)\n".utf8))
        if let idValue = response.id {
            let fallback = "{\"error\":\"internal encode failure\",\"id\":\(encodeJSON(idValue))}\n"
            if let data = fallback.data(using: .utf8) {
                FileHandle.standardOutput.write(data)
            }
        }
    }
}

func encodeJSON(_ value: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
          let string = String(data: data, encoding: .utf8) else {
        return "null"
    }
    return string
}

func fail(id: AnyCodable?, code: Int, message: String) -> MCPResponse {
    MCPResponse(id: id, result: nil, error: MCPError(code: code, message: message))
}

func handle(_ request: MCPRequest) {
    switch request.method {
    case "initialize":
        let result: [String: Any] = [
            "protocolVersion": protocolVersion,
            "capabilities": ["tools": [String: String]()],
            "serverInfo": serverInfo
        ]
        send(MCPResponse(id: request.id, result: AnyCodable(result), error: nil))

    case "notifications/initialized":
        break

    case "ping":
        send(MCPResponse(id: request.id, result: AnyCodable([String: String]()), error: nil))

    case "tools/list":
        sendToolsList(id: request.id)

    case "tools/call":
        guard let params = request.params?.value as? [String: Any],
              let name = params["name"] as? String,
              let tool = toolByName[name] else {
            send(fail(id: request.id, code: -32602, message: "Unknown tool"))
            return
        }
        let arguments = (params["arguments"] as? [String: Any]) ?? [:]
        executeToolCall(id: request.id, tool: tool, arguments: arguments)

    default:
        send(fail(id: request.id, code: -32601, message: "Method not found: \(request.method)"))
    }
}

func sendToolsList(id: AnyCodable?) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    do {
        let data = try encoder.encode(["tools": tools])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        send(MCPResponse(id: id, result: AnyCodable(json), error: nil))
    } catch {
        send(fail(id: id, code: -32603, message: "Failed to serialize tools: \(error.localizedDescription)"))
    }
}

func executeToolCall(id: AnyCodable?, tool: ToolDefinition, arguments: [String: Any]) {
    let params = arguments.mapValues { AnyCodable($0) }
    let controlRequest = ControlRequest(id: 1, method: tool.name, params: params)

    do {
        let response = try client.send(controlRequest)
        if let error = response.error {
            let result = ToolCallResult(
                content: [TextContent(type: "text", text: "Valen: \(error)")],
                isError: true
            )
            sendResult(id: id, result: result)
            return
        }

        let resultValue: Any
        if let result = response.result?.value, !(result is [String: String]) {
            resultValue = result
        } else {
            resultValue = ["ok": true]
        }
        let text: String
        if let dict = resultValue as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let pretty = String(data: data, encoding: .utf8) {
            text = pretty
        } else {
            text = "\(resultValue)"
        }
        let result = ToolCallResult(
            content: [TextContent(type: "text", text: text)],
            isError: false
        )
        sendResult(id: id, result: result)
    } catch let error as ControlClientError {
        let text: String
        if case .notRunning = error {
            text = "Valen is not running. Launch the Valen GUI first, then try again."
        } else {
            text = "Valen control error: \(error.localizedDescription)"
        }
        let result = ToolCallResult(
            content: [TextContent(type: "text", text: text)],
            isError: true
        )
        sendResult(id: id, result: result)
    } catch {
        let result = ToolCallResult(
            content: [TextContent(type: "text", text: "Internal error: \(error.localizedDescription)")],
            isError: true
        )
        sendResult(id: id, result: result)
    }
}

func sendResult(id: AnyCodable?, result: ToolCallResult) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    do {
        let data = try encoder.encode(result)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        send(MCPResponse(id: id, result: AnyCodable(json), error: nil))
    } catch {
        FileHandle.standardError.write(Data("valen-mcp: failed to serialize result: \(error)\n".utf8))
    }
}

let decoder = JSONDecoder()

while let line = readLine() {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { continue }
    guard let data = trimmed.data(using: .utf8) else { continue }
    do {
        let request = try decoder.decode(MCPRequest.self, from: data)
        handle(request)
    } catch {
        FileHandle.standardError.write(Data("valen-mcp: failed to decode line: \(error)\n".utf8))
    }
}
