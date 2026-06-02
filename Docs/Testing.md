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
- `LayoutMetricsTests`
  - empty state copy and icon contract
  - overlay opacity, corner radius, and semantic icons
- `ControlProtocolTests`
  - control request/response encoding
  - `AnyCodable` JSON support
  - control method names and state round trips
- `ReleaseMetadataTests`
  - release version alignment across build scripts, Xcode metadata, README, appcast, release notes, and MCP server metadata

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
