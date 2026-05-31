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
- Native Settings window for playback defaults, seek distance, resume behavior, and overlay auto-hide timing
- Keyboard shortcuts:
  - `Space`: play / pause
  - `Left Arrow`: seek back 10 seconds
  - `Right Arrow`: seek forward 10 seconds
  - `Control-Command-F`: enter / exit full screen
  - `Escape`: exit full screen
- Double-click video to enter / exit full screen
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

The keyboard seek distance can be changed in `Valen > Settings`.

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

## Xcode App Target

Valen also includes a native Xcode app target:

```bash
open Valen.xcodeproj
```

Or build it from the command line:

```bash
xcodebuild -project Valen.xcodeproj -scheme Valen -configuration Debug build
```

The Xcode target uses the same Swift source files as the Swift Package target. It links against Homebrew `libmpv`, so install mpv first with `brew install mpv`.

## Build App Bundle

```bash
Scripts/build-app.sh
```

This creates:

- `dist/Valen.app`
- `dist/Valen-0.1.0-macos-arm64.zip`

The app bundle includes `libmpv` and its Homebrew runtime dylib dependencies under `Contents/Frameworks`.

By default, the bundle is ad-hoc signed for local use.

For Developer ID signing:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Scripts/build-app.sh
```

To include a Sparkle feed URL in the app bundle:

```bash
SPARKLE_FEED_URL="https://your-domain.com/valen/appcast.xml" Scripts/build-app.sh
```

For notarization:

```bash
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
Scripts/notarize-app.sh
```

Notarization requires an Apple Developer Program account, a Developer ID Application certificate in Keychain, and an app-specific Apple ID password.

## Sparkle Updates

Sparkle update scaffolding is included:

- `Sources/mpvdesk/SparkleUpdater.swift`
- `Packaging/appcast.example.xml`
- optional `SUFeedURL` in the generated `Info.plist`

The update menu is enabled automatically when the app target links Sparkle. The current Swift Package build keeps Sparkle optional so local builds do not fail without the framework.

Before shipping auto-updates, replace the example feed URL with your real hosted `appcast.xml`, sign releases with Sparkle's EdDSA signing tool, and embed Sparkle in a real Xcode app target.

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

## Notes

Valen currently uses `NSOpenGLView` because mpv exposes a stable OpenGL render API. Apple deprecates OpenGL, so a future production version should move the rendering surface to Metal once the mpv build and render API path support it cleanly.

See [Docs/Rendering.md](Docs/Rendering.md) for the rendering roadmap and Metal investigation checklist.

The generated app bundle is intentionally ignored by git. Build artifacts live in `dist/` and can be recreated with `Scripts/build-app.sh`.

## License

No license has been selected yet.
