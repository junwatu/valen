# Valen Testing Guide

Valen uses XCTest through Swift Package Manager.

Run the full test suite from the repository root:

```bash
swift test
```

## Test Groups

- `PlayerModelTests`
  - time formatting
  - media track display labels
  - saved playback state behavior
- `AppPreferencesTests`
  - registered defaults
  - explicit user preference overrides
  - settings option bounds and stable preference keys
- `LayoutMetricsTests`
  - empty state copy and icon contract
  - overlay opacity, corner radius, and semantic icons
- `OverlayVisibilityPolicyTests`
  - overlay visibility rules for paused, idle, debug, and popover states
  - cursor-hide rules while video is playing
- `SupportedMediaTypesTests`
  - media extensions accepted by open panel policy
  - custom containers such as MKV, WebM, and FLAC
- `PlaybackStatePolicyTests`
  - resume-state save guards
  - restore-position edge cases near the start and end of a video
- `SubtitleSelectionPolicyTests`
  - subtitle UI selection follows mpv `sid` when track `selected` flags drop (e.g. after pause)
- `SinglePlayerPolicyTests`
  - single-window identity and title contract
  - open intent prefers one media file (replace, never multi-player)
  - subtitle open only when media is already loaded
  - extra player-window close policy
- `ControlProtocolTests`
  - control request/response encoding
  - `AnyCodable` JSON support
- `ControlSocketPeerPolicyTests`
  - Unix socket peer credential check accepts same-user connections
  - control method names and state round trips
  - control input validation and volume/speed clamping
- `MCPLiveControlTests` / `MCPLiveProcessTests` (optional, requires running Valen)
  - live control socket and `valen-mcp` stdio integration
  - skipped automatically in CI when the GUI is not running
- `ReleaseMetadataTests`
  - release version alignment across build scripts, Xcode metadata, README, appcast, release notes, and MCP server metadata
  - generated app bundle metadata contract for document types and media associations

## What These Tests Protect

The tests focus on stable behavior and release contracts that are easy to break while polishing the app:

- UI copy that users see on the empty player screen.
- Overlay styling constants that keep the controls compact and QuickTime-like.
- Saved resume state and track-selection metadata.
- MCP protocol JSON shapes used by external agent clients.
- Version strings used by packaging and release files.

## When To Add More Tests

Add a test when a change affects:

- file opening or supported media extensions
- keyboard shortcuts
- audio/subtitle track labels or selection
- resume playback behavior
- MCP tool names or argument shapes
- release version, appcast, packaging, or notarization metadata

For UI behavior that XCTest cannot inspect directly, prefer small stable constants or parser-friendly state that can be tested without launching the full app.

## Live MCP Tests (Running Valen)

These tests talk to a real Valen GUI through `$TMPDIR/valen-control.sock` and optionally spawn `valen-mcp`.

1. Launch Valen:

```bash
swift run valen
```

2. Run only the live MCP tests:

```bash
Scripts/test-mcp-live.sh
```

Or:

```bash
swift test --filter MCPLive
```

When Valen is not running, `MCPLiveControlTests` skip. `MCPLiveProcessTests.testMCPToolsListExposesThirteenTools` still runs without the GUI.

Optional environment variables:

- `VALEN_LIVE_PLAYBACK=1` — also run play/pause/toggle checks
- `VALEN_TEST_MEDIA=/absolute/path/to/file.mkv` — run `open_file` against real media
