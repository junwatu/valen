# Valen Rendering Roadmap

Valen currently renders video through `libmpv`'s OpenGL render API inside an `NSOpenGLView`.

This works today, but it is not the best long-term macOS path because Apple deprecated OpenGL in macOS 10.14. Deprecated does not mean removed, but it means Apple is not improving it and future macOS or hardware changes could make it harder to support.

## Current Path

```text
SwiftUI
  -> VideoSurfaceView
  -> MPVHostView: NSOpenGLView
  -> MPVClient mpv_render_context
  -> mpv OpenGL FBO render
```

Why this path was chosen:

- `libmpv` exposes a stable OpenGL render API.
- It works with embedded SwiftUI/AppKit views.
- It keeps subtitles, video filters, colors, and timing inside mpv.
- It was the fastest reliable way to get MKV playback working.

Current tradeoffs:

- OpenGL warnings during build are expected.
- `NSOpenGLView` is deprecated.
- Future notarized releases may still work, but this is not ideal for a polished macOS player.

## Target Direction

The preferred future path is a Metal-backed view.

```text
SwiftUI
  -> VideoSurfaceView
  -> MetalVideoSurface: MTKView
  -> mpv render bridge or native texture path
  -> Metal drawable
```

The hard part is not creating `MTKView`; it is making mpv render into a Metal-compatible target without losing subtitle rendering, color handling, timing, or hardware decode behavior.

## Investigation Checklist

1. Check the exact `libmpv` version shipped by Homebrew and whether it exposes a Metal render API on macOS.
2. Inspect `mpv/render.h` and `mpv/render_gl.h` for supported API types beyond OpenGL.
3. Test whether mpv can render through `vo=gpu-next` while embedded through `libmpv`.
4. Prototype an `MTKView` surface without changing `PlayerModel` or the controls.
5. Verify:
   - video frames render
   - ASS subtitles render correctly
   - HDR/10-bit content does not look washed out
   - resize/fullscreen does not flicker
   - pause/seek/scrub still redraws correctly
6. Compare CPU/GPU usage against the current OpenGL path.

## Code Boundary

Keep UI code talking to a small render surface abstraction, not directly to a rendering technology.

Current files:

- `Packaging/Sources/mpvdesk/VideoSurfaceView.swift`
- `Packaging/Sources/mpvdesk/MPVClient.swift`

The future replacement should keep this contract:

- SwiftUI owns a video surface view.
- The surface schedules redraws when mpv asks for a new frame.
- `MPVClient` owns mpv playback and render context state.
- Player controls do not know whether the renderer is OpenGL or Metal.

## Practical Recommendation

Keep OpenGL for the first distributable build. Move to Metal after the app target, signing, notarization, and update flow are stable.

Reason: playback correctness matters more than removing warnings. A broken Metal renderer would hurt the core app more than the current OpenGL deprecation warnings.
