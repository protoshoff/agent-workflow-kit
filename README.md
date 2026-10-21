# agent-workflow-kit

A portable, project-neutral kit that reproduces a multi-session Claude Code workflow: **one Gate Keeper (GK) session, a claude.ai live-board artifact, and named worker sessions** (Backend, Review, Deploys, Hotfix, Mobile, Bug-Class, Planner). It was extracted from a production setup and stripped of project names, data, hosts and secrets. Project-specific decisions are `{{PLACEHOLDERS}}` listed in `PORTING-CHECKLIST.md`.

## Architecture in 10 lines
1. Each Claude Code session has one job and an exact `/rename` name; the roster is `.gatekeeper/roster.txt`.
2. **GK coordinates.** It relays rulings, verifies claims (SHA, CI, deploy state) itself, keeps `LOG.md` + `BOARD.md`, and moves tickets to the done status. It never writes product code, merges, deploys, or reads the prod DB.
3. **Workers own lanes** (a repo/area each), work in their own git worktree, and own a PR up to the reviewer's CLEARED; they never press merge.
4. **Review** reports FINDINGS or `CLEARED @ <full 40-char SHA>`; **Deploys** presses every merge and runs every deploy, pinned to the full SHA, staging before prod.
5. **Live board** = a claude.ai artifact page with the `db` capability (collections `sessions`, `tasks`, `questions`, docs `board/ctx|release|log`). It shows "Needs you" first, then release, one card per session, then the log. Needs-you and session cards are laid out masonry-style. Go cards carry "I typed it" and Pass along cards "I sent it", so the operator can mark either one without messaging GK.
6. **Gos are typed by the operator first-hand, in the doer's tab, and are never relayed.** A board click is a ruling, never a go (every session writes as the operator, so a click proves nothing). Merge, staging, prod each need their own go.
7. Cross-session messages use Claude Code's built-in `ListAgents` / `SendMessage` (deferred tools: `ToolSearch select:ListAgents,SendMessage`); protocol words are `UPDATE:` and `ASK:`.
8. Hooks keep it alive across compaction: auto-compact at ~50% of the window, a SessionStart `compact` hook re-anchors the session and logs to `compactions.log`, and a PostToolUse hook nags GK when the board's questions have not been re-listed for 10 minutes.
9. A nightly in-session cron (Deploys check + GK backstop) catches silent failures; crons expire in 7 days, so ids are kept in `BOARD.md`.
10. Routing is by **blast radius, not difficulty**: solo when a compiler/test/human catches errors; guarded workflows only where nothing would catch a confident wrong answer.

## Layout
`SETUP-UBUNTU.md` (read first) | `bootstrap-ubuntu.sh` | `project.env.example` | `kit/tmux-up.sh` | `templates/gatekeeper/` (KICKOFF, BOARD, LIVE-BOARD-PROTOCOL, LOG, live-board.html, roster, hooks) | `templates/workers/` | `claude-home/` (agents, hooks, settings fragment, global rules, MCP shape) | `PORTING-CHECKLIST.md` | `MANIFEST.md`.
