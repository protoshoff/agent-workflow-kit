# MANIFEST

Source roots: GK = `garbago_platform/.gatekeeper/`, SETUP = `garbago-knowledge/.planning/2026-10-14-MULTI-SESSION-SETUP-FOR-MIKE.md`, SPINE = `garbago-knowledge/CLAUDE.md`, HOME = `~/.claude`, PROJ = `garbago_platform/CLAUDE.md`.
Status: **generic** = copied unchanged (or comment-only edits); **adapted** = logic kept, project names/paths/people replaced by placeholders or env; **new** = written for this kit.

| Kit file | Source | Status |
|---|---|---|
| README.md, SETUP-UBUNTU.md, PORTING-CHECKLIST.md, MANIFEST.md, project.env.example | - (SETUP-UBUNTU draws on SETUP 1-9, settings/MCP config key names) | new |
| bootstrap-ubuntu.sh | replaces GK `apply-autocompact.sh` + `apply-board-reminder.sh` flow | new |
| kit/tmux-up.sh | replaces cmux tab-per-session practice (KICKOFF.md intro) | new |
| templates/gatekeeper/KICKOFF.md | GK/KICKOFF.md + SETUP "Gate Keeper's routine" | adapted |
| templates/gatekeeper/BOARD.md | GK/BOARD.md RESUME block (rules 1-5, 4a-4c and 4b-2, standing exception, compaction) | adapted (state tables emptied) |
| templates/gatekeeper/LIVE-BOARD-PROTOCOL.md | GK/LIVE-BOARD-PROTOCOL.md + SETUP step 7 data shapes | adapted |
| templates/gatekeeper/live-board.html | GK/live-board.html | adapted (title/data/names stripped; `OP`, `TZ`, `PEER_TEAM` placeholders; logic unchanged) |
| templates/gatekeeper/LOG.md | GK/LOG.md header + entry format only | adapted (no log content) |
| templates/gatekeeper/compactions.log | GK/compactions.log | empty file |
| templates/gatekeeper/roster.txt | role table in GK/KICKOFF.md + the case table in post-compact-reanchor.sh | adapted |
| templates/gatekeeper/hooks/post-compact-reanchor.sh | GK/post-compact-reanchor.sh | adapted (roster-driven, no hard-coded path/names/TZ) |
| templates/gatekeeper/hooks/board-relist-reminder.sh | GK/board-relist-reminder.sh | adapted (GK detected by agentName + cache instead of a hard-coded session id) |
| templates/gatekeeper/hooks/ctx-sync.sh | GK/ctx-sync.sh | generic (comments only) |
| templates/gatekeeper/hooks/apply-gk-hooks.sh | GK/apply-autocompact.sh + apply-board-reminder.sh | adapted (merged into one, project-dir argument) |
| templates/workers/backend-KICKOFF.md | GK/KICKOFF.md "Backend" | adapted |
| templates/workers/review-KICKOFF.md | KICKOFF.md "Review" + SETUP "Randy's review method" | adapted |
| templates/workers/deploys-KICKOFF.md | KICKOFF.md "Deploys" + SETUP gate 4 + deploy rules | adapted |
| templates/workers/worker-template-KICKOFF.md | KICKOFF.md worker template + lane lines (Mobile, Bug-Class, Hotfix) + SETUP "Rick" planner | adapted |
| claude-home/agents/{refuter,retriever,digester,oracle-scout,citation-auditor}.md | HOME/agents/ | generic (no project references found; unchanged) |
| claude-home/hooks/session-reaper.py | HOME/hooks/session-reaper.py | generic |
| claude-home/settings.fragment.json | HOME/settings.json keys `env`, SessionStart/SessionEnd reaper wiring | adapted ($HOME paths, only generic hooks) |
| claude-home/CLAUDE.global.md | HOME/CLAUDE.md + PROJ "Working Mode" + "Any workflow you author" | adapted |
| claude-home/mcp.example.json | project `.mcp.json` + user `~/.claude.json` server shapes | new (names/env var NAMES only) |

Not carried over: DEPLOYS-HANDOFF.md (project state; example only), strategy-2026-10-15.json, LOG.md body, `garbago-knowledge/memory/*`, all values from settings/MCP files.

## Offline smoke tests (what was run when building the kit)
- `bash -n` on every `.sh`; settings merge run twice on a sandbox `settings.json` (existing env/hooks/permissions preserved, kit hooks added once).
- `apply-gk-hooks.sh` run twice on a sandbox project (idempotent). `post-compact-reanchor.sh` fed a fake payload + transcript containing `"agentName":"Backend"` -> prints re-anchor text and logs a line. `board-relist-reminder.sh` fed a GK payload -> reminder when stale, silent after a `questions` list.
