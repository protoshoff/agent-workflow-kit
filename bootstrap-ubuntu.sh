#!/bin/bash
# bootstrap-ubuntu.sh - idempotent, NON-INTERACTIVE parts of the agent-workflow kit on Ubuntu 22.04/24.04.
# Does: apt packages, Node LTS, @anthropic-ai/claude-code (npm -g), copies agents/hooks into ~/.claude,
#       merges settings.fragment.json into ~/.claude/settings.json WITHOUT clobbering existing keys,
#       installs the .gatekeeper/ templates into the project and renders {{PLACEHOLDERS}} from project.env,
#       wires the GK hooks into <project>/.claude/settings.local.json.
# Never does: logins, tokens, secrets, MCP credentials, publishing the board, creating crons.
# Usage:  ./bootstrap-ubuntu.sh [path/to/project.env]     (default ./project.env, else ./project.env.example)
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVFILE="${1:-$KIT/project.env}"
[ -f "$ENVFILE" ] || { ENVFILE="$KIT/project.env.example"; echo "NOTE: no project.env; using the example values (edit project.env and re-run)."; }
set -a; . "$ENVFILE"; set +a
PROJECT_DIR="${PROJECT_DIR:-$HOME/${PROJECT:-project}}"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "== 1. apt packages"
if command -v apt-get >/dev/null; then
  $SUDO apt-get update -y
  $SUDO apt-get install -y git jq tmux python3 curl ca-certificates gnupg build-essential
  if ! command -v gh >/dev/null; then $SUDO apt-get install -y gh || echo "WARN: gh not in apt on this release; install from https://cli.github.com/ (apt repo)"; fi
else echo "WARN: not an apt system; install git jq tmux python3 gh yourself"; fi

echo "== 2. Node LTS"
need_node=1
if command -v node >/dev/null; then v=$(node -p 'process.versions.node.split(".")[0]'); [ "$v" -ge 20 ] && need_node=0; fi
if [ "$need_node" = 1 ]; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash -
  $SUDO apt-get install -y nodejs
fi
node --version

echo "== 3. Claude Code CLI"
if ! command -v claude >/dev/null; then $SUDO npm install -g @anthropic-ai/claude-code; fi
claude --version || true

echo "== 4. ~/.claude agents, hooks, global rules"
mkdir -p "$HOME/.claude/agents" "$HOME/.claude/hooks"
for f in "$KIT"/claude-home/agents/*.md; do
  d="$HOME/.claude/agents/$(basename "$f")"; [ -e "$d" ] && ! cmp -s "$f" "$d" && cp "$d" "$d.bak-kit" ; cp "$f" "$d"
done
for f in "$KIT"/claude-home/hooks/*; do
  d="$HOME/.claude/hooks/$(basename "$f")"; [ -e "$d" ] && ! cmp -s "$f" "$d" && cp "$d" "$d.bak-kit"; cp "$f" "$d"; chmod +x "$d"
done
if [ ! -f "$HOME/.claude/CLAUDE.md" ]; then cp "$KIT/claude-home/CLAUDE.global.md" "$HOME/.claude/CLAUDE.md"
elif ! grep -q 'Working mode - routed by blast radius' "$HOME/.claude/CLAUDE.md"; then
  printf '\n\n<!-- agent-workflow-kit: generic standing rules -->\n' >> "$HOME/.claude/CLAUDE.md"; cat "$KIT/claude-home/CLAUDE.global.md" >> "$HOME/.claude/CLAUDE.md"
fi

echo "== 5. merge settings fragment into ~/.claude/settings.json (existing keys win; hooks appended once)"
S="$HOME/.claude/settings.json"; [ -f "$S" ] || echo '{}' > "$S"
cp "$S" "$S.bak-kit-$(date +%Y%m%d%H%M%S)"
tmp=$(mktemp)
jq --slurpfile f "$KIT/claude-home/settings.fragment.json" '
  ($f[0]) as $F
  | .env = (($F.env // {}) + (.env // {}))
  | .hooks = (reduce (($F.hooks // {}) | to_entries[]) as $e (.hooks // {};
      .[$e.key] = ((.[$e.key] // []) as $cur
        | $cur + [ $e.value[] | select(. as $n | ($cur | map(tojson) | index($n|tojson)) == null) ])))
' "$S" > "$tmp" && jq -e . "$tmp" >/dev/null && mv "$tmp" "$S"

echo "== 6. project .gatekeeper/ from templates ($PROJECT_DIR)"
GK="$PROJECT_DIR/.gatekeeper"; mkdir -p "$GK/hooks" "$GK/workers"
copy_if_absent() { [ -e "$2" ] && { echo "  keep existing $2"; return; }; cp "$1" "$2"; }
for f in KICKOFF.md BOARD.md LIVE-BOARD-PROTOCOL.md LOG.md live-board.html roster.txt compactions.log; do copy_if_absent "$KIT/templates/gatekeeper/$f" "$GK/$f"; done
for f in "$KIT"/templates/gatekeeper/hooks/*.sh; do cp "$f" "$GK/hooks/"; chmod +x "$GK/hooks/$(basename "$f")"; done
for f in "$KIT"/templates/workers/*.md; do copy_if_absent "$f" "$GK/workers/$(basename "$f")"; done
mkdir -p "$HOME/.agent-kit"; cp "$ENVFILE" "$HOME/.agent-kit/project.env"
mkdir -p "$PROJECT_DIR/kit"; cp "$KIT/kit/tmux-up.sh" "$PROJECT_DIR/kit/"; chmod +x "$PROJECT_DIR/kit/tmux-up.sh"
# Render {{KEY}} placeholders for keys present in the env file only; others are left for the GK to decide.
python3 -I - "$ENVFILE" "$GK" <<'PY'
import os, re, sys
envfile, gk = sys.argv[1:3]
vals = {}
for line in open(envfile):
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line: continue
    k, v = line.split("=", 1)
    vals[k.strip()] = os.path.expandvars(v.strip().strip('"'))
vals["worker_id_1"] = "backend"
for root, _, files in os.walk(gk):
    for fn in files:
        if not fn.endswith((".md", ".html", ".sh", ".txt")): continue
        p = os.path.join(root, fn); s = open(p).read(); o = s
        for k, v in vals.items(): s = s.replace("{{%s}}" % k, v)
        if s != o: open(p, "w").write(s)
left = set()
for root, _, files in os.walk(gk):
    for fn in files:
        if fn.endswith((".md", ".html", ".sh", ".txt")): left |= set(re.findall(r"\{\{[A-Za-z_0-9]+\}\}", open(os.path.join(root, fn)).read()))
print("  placeholders still unresolved (settle in PORTING-CHECKLIST.md):", ", ".join(sorted(left)) or "none")
PY

echo "== 7. GK hooks + auto-compact into $PROJECT_DIR/.claude/settings.local.json"
bash "$GK/hooks/apply-gk-hooks.sh" "$PROJECT_DIR" "${AUTO_COMPACT_WINDOW:-500000}"

cat <<'MSG'

============================ REMAINING MANUAL STEPS ============================
 (the operator does these personally; this script never touches credentials)
 1. `claude` and log in with the SAME claude.ai account as the other machine (the Artifact / ArtifactData tools come from the account).
 2. `gh auth login`; any cloud CLI login (e.g. `aws configure sso`), tracker/memory MCP credentials via your secret store.
 3. Configure MCP servers (see templates in claude-home/mcp.example.json and SETUP-UBUNTU.md section 6).
 4. Publish the NEW live board from .gatekeeper/live-board.html (db capability), record the URL in BOARD.md and LIVE-BOARD-PROTOCOL.md.
 5. Start the sessions:  cd <project> && kit/tmux-up.sh ; in each window: /rename <Exact Name>, then paste its kickoff prompt.
 6. In the Gate Keeper tab: create the nightly backstop cron (CronCreate) and record its id in BOARD.md.
 7. Run the "Verify it works" checklist in SETUP-UBUNTU.md; mark VERIFY-ON-BOX items.
 8. Settle every item in PORTING-CHECKLIST.md before the first worker starts.
================================================================================
MSG
