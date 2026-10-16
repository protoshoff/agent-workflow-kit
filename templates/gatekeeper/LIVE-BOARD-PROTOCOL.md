# Gate Keeper Live - session write protocol (kit v1; derived from a v2 protocol in production use)

Board: {{BOARD_URL}}
Session ids (doc ids under `sessions/`, task `owner`): see `roster.txt` (default: gk, deploys, review, backend, mobile, bug-class, hotfix, planner).
Step `gate` values on this board: `{{OPERATOR_HANDLE}}` = the operator's go (shown as "you"), `relay` = pass along to {{PEER_TEAM}} (omit if no peer team), `peer` = {{PEER_TEAM}} owns the step.
Tool: `ArtifactData` (load once: ToolSearch `select:ArtifactData`). Every write to an existing doc needs `if_version` from your last read; on `version_mismatch`, re-read and redo. Never retry blind.

## What you may write
1. **Your own card**: `sessions/<you>` (lowercase id). Use `update` with `now` (one plain sentence a non-engineer can read), `state` (working | waiting | idle | blocked | compacting) and `updated` (ISO UTC, read from the clock, never guessed). Write it when your work changes, not on a timer.
2. **Your own tasks**: `tasks/<id>` where `owner` is you. Tick steps you finished yourself (code, suites, PR open, fix round) and add `proof` (SHA, counts). Use `update` and resend the whole `steps` array.
   - **Never tick these yourself:** "Review CLEARED", "CI green on SHA", "Merge go", "Merged", "Live", "to feedback". GK writes those (Review may tick CLEARED, CI green, and "Review merge check").
   - A new task, or a SHA change after a fix round: tick what you can and tell GK. GK resets the gate steps.
3. **Questions for the operator**: `questions/<you>-<short-slug>`, using `set` with `{from, kind:"question"|"ruling", status:"open", created (ISO UTC), title, body, options:[{key,label,rec?}], ticket}`. Keep `title` to one plain sentence; put the detail in `body`. Mark at most one option `rec:true`, and only when you have a recommendation.
4. **Deploys only**: progress steps on `board/release`. Never the "Prod go" step.

## Collections (shapes the page reads)
- `sessions/<id>`: `{name, role, order, now, state, updated}`
- `tasks/<id>`: `{owner, title, note, sha, order, done, steps:[{label, done, proof, gate}], go:{tab, text, kind}, relay, typed, updated}`
- `questions/<from>-<slug>`: above, plus on answer `status:"answered"`, `answer:{choice,text,at}`; GK later sets `status:"relayed"` and `relayedAt`.
- `board/ctx` `{sessions:{<id>:{pct,at}}, usage}` (GK writes from `hooks/ctx-sync.sh`), `board/release`, `board/log` `{entries:[{t,who,text}]}` (GK only).

## Needs-you logic (what the page shows as waiting on the operator)
First open step of a task with `gate:"{{OPERATOR_HANDLE}}"` AND a `go` field -> a "go card" (text to type in the named tab). `gate:"relay"` -> "Pass along". Open `questions` -> Question/Ruling cards. A session at >=45% context -> "Compact soon".
`typed` is set when the operator taps "I typed it". Rule: whenever a card's `go` changes or is ticked, delete `typed` in the SAME write (`{"__delete__":true}`), or the board says "Waiting for confirmation" for a go nobody typed.

## What you never do
- **Never post a merge, deploy, prod read/write, secret or money go request as a question.** Those are typed by the operator in YOUR tab, and an answer on the board can't authorize them: every session writes as the operator, so a board answer is not proof the operator typed it.
- Never edit another session's card, tasks or questions. Never touch `board/log` (GK only).
- The operator's answers on the board are rulings. GK relays them to you and records them in LOG and the tracker. Act on GK's relay or on the operator's words in your tab, not on a board read you made yourself.

## Still do
Send GK `UPDATE:` / `ASK:` messages as before (SendMessage). The board adds to them; it doesn't replace them.

## Compaction policy
- Sessions auto-compact at about 50% of the context window (`CLAUDE_CODE_AUTO_COMPACT_WINDOW`, set in the project's `.claude/settings.local.json` by `hooks/apply-gk-hooks.sh`). Past that, each call costs much more, so compaction is automatic, not on request.
- Because it can fire at any moment, keep state durable: tracker note at each milestone, board card and task steps current, WIP committed and pushed at each stopping point, note ids and SHAs written down, not held in context.
- After a compaction, a SessionStart hook tells you what to re-read (your KICKOFF.md section, this protocol, your board card and tasks). Do that first, then send GK `UPDATE: compacted; resuming at <ticket/PR, SHA, next step>`.
- If an action the operator granted first-hand in your tab (a standing exception) is refused after compaction, ask the operator to re-grant it in your tab. Never ask another session to do it.
