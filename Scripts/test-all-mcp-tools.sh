#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MCP="${ROOT}/.build/debug/valen-mcp"
MEDIA="${VALEN_TEST_MEDIA:-$(find "/Users/equan_p/Downloads/Yami Shibai 16" -maxdepth 1 -name '*.mkv' 2>/dev/null | sort | head -1)}"

if [[ ! -x "$MCP" ]]; then
  swift build --product valen-mcp >/dev/null
fi

SOCKET="${TMPDIR:-/tmp}/valen-control.sock"
if ! python3 - "$SOCKET" <<'PY' >/dev/null 2>&1; then
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(2)
s.connect(sys.argv[1])
s.close()
PY
  echo "ERROR: Valen is not running (cannot connect to $SOCKET)"
  echo "Start Valen first: swift run valen"
  exit 1
fi

if [[ -z "${MEDIA:-}" || ! -f "$MEDIA" ]]; then
  echo "ERROR: Set VALEN_TEST_MEDIA to an absolute video path"
  exit 1
fi

call_mcp() {
  local id="$1"
  local tool="$2"
  local args="${3:-{}}"
  printf '%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-all-test","version":"1.0"}}}' \
    '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
    "{\"jsonrpc\":\"2.0\",\"id\":$id,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}"
}

parse_result() {
  python3 - "$1" "$2" <<'PY'
import json, sys
tool, line = sys.argv[1], sys.argv[2]
try:
    obj = json.loads(line)
except json.JSONDecodeError as e:
    print(f"FAIL  {tool}: invalid JSON ({e})")
    sys.exit(0)
if obj.get("error"):
    print(f"FAIL  {tool}: RPC error {obj['error']}")
    sys.exit(0)
result = obj.get("result") or {}
if result.get("isError"):
    text = (result.get("content") or [{}])[0].get("text", "")
    print(f"FAIL  {tool}: {text.strip()[:200]}")
else:
    text = (result.get("content") or [{}])[0].get("text", "{}")
    try:
        payload = json.loads(text) if text.strip().startswith("{") else {"ok": text.strip() or True}
    except json.JSONDecodeError:
        payload = {"raw": text[:120]}
    summary = json.dumps(payload, ensure_ascii=False)[:180]
    print(f"PASS  {tool}: {summary}")
PY
}

echo "Media: $MEDIA"
echo "Socket: $SOCKET"
echo "---"

# tools/list
OUT=$(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-all-test","version":"1.0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":99,"method":"tools/list"}' | "$MCP" 2>/dev/null | tail -1)
python3 - "$OUT" <<'PY'
import json, sys
line = sys.argv[1]
obj = json.loads(line)
tools = obj.get("result", {}).get("tools", [])
names = sorted(t.get("name") for t in tools)
print(f"PASS  tools/list: {len(names)} tools")
for n in names:
    print(f"       - {n}")
PY

run_tool() {
  local id="$1" tool="$2" args="$3"
  local line
  line=$(call_mcp "$id" "$tool" "$args" | "$MCP" 2>/dev/null | tail -1)
  parse_result "$tool" "$line"
}

# Escape path for JSON
MEDIA_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$MEDIA")

run_tool 10 open_file "{\"path\":$MEDIA_JSON}"
sleep 1

run_tool 11 get_state '{}'
run_tool 12 list_audio_tracks '{}'
run_tool 13 list_subtitle_tracks '{}'

# Resolve track ids via control socket (accurate integers)
read -r AUDIO_ID SUB_ID <<<"$(python3 - "$SOCKET" <<'PY'
import json, socket, struct, sys
path = sys.argv[1].encode()
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(path)
def req(mid, method):
    body = json.dumps({"id": mid, "method": method, "params": {}}).encode() + b"\n"
    sock.sendall(body)
    data = b""
    while True:
        chunk = sock.recv(4096)
        if not chunk: break
        data += chunk
        if b"\n" in data: break
    return json.loads(data.decode().strip())
a = req(1, "list_audio_tracks").get("result", {})
s = req(2, "list_subtitle_tracks").get("result", {})
audio = (a.get("tracks") or [{}])[0].get("id", 1)
sub = (s.get("tracks") or [{}])[0].get("id", 1)
print(audio, sub)
PY
)"

run_tool 20 select_audio_track "{\"id\":$AUDIO_ID}"
run_tool 21 select_subtitle_track "{\"id\":$SUB_ID}"
run_tool 22 subtitles_off '{}'
run_tool 23 select_subtitle_track "{\"id\":$SUB_ID}"

run_tool 30 pause '{}'
run_tool 31 play '{}'
run_tool 32 toggle_play_pause '{}'
run_tool 33 toggle_play_pause '{}'

run_tool 40 seek '{"seconds":30,"relative":false}'
run_tool 41 seek '{"seconds":-5,"relative":true}'

run_tool 50 set_volume '{"value":85}'
run_tool 51 set_speed '{"speed":1.25}'

run_tool 60 get_state '{}'

echo "---"
echo "Done."