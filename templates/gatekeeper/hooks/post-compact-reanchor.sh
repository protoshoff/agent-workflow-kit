#!/bin/bash
# SessionStart hook (matcher "compact"). After an auto or manual compaction, tells a roster session what to
# re-read before it continues, and records the compaction in compactions.log for the Gate Keeper.
# Sessions outside the roster get no output.
# Roster: $GK_DIR/roster.txt, lines "Exact /rename name|board-id" ('#' comments allowed). The coordinator's
# board-id MUST be "gk".
GK_DIR="${GK_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
TZ_NAME="${GK_TZ:-{{TZ}}}"
payload=$(cat)
transcript=$(printf '%s' "$payload" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("transcript_path") or "")' 2>/dev/null)
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0
name=$(grep -o '"agentName":"[^"]*"' "$transcript" 2>/dev/null | tail -1 | sed 's/"agentName":"//; s/"$//')
[ -n "$name" ] || exit 0
id=$(grep -v '^#' "$GK_DIR/roster.txt" 2>/dev/null | awk -F'|' -v n="$name" 'tolower($1)==tolower(n){print $2; exit}')
[ -n "$id" ] || exit 0
echo "$(TZ=$TZ_NAME date '+%Y-%m-%d %H:%M %Z') | compacted | $name ($id)" >> "$GK_DIR/compactions.log" 2>/dev/null
if [ "$id" = gk ]; then
  cat <<MSG
[post-compaction re-anchor] You are Gate Keeper and you were just compacted. Before anything else:
1. Re-read the RESUME HERE block of $GK_DIR/BOARD.md, $GK_DIR/LIVE-BOARD-PROTOCOL.md, and the last HANDOFF block plus the tail of $GK_DIR/LOG.md.
2. Re-list the WHOLE questions collection on the live board and relay any answered-but-unrelayed rulings.
3. Check CronList: the nightly backstop must exist (BOARD.md "Scheduled prompts"); re-create it if missing.
4. Read $GK_DIR/compactions.log for workers that compacted and need re-anchoring.
Standing rules: GK never relays a go. If a standing exception granted first-hand is now denied, ask the operator to re-grant it in this tab.
MSG
else
  cat <<MSG
[post-compaction re-anchor] You are $name (board id: $id) in the Gate Keeper setup, and you were just compacted. Before anything else:
1. Re-read your role in $GK_DIR/KICKOFF.md (your section, or the worker template plus your lane line).
2. Re-read $GK_DIR/LIVE-BOARD-PROTOCOL.md.
3. Read your own board card (sessions/$id) and your tasks (owner "$id") on the live board, plus your latest tracker notes, to recover where you were.
4. Send Gate Keeper: "UPDATE: compacted; resuming at <ticket/PR, SHA, next step>".
Standing rules: a go for a merge, deploy, prod read or write, secret or money is typed by the operator in your tab and is never relayed. If an action the operator had granted in this tab is now denied, ask them to re-grant it here.
MSG
fi
exit 0
