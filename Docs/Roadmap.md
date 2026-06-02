# Valen Roadmap

Valen's product direction is a native macOS player for MKV, subtitles, and AI-assisted playback.

## Subtitle-Focused TODO

### Track Selection

- [ ] Improve subtitle track labels so title, metadata language, codec, default, and forced flags are easy to scan.
- [ ] Add a clear distinction between metadata language and real subtitle content when the file is mislabeled.
- [ ] Group subtitle tracks by likely purpose:
  - full subtitles
  - signs/songs
  - forced subtitles
  - unknown
- [ ] Remember subtitle visibility state per video.
- [ ] Remember subtitle delay per video.

### Subtitle Navigation

- [ ] Add shortcut to replay the current subtitle line.
- [ ] Add shortcut to jump to previous subtitle line.
- [ ] Add shortcut to jump to next subtitle line.
- [ ] Add optional pause-after-subtitle mode for language learning.
- [ ] Add optional auto-replay current subtitle line.

### Subtitle Timing

- [ ] Add subtitle delay controls.
- [ ] Add audio delay controls.
- [ ] Show current subtitle delay and audio delay in a compact overlay.
- [ ] Save subtitle/audio delay per video.

### Subtitle Display

- [ ] Keep ASS subtitle rendering through mpv as the default path.
- [ ] Verify embedded fonts work across common MKV files.
- [ ] Add support for loading external subtitle files.
- [ ] Add option to choose primary subtitle track quickly from keyboard.
- [ ] Investigate dual subtitles:
  - primary subtitle rendered by mpv
  - secondary subtitle shown as a lightweight overlay, if reliable

### Diagnostics

- [ ] Add a compact subtitle diagnostics view:
  - selected `sid`
  - subtitle visibility
  - ASS enabled
  - embedded fonts enabled
  - active subtitle text
  - track list
- [ ] Add "copy diagnostics" button for debugging user reports.
- [ ] Add a warning when the selected subtitle track has no visible subtitle text for a while.

## AI-Assisted Playback TODO

### MCP Tool Expansion

- [ ] Add MCP tool to list audio tracks.
- [ ] Add MCP tool to list subtitle tracks.
- [ ] Add MCP tool to select audio track by id.
- [ ] Add MCP tool to select subtitle track by id.
- [ ] Add MCP tool to turn subtitles off.
- [ ] Add MCP tool to read active subtitle text.
- [ ] Add MCP tool to read current file metadata.
- [ ] Add MCP tool to read folder playlist state.

### File Automation

- [ ] Add "open next file in folder".
- [ ] Add "open previous file in folder".
- [ ] Add "open latest media file in Downloads".
- [ ] Add watched/unwatched state per file.
- [ ] Add "play next unwatched file".
- [ ] Add basic folder playlist support without cluttering the UI.

### AI-Friendly State

- [ ] Return richer `get_state` output:
  - current file
  - position
  - duration
  - pause state
  - volume
  - speed
  - selected audio track
  - selected subtitle track
  - subtitle visibility
  - active subtitle text
- [ ] Keep MCP responses structured and stable.
- [ ] Add tests for every MCP tool schema and response shape.

### Command Palette

- [ ] Add keyboard-first command palette.
- [ ] Include playback commands:
  - play/pause
  - seek
  - open file
  - open next file
  - select audio
  - select subtitle
  - subtitle delay
  - audio delay
- [ ] Make command palette actions reusable by MCP where possible.

### Safety

- [ ] Keep AI file-opening local-only by default.
- [ ] Require absolute paths for MCP `open_file`.
- [ ] Avoid deleting, moving, or modifying media files through MCP until explicitly designed.
- [ ] Log AI-triggered player actions in the debug panel.

## Priority TODO

- [ ] Add audio/subtitle MCP tools.
- [ ] Add subtitle/audio delay controls and tests.
- [ ] Add next/previous subtitle navigation.
- [ ] Add active subtitle text to player state and MCP state.
- [ ] Add folder next/previous playback.
- [ ] Add watched/unwatched state.
- [ ] Add command palette.
- [ ] Investigate dual subtitles.
