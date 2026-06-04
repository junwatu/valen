#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SOCKET="${TMPDIR:-/tmp}/valen-control.sock"

if [[ ! -e "$SOCKET" ]]; then
  echo "Valen control socket not found at:"
  echo "  $SOCKET"
  echo ""
  echo "Launch Valen first, for example:"
  echo "  swift run valen"
  echo "  open dist/Valen.app"
  exit 1
fi

echo "Running live MCP integration tests (socket: $SOCKET)"
swift build --product valen-mcp >/dev/null
swift test --filter 'MCPLive' "$@"