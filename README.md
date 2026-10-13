<p align="center">
    <img src="Icons/Valen-iOS-ClearDark-1024x1024@1x.png" width="138" alt="Valen"/>
</p>

<h1 align="center">Valen</h1>

<p align="center">
    <strong>A native macOS media player built with SwiftUI and powered by libmpv.<br/>
    Single-window, single-player design with video-first controls, a compact mini-player mode, MKV support, subtitles, audio tracks, per-video resume state, and an MCP server for AI agent control.</strong>
</p>

<div align="center">
    <a href="https://github.com/junwatu/valen">
        <img alt="Platform" src="https://img.shields.io/badge/platform-macOS-lightgrey">
    </a>
    <a href="LICENSE">
        <img alt="License" src="https://img.shields.io/badge/license-MIT-blue">
    </a>
    <img alt="SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-orange">
    <img alt="mpv" src="https://img.shields.io/badge/player-libmpv-green">
</div>

## Features

- Native SwiftUI macOS app
- mpv playback through `libmpv`
- **Single window, single player** — one main player window and one playback session
- Opening another video replaces the current file (resume state is saved first)
- Single app instance — a second launch activates the running Valen instead of starting another player
- MKV, WebM, MP4, MOV, AVI, FLAC, OGG, WAV, and common media extension support
- Open files with `Command-O`, Finder, or drag and drop
- Compact QuickTime-style translucent overlay controls
- Responsive compact mode for small windows (single-row layout, 480×280 minimum)
- Overlay auto-hides during playback when the pointer is idle
- Cursor hides when playback controls hide
- Display sleep is prevented while media is actively playing
- Fullscreen support through shortcut, double-click, or macOS window controls
- Audio track selector
- Subtitle track selector
- External subtitle files (`.srt`, `.ass`, `.ssa`, `.vtt`, and more) via menu, drag-and-drop, or auto-load when `Movie.srt` sits beside `Movie.mkv`
- Native Settings window (separate from the player window)
- Per-video saved state:
  - resume position
  - resume state is flushed when Valen quits
  - selected audio track
  - selected subtitle track
  - subtitles off/on state
  - volume
- MCP server (stdio + Unix socket) for AI agent control — ships inside the app bundle

## Single player behavior

Valen is intentionally **not** a multi-window or multi-instance player.

| Action | Result |
| --- | --- |
| Open / drop a new media file | Replaces the current file in the same window |
| Open while Valen is already running | Activates the existing instance and loads there |
| Open several files at once | Plays the first supported media file |
| Drop a subtitle while a video is open | Loads that subtitle on the current file |
| Dock click with no visible window | Brings the existing player window forward |
| MCP `open_file` | Loads into the same single player and focuses its window |

There is no “open in new window” path. Settings is the only extra app window, and it does not create a second player.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Command-O` | Open file |
| `Space` | Play / pause |
| `Left Arrow` | Seek backward |
| `Right Arrow` | Seek forward |
| `Control-Command-F` | Enter / exit fullscreen |
| `Escape` | Exit fullscreen |
| Double-click video | Enter / exit fullscreen |

The seek distance is configurable in `Valen > Settings`.

## Requirements

Install mpv through Homebrew:

```bash
brew install mpv
```

You also need Xcode or Xcode Command Line Tools with Swift 6.

## Run With Swift Package

```bash
swift run valen
```

This is the fastest development path.

## Run With Xcode

Open the native app target:

```bash
open Valen.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project Valen.xcodeproj -scheme Valen -configuration Debug build
```

The Xcode target uses the same Swift source files as the Swift Package target. It links against Homebrew `libmpv`.

## Test

Run the unit and layout-contract tests:

```bash
swift test
```

The tests cover time formatting, media track labels, supported media extensions, saved playback state, preference defaults, overlay behavior policy, single-player open intent, MCP protocol encoding, release metadata, app bundle metadata (including single-instance), and stable UI copy/icons/metrics for the empty state and playback overlay.

See [Docs/Testing.md](Docs/Testing.md) for the test map and guidance on when to add more tests.

## Build Distributable App

```bash
Scripts/build-app.sh
```

This creates:

- `dist/Valen.app`
- `dist/Valen-0.2.1-macos-arm64.zip`

The generated app bundle includes `libmpv` and Homebrew runtime dylib dependencies under `Contents/Frameworks`.

By default, the bundle is ad-hoc signed for local use.


## Sparkle Updates

Sparkle update scaffolding is included, but Sparkle is not fully embedded yet.

Current files:

- `Packaging/Sources/mpvdesk/SparkleUpdater.swift`
- `Packaging/appcast.example.xml`

To include a Sparkle feed URL in the generated bundle:

```bash
SPARKLE_FEED_URL="https://your-domain.com/valen/appcast.xml" Scripts/build-app.sh
```

Before shipping auto-updates:

- embed Sparkle in the Xcode app target
- host a real `appcast.xml`
- replace the example feed URL
- sign release zips with Sparkle's EdDSA signing tool

## Rendering

Valen currently uses `NSOpenGLView` because mpv exposes a stable OpenGL render API. Apple deprecated OpenGL, so the long-term plan is to investigate a Metal-backed rendering surface.

See [Docs/Rendering.md](Docs/Rendering.md) for the rendering roadmap and Metal investigation checklist.

## Roadmap

See [Docs/Roadmap.md](Docs/Roadmap.md) for the subtitle-focused and AI-assisted playback TODO list.

## MCP Server

Valen ships with an embedded [Model Context Protocol](https://modelcontextprotocol.io) server so AI agents (Claude Code, Claude Desktop, etc.) can drive the player.

The `valen-mcp` executable reads JSON-RPC over stdio and forwards calls to the running GUI through a Unix domain socket. The GUI listens on `$TMPDIR/valen-control.sock` whenever the app is running.

### Tools

| Tool | Args | Description |
| --- | --- | --- |
| `play` | - | Resume playback |
| `pause` | - | Pause playback |
| `toggle_play_pause` | - | Toggle play/pause |
| `open_file` | `path` (string, absolute) | Open a local file in the single player (replaces current media); path must start with `/` |
| `seek` | `seconds` (number), `relative` (boolean, optional) | Seek to an absolute time, or by a signed offset when `relative` is true |
| `set_volume` | `value` (0–150) | Set volume; 100 is unity gain |
| `set_speed` | `speed` (0.25–4.0) | Set playback speed multiplier |
| `get_state` | - | Read full player state (see below) |
| `list_audio_tracks` | - | List audio tracks for the current file |
| `list_subtitle_tracks` | - | List subtitle tracks for the current file |
| `select_audio_track` | `id` (integer) | Select an audio track by mpv track id |
| `select_subtitle_track` | `id` (integer) | Select a subtitle track by mpv track id |
| `subtitles_off` | - | Turn subtitles off |

`list_audio_tracks` and `list_subtitle_tracks` return `{ "tracks": [...] }`. Each track includes `id`, `kind`, `title`, `language`, `codec`, `isDefault`, `isForced`, `isSelected`, and `displayName`.

`get_state` returns control protocol version 2 fields:

- `protocolVersion`, `currentFile`, `isPaused`, `position`, `duration`, `volume`, `speed`
- `selectedAudioID`, `selectedSubtitleID`, `subtitlesVisible`, `activeSubtitleText`
- `audioTracks`, `subtitleTracks` (same shape as the list tools)

### Build

```bash
swift build
```

The binaries land in `.build/debug/valen` and `.build/debug/valen-mcp`.

### Smoke test

Start the GUI once so the socket exists, then pipe JSON-RPC through the MCP binary:

```bash
.build/debug/valen &
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0.0.1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_state","arguments":{}}}' \
  | .build/debug/valen-mcp
```

### Claude Desktop

`valen-mcp` ships inside the app bundle at `Valen.app/Contents/MacOS/valen-mcp`. Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "valen": {
      "command": "/Applications/Valen.app/Contents/MacOS/valen-mcp"
    }
  }
}
```

Launch Claude Desktop while the Valen app is running and the thirteen tools appear in the tools menu.


## Current Limitations

- OpenGL rendering works but produces deprecation warnings.
- Sparkle update code is scaffolded, but the framework still needs to be embedded in the Xcode target.
- Multi-window / multi-player is intentionally unsupported; open another file to replace the current one.

## License

Valen source code is licensed under the [MIT License](LICENSE).

Valen depends on `libmpv` and other bundled runtime libraries, which are distributed under their own licenses. Add `THIRD_PARTY_NOTICES.md` before a public binary release.
