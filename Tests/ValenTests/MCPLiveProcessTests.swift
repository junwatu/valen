import ValenControl
import XCTest

/// Integration tests that spawn the valen-mcp stdio server (same path Claude uses).
final class MCPLiveProcessTests: XCTestCase {
    func testMCPToolsListExposesThirteenTools() throws {
        let output = try MCPLiveTestSupport.runMCPLines([
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"valen-test","version":"0.0.1"}}}"#,
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#,
        ])

        let messages = MCPLiveTestSupport.parseJSONLines(output)
        let toolsList = messages.first { ($0["id"] as? Int) == 2 }
        let result = try XCTUnwrap(toolsList?["result"] as? [String: Any])
        let tools = try XCTUnwrap(result["tools"] as? [[String: Any]])
        let names = Set(tools.compactMap { $0["name"] as? String })

        XCTAssertEqual(tools.count, 13)
        XCTAssertEqual(names.count, 13)
        for method in ControlMethod.allCases {
            XCTAssertTrue(names.contains(method.rawValue), "missing MCP tool: \(method.rawValue)")
        }
    }

    func testMCPGetStateReportsNotRunningWithoutValen() throws {
        try XCTSkipIf(
            MCPLiveTestSupport.isValenRunning,
            "Valen is running; skip not-running MCP error test."
        )

        let output = try MCPLiveTestSupport.runMCPLines(
            MCPLiveTestSupport.mcpToolCallLines(tool: "get_state")
        )
        let messages = MCPLiveTestSupport.parseJSONLines(output)
        let call = messages.first { ($0["id"] as? Int) == 2 }
        let result = try XCTUnwrap(call?["result"] as? [String: Any])
        let content = try XCTUnwrap(result["content"] as? [[String: Any]])
        let text = try XCTUnwrap(content.first?["text"] as? String)
        XCTAssertEqual(result["isError"] as? Bool, true)
        XCTAssertTrue(text.localizedCaseInsensitiveContains("not running"))
    }

    func testMCPGetStateSucceedsWhileValenRuns() throws {
        try MCPLiveTestSupport.requireValenRunning()

        let output = try MCPLiveTestSupport.runMCPLines(
            MCPLiveTestSupport.mcpToolCallLines(tool: "get_state")
        )
        let messages = MCPLiveTestSupport.parseJSONLines(output)
        let call = messages.first { ($0["id"] as? Int) == 2 }
        let result = try XCTUnwrap(call?["result"] as? [String: Any])
        XCTAssertEqual(result["isError"] as? Bool, false)

        let content = try XCTUnwrap(result["content"] as? [[String: Any]])
        let text = try XCTUnwrap(content.first?["text"] as? String)
        let data = try XCTUnwrap(text.data(using: .utf8))
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(state["protocolVersion"] as? Int, 2)
    }

    func testMCPListSubtitleTracksWhileValenRuns() throws {
        try MCPLiveTestSupport.requireValenRunning()

        let output = try MCPLiveTestSupport.runMCPLines(
            MCPLiveTestSupport.mcpToolCallLines(tool: "list_subtitle_tracks", id: 3)
        )
        let messages = MCPLiveTestSupport.parseJSONLines(output)
        let call = messages.first { ($0["id"] as? Int) == 3 }
        let result = try XCTUnwrap(call?["result"] as? [String: Any])
        XCTAssertEqual(result["isError"] as? Bool, false)

        let content = try XCTUnwrap(result["content"] as? [[String: Any]])
        let text = try XCTUnwrap(content.first?["text"] as? String)
        let data = try XCTUnwrap(text.data(using: .utf8))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(payload["tracks"])
    }
}