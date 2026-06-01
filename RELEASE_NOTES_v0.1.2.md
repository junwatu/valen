# Valen v0.1.2 Public Preview

Valen is a native macOS media player built with SwiftUI and powered by libmpv.

This is an early public preview for feedback and testing.

## Highlights

- Native SwiftUI macOS app shell.
- mpv playback with bundled runtime libraries.
- MKV and common media file support.
- Audio and subtitle track selectors.
- Track selectors now use popovers so the overlay stays visible while choosing audio or subtitles.
- Native `Valen > About Valen` panel.
- Per-video resume state for position, volume, audio, and subtitle choices.
- QuickTime-style translucent playback controls.
- Unit and layout-contract tests.

## Known Limitations

- This build is ad-hoc signed for local use, not Developer ID signed or notarized.
- macOS Gatekeeper may warn when opening the app.
- Rendering currently uses OpenGL through mpv; Apple has deprecated OpenGL.
- Sparkle auto-update support is scaffolded but not enabled for production updates.
- Third-party notices still need to be completed before a wider public release.

## Download

Use `Valen-0.1.2-macos-arm64.zip` from the release assets.

SHA-256:

```text
76c87fdc4e3efacf861c836f6f1a46da506d114896b42334c104473fb630c60a
```
