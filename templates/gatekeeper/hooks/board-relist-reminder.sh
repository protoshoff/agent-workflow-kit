#!/bin/bash
# PostToolUse hook, Gate Keeper session only. Records each re-list of the live-board `questions` collection
# and, on any later tool call, injects a reminder if the last re-list is older than MAX_AGE seconds.
# Prints nothing while the board is fresh; exits silently in every non-GK session.
GK_DIR="${GK_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
STAMP="$GK_DIR/.last-board-relist"
CACHE="$GK_DIR/.sid-cache"
MAX_AGE="${GK_BOARD_MAX_AGE:-600}"
GK_NAME="${GK_SESSION_NAME:-Gate Keeper}"
payload=$(cat)
read -r sid tool coll action transcript < <(printf '%s' "$payload" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("- - - - -"); sys.exit(0)
ti = d.get("tool_input") or {}
print(d.get("session_id") or "-", d.get("tool_name") or "-", ti.get("collection") or "-", ti.get("action") or "-", d.get("transcript_path") or "-")
' 2>/dev/null)
[ "$sid" != "-" ] || exit 0
mkdir -p "$CACHE" 2>/dev/null
if [ -f "$CACHE/$sid" ]; then name=$(cat "$CACHE/$sid")
else
  [ -f "$transcript" ] || exit 0
  name=$(grep -m1 -o '"agentName":"[^"]*"' "$transcript" 2>/dev/null | sed 's/"agentName":"//; s/"$//')
  [ -n "$name" ] && echo "$name" > "$CACHE/$sid"   # unnamed sessions are re-checked next call, so /rename takes effect
fi
[ "$name" = "$GK_NAME" ] || exit 0
now=$(date +%s)
if [ "$tool" = "ArtifactData" ] && [ "$coll" = "questions" ] && { [ "$action" = "query" ] || [ "$action" = "list" ]; }; then
  echo "$now" > "$STAMP"; exit 0
fi
last=$(cat "$STAMP" 2>/dev/null || echo 0)
age=$((now - last))
if [ "$age" -gt "$MAX_AGE" ]; then
  mins=$((age / 60)); [ "$last" -eq 0 ] && mins="unknown"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"GK BOARD CHECK: the live-board questions were last re-listed %s min ago. Before anything else, run ArtifactData query on collection questions with status == answered, and relay and mark every answer."}}\n' "$mins"
fi
exit 0
