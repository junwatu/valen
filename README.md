# Valen

Valen is a native macOS media player built with SwiftUI and powered by `libmpv`.

It is designed as a clean, keyboard-friendly desktop player with a compact QuickTime-style overlay, direct mpv playback, audio/subtitle selection, and per-file resume state.

## Features

- Native SwiftUI macOS interface
- mpv-backed playback through `libmpv`
- Embedded video rendering through `mpv_render_context`
- Open files with `Command-O`
- Drag and drop media files
- MKV, WebM, MP4, MOV, AVI, FLAC, OGG, WAV, and common media extension support
- Compact translucent playback overlay
- Auto-hide controls during playback when the pointer is idle
- Keyboard shortcuts:
  - `Space`: play / pause
  - `Left Arrow`: seek back 10 seconds
  - `Right Arrow`: seek forward 10 seconds
- Audio track selector
- Subtitle track selector
- Per-video saved state:
  - resume position
  - selected audio track
  - selected subtitle track
  - subtitles off/on state
  - volume
- Debug log panel for mpv diagnostics
- App bundle generation with bundled Homebrew `libmpv` dylib dependencies

## Screenshots

Screenshots are not committed yet. The app currently uses a dark video-first layout with a compact floating control overlay.

## Requirements

```bash
brew install mpv
```

You also need Xcode or the Xcode Command Line Tools with Swift 6 available.

## Run

```bash
swift run valen
```

## Build App Bundle

```bash
Scripts/build-app.sh
```

This creates:

- `dist/Valen.app`
- `dist/Valen-0.1.0-macos-arm64.zip`

The app bundle includes `libmpv` and its Homebrew runtime dylib dependencies under `Contents/Frameworks`.

The bundle is ad-hoc signed for local use. For public distribution outside your machine, sign with an Apple Developer ID certificate and notarize it so Gatekeeper accepts it without warnings.

## Project Layout

```text
Package.swift
Sources/
  CMpv/
    module.modulemap
  mpvdesk/
    ContentView.swift
    MPVClient.swift
    MpvdeskApp.swift
    PlayerModel.swift
    VideoSurfaceView.swift
Icons/
Scripts/
  build-app.sh
```

## Notes

Valen currently uses `NSOpenGLView` because mpv exposes a stable OpenGL render API. Apple deprecates OpenGL, so a future production version should move the rendering surface to Metal once the mpv build and render API path support it cleanly.

The generated app bundle is intentionally ignored by git. Build artifacts live in `dist/` and can be recreated with `Scripts/build-app.sh`.

## License

No license has been selected yet.
