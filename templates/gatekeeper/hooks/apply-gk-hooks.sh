#!/bin/bash
# Usage: apply-gk-hooks.sh <project_dir> [auto_compact_window]
# Merges into <project_dir>/.claude/settings.local.json (keeps every existing key; backs up first; idempotent):
#   env.CLAUDE_CODE_AUTO_COMPACT_WINDOW (default 500000 = 50% of a 1M window; set to ~50% of YOUR window)
#   hooks.SessionStart[matcher "compact"] -> .gatekeeper/hooks/post-compact-reanchor.sh
#   hooks.PostToolUse[SendMessage|ArtifactData|Bash|mcp__{{TRACKER_MCP}}__.*] -> .gatekeeper/hooks/board-relist-reminder.sh
# Undo: copy the printed backup over settings.local.json.
set -euo pipefail
P=$(cd "${1:?usage: apply-gk-hooks.sh <project_dir> [window]}" && pwd)
W="${2:-500000}"
F="$P/.claude/settings.local.json"
mkdir -p "$P/.claude"; [ -f "$F" ] || echo '{}' > "$F"
B="$F.bak-gk-$(date +%Y%m%d%H%M%S)"; cp "$F" "$B"
python3 -I - "$F" "$P" "$W" <<'PY'
import json, sys
p, proj, win = sys.argv[1:4]
d = json.load(open(p))
d.setdefault("env", {})["CLAUDE_CODE_AUTO_COMPACT_WINDOW"] = win
h = d.setdefault("hooks", {})
def add(event, entry, needle):
    lst = h.setdefault(event, [])
    if not any(needle in x.get("command", "") for e in lst for x in e.get("hooks", [])):
        lst.append(entry)
c1 = proj + "/.gatekeeper/hooks/post-compact-reanchor.sh"
c2 = proj + "/.gatekeeper/hooks/board-relist-reminder.sh"
add("SessionStart", {"matcher": "compact", "hooks": [{"type": "command", "command": c1, "timeout": 15}]}, "post-compact-reanchor.sh")
add("PostToolUse", {"matcher": "SendMessage|ArtifactData|Bash|mcp__.*", "hooks": [{"type": "command", "command": c2, "timeout": 10}]}, "board-relist-reminder.sh")
json.dump(d, open(p, "w"), indent=2); open(p, "a").write("\n")
PY
echo "OK: GK hooks + auto-compact window $W merged into $F (backup: $B)"
