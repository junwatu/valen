# Valen v0.2.0

Valen v0.2.0 is the current public-preview line for the native macOS SwiftUI player powered by libmpv.

## Highlights

- Adds the bundled `valen-mcp` server for AI-agent control through MCP.
- Keeps QuickTime-style translucent overlay controls compact and centered.
- Supports audio and subtitle track popovers that keep the overlay visible while selecting.
- Saves per-video playback state, including resume position, volume, audio track, and subtitle track.
- Keeps native macOS file association support for common video and audio formats, including MKV.
- Includes the real Xcode app target and Swift Package build path using the same source files.

## Build

The default distributable artifact is:

```text
dist/Valen-0.2.0-macos-arm64.zip
```

## Known Limitations

- The default local package is ad-hoc signed unless a Developer ID identity is passed to `Scripts/build-app.sh`.
- Notarization requires Apple Developer credentials and `Scripts/notarize-app.sh`.
- Sparkle update metadata is scaffolded, but Sparkle is not fully embedded for production updates yet.
- Rendering still uses `NSOpenGLView`; Metal rendering remains future work.
- Add `THIRD_PARTY_NOTICES.md` before a broader public binary release.
