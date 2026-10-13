# Reliability upgrades

- [x] 1. Subtitle Off takes precedence over a saved external path; explicit track selection clears the external selection.
- [ ] 2. Wait for file-loaded before restoring; isolate optional track errors.
- [ ] 3. Release display protection at EOF and load failure.
- [ ] 4. Bound MCP transport and report command errors.

## Validation

Each completed item is committed separately after the unit suite passes. GUI smoke testing remains separate from unit coverage.
