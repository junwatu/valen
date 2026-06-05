#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MEDIA="${VALEN_TEST_MEDIA:-$(find "/Users/equan_p/Downloads/Yami Shibai 16" -maxdepth 1 -name '*.mkv' 2>/dev/null | sort | head -1)}"
SOCKET="${TMPDIR:-/tmp}/valen-control.sock"
VALEN="${ROOT}/.build/debug/valen"
LOG="${TMPDIR:-/tmp}/valen-external-subtitle-test.log"

if [[ -z "${MEDIA:-}" || ! -f "$MEDIA" ]]; then
  echo "ERROR: video file not found"
  exit 1
fi

DIR=$(dirname "$MEDIA")
BASE=$(basename "$MEDIA" .mkv)
SRT="$DIR/${BASE}.srt"

swift build --product valen >/dev/null

pkill -f "\.build/debug/valen" 2>/dev/null || true
rm -f "$SOCKET"
sleep 0.5

"$VALEN" >"$LOG" 2>&1 &
VALEN_PID=$!

for _ in $(seq 1 30); do
  if python3 - "$SOCKET" <<'PY' >/dev/null 2>&1; then
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(1)
s.connect(sys.argv[1])
s.close()
PY
    break
  fi
  sleep 0.5
done

MEDIA_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$MEDIA")
python3 - "$SOCKET" "$MEDIA_JSON" <<'PY'
import json, socket, sys, time
path, media_json = sys.argv[1], sys.argv[2]
media = json.loads(media_json)
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(path)
def call(mid, method, params=None):
    body = json.dumps({"id": mid, "method": method, "params": params or {}}).encode() + b"\n"
    s.sendall(body)
    data = b""
    while True:
        chunk = s.recv(8192)
        if not chunk:
            break
        data += chunk
        if b"\n" in data:
            break
    return json.loads(data.decode().strip())
resp = call(1, "open_file", {"path": media})
if resp.get("error"):
    print(f"FAIL  open_file: {resp['error']}")
    raise SystemExit(1)
print("PASS  open_file")
time.sleep(4)
state = call(2, "get_state").get("result", {})
print(f"INFO  file={state.get('currentFile','')[-50:]}")
print(f"INFO  duration={state.get('duration')} paused={state.get('isPaused')}")
s.close()
PY

if [[ -f "$SRT" ]]; then
  if grep -q "Auto-loaded matching subtitle" "$LOG" || grep -q "Loaded external subtitle" "$LOG"; then
    echo "PASS  auto_load_sibling: found log entry ($(basename "$SRT"))"
  else
    echo "FAIL  auto_load_sibling: expected auto-load log (srt exists: $(basename "$SRT"))"
    echo "       tail log:"
    tail -8 "$LOG" | sed 's/^/       /'
  fi
else
  echo "SKIP  auto_load_sibling: no sibling srt at $SRT"
fi

# Unit tests on this branch
echo "---"
echo "Unit tests (feature/external-subtitle-load):"
swift test 2>&1 | grep -E 'Executed|failed|passed'

kill "$VALEN_PID" 2>/dev/null || true
wait "$VALEN_PID" 2>/dev/null || true

echo "---"
echo "Done. Full Valen log: $LOG"