#!/bin/bash
# Creates one tmux window per roster session and starts `claude` in each in the right directory.
# Usage: kit/tmux-up.sh [project_dir]     (default: PROJECT_DIR from ~/.agent-kit/project.env, else $PWD)
# Re-running attaches to the existing tmux session; it never starts a duplicate window.
# After it starts: in EACH window type  /rename <Exact Name>  FIRST, then paste that role's kickoff prompt.
# (Claude Code cannot be told its /rename name from the shell, so this stays a manual step.)
set -euo pipefail
[ -f "$HOME/.agent-kit/project.env" ] && set -a && . "$HOME/.agent-kit/project.env" && set +a
PROJ="${1:-${PROJECT_DIR:-$PWD}}"
SESSION="${TMUX_SESSION:-agents}"
ROSTER="$PROJ/.gatekeeper/roster.txt"
command -v tmux >/dev/null || { echo "tmux not installed"; exit 1; }
command -v claude >/dev/null || { echo "claude not on PATH"; exit 1; }
[ -f "$ROSTER" ] || { echo "no $ROSTER (run bootstrap-ubuntu.sh first)"; exit 1; }
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  first=1
  while IFS='|' read -r name id; do
    case "$name" in ''|\#*) continue;; esac
    # Workers keep their own git worktree: if $PROJ/../worktrees/<id> exists, start there; else in the project dir.
    dir="$PROJ"; [ -d "$PROJ/../worktrees/$id" ] && dir="$PROJ/../worktrees/$id"
    if [ "$first" = 1 ]; then tmux new-session -d -s "$SESSION" -n "$name" -c "$dir"; first=0
    else tmux new-window -t "$SESSION" -n "$name" -c "$dir"; fi
    tmux send-keys -t "$SESSION:$name" "claude" C-m
  done < "$ROSTER"
  tmux select-window -t "$SESSION:Gate Keeper" 2>/dev/null || true
fi
echo "tmux session '$SESSION' is up. Switch windows: Ctrl-b n/p, Ctrl-b w (list). Detach: Ctrl-b d. Re-attach: tmux attach -t $SESSION"
[ -t 1 ] && exec tmux attach -t "$SESSION" || true
