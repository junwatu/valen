# Reliability upgrades

- [x] 1. Subtitle Off takes precedence over a saved external path; explicit track selection clears the external selection.
- [x] 2. Wait for file-loaded before restoring; isolate optional track errors.
- [x] 3. Release display protection at EOF and load failure.
- [x] 4. Bound MCP transport and report command errors (socket mode 600, same-user peer check, main-thread timeout).
- [x] 5. Resync playback and save state on system/display sleep and wake.
- [x] 6. Keep subtitle UI selection aligned with mpv `sid` after pause (do not rely on transient track `selected` flags).

## Validation

Each completed item is committed separately after the unit suite passes. GUI smoke testing remains separate from unit coverage.
