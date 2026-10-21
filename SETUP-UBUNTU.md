# SETUP-UBUNTU.md - bring the workflow up on a fresh Ubuntu dev server

Assumes Ubuntu 22.04/24.04, a sudo user, and the project checked out (default `$HOME/<project>`). Items marked **VERIFY-ON-BOX** were NOT tested on Linux when this kit was written (it was extracted from macOS + cmux).

## 0. Differences from the macOS original
- The original ran one **cmux** tab per session (cmux is a macOS app). On Ubuntu use **tmux**: one named window per session. `kit/tmux-up.sh` creates them from `.gatekeeper/roster.txt` and starts `claude` in each.
- Times in LOG/board use the operator's IANA zone (`TZ` in `project.env`), not a hard-coded one.
- The original context meters came from a status-line script's bridge files (`$TMPDIR/claude-ctx-<session>.json`) that is NOT part of this kit; see section 10.

## 1. Edit `project.env`
`cp project.env.example project.env`, fill in names, tracker, branches, paths. No secrets. Unfilled keys stay as `{{PLACEHOLDERS}}` for GK to settle (`PORTING-CHECKLIST.md`).

## 2. Run the bootstrap (non-interactive parts)
`./bootstrap-ubuntu.sh project.env`. It installs: git, gh, jq, tmux, python3, Node LTS (NodeSource), `@anthropic-ai/claude-code`; copies `claude-home/agents/*`, `hooks/*` into `~/.claude`; merges `settings.fragment.json` into `~/.claude/settings.json` without overwriting existing keys (backup `settings.json.bak-kit-*`); appends the generic rules to `~/.claude/CLAUDE.md`; builds `<project>/.gatekeeper/` from the templates and renders placeholders; merges the GK hooks and `CLAUDE_CODE_AUTO_COMPACT_WINDOW` into `<project>/.claude/settings.local.json`. Safe to re-run.

Env flags set in `~/.claude/settings.json` `env`: `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` (the todo tools are hidden without it; the global rules require them) and `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=8` (per session; set to roughly CPU count, N sessions x cap is the real ceiling). Project-scope: `CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000` (about 50% of a 1M window; use ~50% of YOUR model's window). Do not pin `effortLevel`/`ultracode` globally: pick effort per thread in the model picker.

## 3. Interactive logins (the operator does these personally)
1. `claude` -> log in with the **same claude.ai account** as the original setup. The `Artifact`/`ArtifactData`/`ArtifactComments` tools, cross-session tools and the `db` capability come from the account, so a different account may lack them. On a headless box use the printed URL/code flow from another machine's browser. **VERIFY-ON-BOX** (headless login).
2. `gh auth login` (org access for the repos). Optionally `gh auth setup-git`.
3. Cloud CLI used for deploy verification (e.g. `aws configure sso`, read-only role). Never paste keys into a chat.
4. Tracker and memory-service credentials go into a chmod-600 file or secret store you own, never the repo (section 6).

## 4. Checkout layout
Project at `$PROJECT_DIR`. Each worker uses its own git worktree off `origin/<main>` outside any scratchpad: `git worktree add ../worktrees/<id> -b feat/<x> origin/<main>`. `kit/tmux-up.sh` starts a window in `../worktrees/<id>` if it exists. Review uses a separate scratch clone.

## 5. Start the sessions
`cd <project> && kit/tmux-up.sh`. Windows: Gate Keeper, Deploys, Review, Backend, ... In EACH window type `/rename <Exact Name>` FIRST (names must match `roster.txt`; GK must be exactly `Gate Keeper`), then paste that role's prompt from `.gatekeeper/KICKOFF.md` / `.gatekeeper/workers/*`. tmux basics: `Ctrl-b w` list, `Ctrl-b n/p` next/prev, `Ctrl-b d` detach, `tmux attach -t agents`. Run Deploys (anything that can touch prod) in a normal permission mode, never bypass-permissions.

## 6. MCP servers (names, transport, env var NAMES only)
Original wiring (values NOT recorded here):
| Name | Scope | Transport | Env var names it reads |
|---|---|---|---|
| `garbago-memory` (agentdesk memory service client) | project `.mcp.json` | stdio, `node <client>/index.js` | `MEMORY_SERVICE_URL`, `MEMORY_PROJECT_ID`, `MEMORY_AGENT_ID`, `MEMORY_API_TOKEN` |
| `mantis-mcp` (issue tracker) | user `~/.claude.json` | stdio, `node -r dotenv/config <repo>/src/index.js` | `DOTENV_CONFIG_PATH` (the .env file it points to holds the tracker URL + API token) |
| `figma` | user | http | none (OAuth in-app); not needed for this workflow |
Memory service (AWS-hosted Node service, DynamoDB table; its own env: `PORT`, `AWS_REGION`, `DYNAMODB_TABLE`, `MEMORY_API_TOKEN`). Two options for the new project: **(a) reuse the existing service with a new namespace**: same URL/token, `MEMORY_PROJECT_ID={{MEMORY_PROJECT_ID}}`, agentIds `<operator>-<role>`; get the shared token from its owner out-of-band; **(b) self-host** from the service repo (needs DynamoDB or local endpoint via `AWS_ENDPOINT_URL`), then generate a new token. The memory service also provides the deploy-window lease tools (`deploy_window_claim/status/renew/release`); the memory MCP is OPTIONAL for the board itself, but kickoff prompts mention `memory_write`; delete those lines if you skip it. **Tracker MCP:** use whatever the project uses; edit `{{TRACKER}}`, `{{TRACKER_CLAIM_CALL}}`, `{{DONE_STATUS}}` and the tool-name pattern in `apply-gk-hooks.sh`. Shape file: `claude-home/mcp.example.json`. Use `claude mcp add` or merge the file, then approve project servers once in `claude`. Env values come from your shell profile (chmod 600) or secret manager, never git.

## 7. Publish a NEW live board (fresh db, never the original's)
In the GK tab: "Publish `.gatekeeper/live-board.html` as an artifact (private). Declare the `db` capability" (load the `artifact-capabilities` and `artifact-design` skills first, as the Artifact tool requires; collections `sessions`, `tasks`, `questions`, docs `board/ctx|release|log`). Put the returned URL in `BOARD.md` ("Live board") and `LIVE-BOARD-PROTOCOL.md` (`Board:` line). Seed it: one `sessions/<id>` card per roster entry (`name, role, order, state:"idle", now, updated`), `board/log` `{entries:[]}`. Every write to an existing doc needs `if_version`. Do not publish unless the operator says so; the page is private by default.

## 8. Nightly backstop
In the GK tab ask for a CronCreate (e.g. `3 23 * * *` local) with a prompt like: "Read the Deploys nightly report from LOG.md/inbox; log a clean night, flag the operator on any hit, ping Deploys (or tell the operator the check stopped) if no report arrived." Have Deploys create its own check cron ~15 minutes earlier. In-session crons expire after 7 days and die with the session: record id + expiry in `BOARD.md` "Scheduled prompts" and re-create them. For a truly unattended box, use system cron + `claude -p` instead (**VERIFY-ON-BOX**).

## 9. Verify it works (checklist)
- [ ] `claude --version`; `echo $CLAUDE_CODE_ENABLE_TODO_TOOLS` is 1 inside a session (ask: "do you have TodoWrite/TaskCreate?").
- [ ] In GK: `ToolSearch select:ListAgents,SendMessage,ArtifactData` loads them; `ListAgents` shows every other named window. **VERIFY-ON-BOX**: peer discovery/messaging was only used under cmux on macOS; if `ListAgents` is empty in tmux, check that all sessions run as the same OS user and the same claude account, then restart them.
- [ ] Round-trip: GK `SendMessage {to:"Review", message:"ping from GK"}`; Review (at its next tool call) replies `SendMessage {to:"Gate Keeper", message:"pong"}`. **VERIFY-ON-BOX** (delivery latency; a permission prompt may hold an incoming message until approved).
- [ ] `ArtifactData` `list` on `sessions` of the NEW board returns your seeded cards, and `set` + `get` of a test question round-trips with `if_version`.
- [ ] Open the board in a browser: a test task whose first open step is `gate:"<operator handle>"` with a `go` field shows in "Needs you"; ticking it makes it vanish.
- [ ] A test task whose first open step is `gate:"relay"` shows as "Pass along"; "I sent it" ticks that step (proof "Marked sent HH:MM") and the card drops off.
- [ ] Compact hook: in a worker, `/compact`; the next turn must show the "[post-compaction re-anchor]" text and `.gatekeeper/compactions.log` gains a line. **VERIFY-ON-BOX** (hook JSON `transcript_path` and `agentName` in the transcript were observed on macOS with Claude Code 2.1.29x).
- [ ] Board reminder: in GK run a few `Bash` calls without listing `questions` for 10+ minutes; expect a "GK BOARD CHECK" context line. Quick offline test is in `MANIFEST.md`.
- [ ] `session-reaper.py` does not kill anything unrelated: it targets `/tmp/claude-<uid>/<project>/<session>/` scratchpads; on Linux confirm that path layout (`ls /tmp/claude-$(id -u)`). **VERIFY-ON-BOX**.
- [ ] `jq . ~/.claude/settings.json` is valid and still has your pre-existing keys.

## 10. Optional: context meters on the board
`.gatekeeper/hooks/ctx-sync.sh <out.json>` expects per-session bridge files `$TMPDIR/claude-ctx-<session_id>.json` containing `{session_id, remaining_percentage, timestamp}` written by a status-line script, and optionally `claude-usage.json` with rate limits. The original status-line script is project tooling and is NOT in the kit. Without it, board meters stay blank and everything else works. If you write a status-line script, have it emit those two files and add `env -u NODE_OPTIONS` before node if a launcher injects stale `NODE_OPTIONS`.

## 11. Security notes
No secret is in this kit. Never `printenv`/`env` in a session; name variables instead. Keep `project.env` secret-free. Standing exceptions (read-only log/metadata) are granted by the operator first-hand in each doer's tab; after a compaction they may need re-granting.
