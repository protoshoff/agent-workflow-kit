# Gate Keeper BOARD ({{PROJECT}}) - current state only, rewrite in place

## RESUME HERE (read after every compaction)
1. Re-read `{{SETUP_DOC}}` (if you keep one), this RESUME block, and `.gatekeeper/LIVE-BOARD-PROTOCOL.md`.
2. Standing rules (GK rules):
   1. A go for a merge, staging deploy, prod deploy, prod DB read/write, secret or money op is typed by {{OPERATOR}} first-hand in the doer's tab. GK never relays a go; a board answer is never a go.
   2. Every merge: reviewer CLEARED @ the exact full head SHA + green CI on that SHA. Deploys presses merge. A new push needs a new CLEARED.
   3. Staging go and prod go are separate. Prod ships first-parent {{MAIN_BRANCH}} SHAs only, forward-only, full-SHA pinned.
   4. Tracker ({{TRACKER}}): note first, status last, read back. `{{DONE_STATUS}}` only once live in prod. Never close; the operator closes manually.
   - 4a. Board rule: whenever a card's `go` changes or is ticked, delete its `typed` field in the SAME write (`{"__delete__":true}`). A leftover `typed` makes the board say "Waiting for confirmation" for a go nobody typed. A go card stays up only when {{OPERATOR}} can type it now; anything blocked on {{PEER_TEAM}} goes up as a `relay` step (shows as "Pass along").
   - 4b. Re-list the WHOLE `questions` collection at the start of EVERY GK turn, not only after compaction (answered rulings sat unrelayed for 1-1.7 h before this rule).
   - 4b-2. At the start of EVERY GK turn, besides re-listing questions, re-read every task card whose current step is gated `relay` or `{{OPERATOR_HANDLE}}` (Pass along and go cards). The operator marks relays sent with the page's "I sent it" button, so a card can finish with no message to GK (two missed relays before this rule).
   - 4c. Post a go card that names a file hash or SHA only after the doer confirms that file is FROZEN; the card goes stale within minutes if the author applies a NIT afterwards.
   5. Times in LOG are local from `TZ={{TZ}} date`, never guessed. ISO timestamps written to the board come from the clock too.
3. Standing exception (GRANTED by {{OPERATOR}} first-hand in each doer's tab, date: {{GRANT_DATE}}; the auto-mode permission classifier denies these reads until then): {{STANDING_EXCEPTION}}. Never DB reads, writes or secrets. If denied after a compaction, ask the operator to re-grant it in that tab.
4. Kickoff prompts: `.gatekeeper/KICKOFF.md`. Roster: `.gatekeeper/roster.txt`.
5. Compaction policy: auto-compact at ~50% (`CLAUDE_CODE_AUTO_COMPACT_WINDOW`) + SessionStart 'compact' re-anchor hook (`.gatekeeper/hooks/post-compact-reanchor.sh`, logs to `.gatekeeper/compactions.log`). Verify it from transcripts after the first week.

## Sessions
| Name (/rename) | Role | Lane | agentId | State |
|---|---|---|---|---|
| Gate Keeper | coordinator | - | {{OPERATOR_HANDLE}}-gatekeeper | |
| Deploys | merge + deploy | - | {{OPERATOR_HANDLE}}-deploys | |
| Review | reviewer | - | {{OPERATOR_HANDLE}}-review | |
| {{WORKER_NAME_1}} | worker | {{LANE_1}} | {{OPERATOR_HANDLE}}-{{worker_id_1}} | |

## Open ASKs for {{OPERATOR}}
(one dated line each, newest first; mirror every worker ASK onto the live board)

## Standing hold-outs
(shared environment/data you must not touch until a date, with owner)

## Shared-code claims (single-owner rule)
(file-scoped claims granted by GK, held until merge; migration slots; recorded in a tracker note)

## Prod / staging state (GK-verified, date + how)
| Service | Running revision | Short SHA | Source of truth |
|---|---|---|---|

## Live board
URL: {{BOARD_URL}} (published {{PUBLISH_DATE}} from `.gatekeeper/live-board.html`). Re-list the WHOLE questions collection every turn.

## Scheduled prompts (CronCreate / /loop ids)
- nightly prod check (Deploys): id, cron, expiry (in-session crons expire after 7 days and die with the session: re-create and update this line).
- GK backstop: id, cron (~15 min after the Deploys report is due), expiry. Logs a clean night, flags the operator on any hit, pings Deploys (or says the check stopped) if no report came.

## In flight
| Item | Ticket | Head (full SHA) | CI | Review | Next |
|---|---|---|---|---|---|

Watches (not re-verified): ...
{{PEER_TEAM}} side: ...
