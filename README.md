# Valen

Valen is a native macOS media player built with SwiftUI and powered by `libmpv`.

It focuses on a clean video-first interface, keyboard-friendly playback, MKV support, audio/subtitle selection, and per-video resume state.

## Features

- Native SwiftUI macOS app
- Real Xcode app target: `Valen.xcodeproj`
- Swift Package target for quick local development
- mpv playback through `libmpv`
- Embedded rendering through `mpv_render_context`
- MKV, WebM, MP4, MOV, AVI, FLAC, OGG, WAV, and common media extension support
- macOS file association metadata for Finder and Open With
- Open files with `Command-O`
- Drag and drop media files
- Compact QuickTime-style translucent overlay controls
- Overlay auto-hides during playback when the pointer is idle
- Cursor hides when playback controls hide
- Fullscreen support through shortcut, double-click, or macOS window controls
- Audio track selector
- Subtitle track selector
- Native Settings window
- App info popover with version, build, bundle ID, and runtime details
- Per-video saved state:
  - resume position
  - selected audio track
  - selected subtitle track
  - subtitles off/on state
  - volume
- Debug log panel for mpv diagnostics
- App bundle generation with bundled Homebrew `libmpv` runtime libraries
- Developer ID signing and notarization script scaffolding
- Sparkle auto-update scaffolding

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

## Build Distributable App

```bash
Scripts/build-app.sh
```

This creates:

- `dist/Valen.app`
- `dist/Valen-0.1.0-macos-arm64.zip`

The generated app bundle includes `libmpv` and Homebrew runtime dylib dependencies under `Contents/Frameworks`.

By default, the bundle is ad-hoc signed for local use.

## Developer ID Signing

For public distribution, sign with a Developer ID Application certificate:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Scripts/build-app.sh
```

## Notarization

After building with a Developer ID certificate:

```bash
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
Scripts/notarize-app.sh
```

Notarization requires:

- Apple Developer Program account
- Developer ID Application certificate in Keychain
- app-specific Apple ID password

## Sparkle Updates

Sparkle update scaffolding is included, but Sparkle is not fully embedded yet.

Current files:

- `Sources/mpvdesk/SparkleUpdater.swift`
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

## Project Layout

```text
Valen.xcodeproj/
Package.swift
Sources/
  CMpv/
    module.modulemap
  mpvdesk/
    AppPreferences.swift
    ContentView.swift
    MPVClient.swift
    MpvdeskApp.swift
    PlayerModel.swift
    SettingsView.swift
    SparkleUpdater.swift
    VideoSurfaceView.swift
Docs/
  Rendering.md
Icons/
Xcode/
  Valen-Info.plist
  Resources/
    Valen.icns
Packaging/
  Valen.entitlements
  appcast.example.xml
Scripts/
  build-app.sh
  notarize-app.sh
```

## Current Limitations

- OpenGL rendering works but produces deprecation warnings.
- Public distribution still needs real Developer ID signing and notarization.
- Sparkle update code is scaffolded, but the framework still needs to be embedded in the Xcode target.
- The shell bundle script is still the main distributable build path.

## License

No license has been selected yet.
