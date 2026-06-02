import Foundation
import XCTest

final class ReleaseMetadataTests: XCTestCase {
    private let expectedVersion = "0.2.0"
    private let expectedBuild = "3"

    func testVersionMetadataIsAlignedAcrossReleaseFiles() throws {
        let files = try releaseFiles()

        XCTAssertContains(files.buildScript, #"VERSION="${VERSION:-0.2.0}""#)
        XCTAssertContains(files.notarizeScript, "Valen-0.2.0-macos-arm64.zip")
        XCTAssertContains(files.readme, "dist/Valen-0.2.0-macos-arm64.zip")
        XCTAssertContains(files.releaseNotes, "# Valen v0.2.0")
        XCTAssertContains(files.releaseNotes, "dist/Valen-0.2.0-macos-arm64.zip")
        XCTAssertContains(files.mcpServer, #""version": "0.2.0""#)

        let marketingVersionMatches = files.xcodeProject.matches(of: /MARKETING_VERSION = ([^;]+);/)
        XCTAssertEqual(marketingVersionMatches.map { String($0.1) }, [expectedVersion, expectedVersion])

        let buildNumberMatches = files.xcodeProject.matches(of: /CURRENT_PROJECT_VERSION = ([^;]+);/)
        XCTAssertEqual(buildNumberMatches.map { String($0.1) }, [expectedBuild, expectedBuild])
    }

    func testAppcastExamplePointsAtCurrentArtifact() throws {
        let appcast = try releaseFiles().appcast
        let document = try XMLDocument(xmlString: appcast)
        let item = try XCTUnwrap(document.rootElement()?.elements(forName: "channel").first?.elements(forName: "item").first)
        let enclosure = try XCTUnwrap(item.elements(forName: "enclosure").first)

        XCTAssertEqual(item.elements(forName: "title").first?.stringValue, "Version 0.2.0")
        XCTAssertEqual(item.elements(forName: "sparkle:version").first?.stringValue, expectedBuild)
        XCTAssertEqual(item.elements(forName: "sparkle:shortVersionString").first?.stringValue, expectedVersion)
        XCTAssertEqual(enclosure.attribute(forName: "url")?.stringValue, "https://example.com/valen/Valen-0.2.0-macos-arm64.zip")
    }

    func testBuildScriptDeclaresExpectedBundleDocumentTypes() throws {
        let buildScript = try releaseFiles().buildScript

        XCTAssertContains(buildScript, "<key>CFBundleDocumentTypes</key>")
        XCTAssertContains(buildScript, "<key>UTImportedTypeDeclarations</key>")
        XCTAssertContains(buildScript, "<string>org.matroska.mkv</string>")
        XCTAssertContains(buildScript, "<string>org.webmproject.webm</string>")
        XCTAssertContains(buildScript, "<string>org.xiph.flac</string>")
        XCTAssertContains(buildScript, "<key>LSHandlerRank</key>")

        for fileExtension in ["mkv", "mka", "webm", "mp4", "mov", "m4v", "avi", "flv", "wmv", "mp3", "flac", "ogg", "wav"] {
            XCTAssertContains(buildScript, "<string>\(fileExtension)</string>")
        }
    }

    private func releaseFiles() throws -> ReleaseFiles {
        let root = repositoryRoot()
        return ReleaseFiles(
            buildScript: try read("Scripts/build-app.sh", from: root),
            notarizeScript: try read("Scripts/notarize-app.sh", from: root),
            readme: try read("README.md", from: root),
            releaseNotes: try read("RELEASE_NOTES_v0.2.0.md", from: root),
            mcpServer: try read("Packaging/Sources/valen-mcp/main.swift", from: root),
            xcodeProject: try read("Valen.xcodeproj/project.pbxproj", from: root),
            appcast: try read("Packaging/appcast.example.xml", from: root)
        )
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func read(_ relativePath: String, from root: URL) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func XCTAssertContains(
        _ haystack: String,
        _ needle: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            haystack.contains(needle),
            "Expected file contents to contain: \(needle)",
            file: file,
            line: line
        )
    }
}

private struct ReleaseFiles {
    let buildScript: String
    let notarizeScript: String
    let readme: String
    let releaseNotes: String
    let mcpServer: String
    let xcodeProject: String
    let appcast: String
}
