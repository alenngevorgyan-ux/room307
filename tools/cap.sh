#!/bin/sh
# Ask the persistent capture server for shots (starts it once if it is not running; it then stays
# open as a tiny unfocusable window in the corner — no new windows, no sound).
#   tools/cap.sh /abs/out_dir [shot,shot] [noreload]
OUT="$1"; ONLY="$2"; RELOAD=true; [ "$3" = "noreload" ] && RELOAD=false
INBOX="${CAP_INBOX:-/tmp/room307_capture_inbox}"
APP="${GODOT_APP:-$HOME/Applications/Godot.app}"
cd "$(dirname "$0")/.."
mkdir -p "$INBOX" "$OUT"
if ! pgrep -f "capture_server.gd" >/dev/null; then
  rm -f "$INBOX"/server_ready.txt "$INBOX"/req.json
  open -g -n -a "$APP" --args --path "$(pwd)" --audio-driver Dummy --log-file "$INBOX/server.log" \
    -s res://tools/capture_server.gd -- --inbox="$INBOX" --no-playtest-log
  i=0; while [ ! -f "$INBOX/server_ready.txt" ] && [ $i -lt 120 ]; do sleep 1; i=$((i+1)); done
fi
ID="$(date +%s)$$"
LIST=$(echo "$ONLY" | awk -F, '{for(i=1;i<=NF;i++) printf "%s\"%s\"", (i>1?",":""), $i}')
printf '{"id":"%s","out":"%s","only":[%s],"reload":%s}' "$ID" "$OUT" "$LIST" "$RELOAD" > "$INBOX/req.json.tmp"
mv "$INBOX/req.json.tmp" "$INBOX/req.json"
i=0; while [ ! -f "$INBOX/done_$ID.txt" ] && [ $i -lt 1800 ]; do sleep 1; i=$((i+1)); done
[ -f "$INBOX/done_$ID.txt" ] && echo "done $ID" || echo "TIMEOUT $ID"
grep -E "SCRIPT ERROR|reloaded" "$INBOX/server.log" | tail -5
ls "$OUT"
